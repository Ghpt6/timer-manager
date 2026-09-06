"""Exercise release checks against real, isolated Git version histories."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("release_metadata.py").resolve()


class ReleaseMetadataTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="timer-release-test-")
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name)
        self.output = self.repo / "outputs.txt"
        self.git("init", "--quiet")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release-test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "tag.gpgsign", "false")
        self.write_version("1.2.0+4005", commit=True)
        self.git("tag", "v1.2.0")
        self.write_version("1.2.1+4006", commit=True)

    def git(self, *args):
        subprocess.run(
            ["git", *args], cwd=self.repo, check=True, capture_output=True, text=True
        )

    def write_version(self, version, commit=False):
        (self.repo / "pubspec.yaml").write_text(
            f"name: flutterproject\nversion: {version}\n", encoding="utf-8"
        )
        if commit:
            self.git("add", "pubspec.yaml")
            self.git("commit", "--quiet", "-m", f"Version {version}")

    def run_check(self, event="workflow_dispatch", ref="refs/heads/main", publish=True):
        return subprocess.run(
            [sys.executable, str(SCRIPT)],
            cwd=self.repo,
            env={
                **os.environ,
                "GITHUB_EVENT_NAME": event,
                "GITHUB_REF": ref,
                "PUBLISH_RELEASE": str(publish).lower(),
                "GITHUB_OUTPUT": str(self.output),
            },
            capture_output=True,
            text=True,
        )

    def assert_rejected(self, result, message):
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(message, result.stderr)
        self.assertFalse(self.output.exists())

    def test_manual_release_uses_pubspec_version(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.output.read_text(encoding="utf-8"),
            "version=1.2.1+4006\ntag=v1.2.1\npublish=true\n",
        )

    def test_annotated_tag_release_and_retry(self):
        self.git("tag", "-a", "v1.2.1", "-m", "Release")
        for event, ref in [
            ("push", "refs/tags/v1.2.1"),
            ("workflow_dispatch", "refs/heads/main"),
        ]:
            result = self.run_check(event=event, ref=ref)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.output.unlink()

    def test_tag_must_match_version(self):
        result = self.run_check(event="push", ref="refs/tags/v1.9.0")
        self.assert_rejected(result, "Release tag must match pubspec.yaml: v1.2.1")

    def test_manual_publish_requires_main(self):
        result = self.run_check(ref="refs/heads/feature")
        self.assert_rejected(result, "only supported from main")

    def test_existing_tag_cannot_move_to_new_code(self):
        self.git("tag", "v1.2.1", "HEAD~1")
        self.assert_rejected(self.run_check(), "already points to a different commit")

    def test_equal_or_lower_build_number_is_rejected(self):
        for build in [4005, 4004]:
            with self.subTest(build=build):
                self.write_version(f"1.2.1+{build}")
                self.assert_rejected(self.run_check(), "must exceed 4005 from v1.2.0")

    def test_compare_all_tags_not_lexicographic_latest(self):
        self.write_version("1.1.9+5000", commit=True)
        self.git("tag", "v1.1.9")
        self.write_version("1.2.1+4006", commit=True)
        self.assert_rejected(self.run_check(), "must exceed 5000 from v1.1.9")

    def test_build_only_runs_do_not_publish_or_require_version_bump(self):
        self.write_version("1.2.0+4005")
        for event, ref in [
            ("push", "refs/heads/main"),
            ("pull_request", "refs/pull/7/merge"),
            ("workflow_dispatch", "refs/heads/feature"),
        ]:
            result = self.run_check(event=event, ref=ref, publish=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("publish=false", self.output.read_text(encoding="utf-8"))
            self.output.unlink()

    def test_invalid_android_versions_fail_before_building(self):
        for version in ["1.2.1", "1.2.1+0", "1.2.1+-1", "1.2.1+2100000001"]:
            with self.subTest(version=version):
                self.write_version(version)
                result = self.run_check()
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
