"""Validate Android release versions before CI spends time building APKs."""

import os
from pathlib import Path
import re
import subprocess


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def parse_version(content):
    match = re.search(
        r"^version:\s*['\"]?(\d+\.\d+\.\d+)\+([1-9]\d*)['\"]?\s*$",
        content,
        re.MULTILINE,
    )
    if not match:
        raise SystemExit("pubspec.yaml must have version: x.y.z+positive_build_number")
    name, build = match.groups()
    if int(build) > 2100000000:
        raise SystemExit("Android build number must not exceed 2100000000")
    return name, int(build)


def main():
    name, build = parse_version(Path("pubspec.yaml").read_text(encoding="utf-8"))
    tag = f"v{name}"
    ref = os.environ["GITHUB_REF"]
    event = os.environ["GITHUB_EVENT_NAME"]
    tag_release = event == "push" and ref.startswith("refs/tags/v")
    manual_release = (
        event == "workflow_dispatch" and os.environ.get("PUBLISH_RELEASE") == "true"
    )
    publish = tag_release or manual_release

    if publish:
        if tag_release and ref != f"refs/tags/{tag}":
            raise SystemExit(f"Release tag must match pubspec.yaml: {tag}")
        if manual_release and ref != "refs/heads/main":
            raise SystemExit("Manual publishing is only supported from main")

        tags = git("tag", "--list", "v*").splitlines()
        if tag in tags and git("rev-parse", f"refs/tags/{tag}^{{commit}}") != git(
            "rev-parse", "HEAD"
        ):
            raise SystemExit(f"Tag {tag} already points to a different commit; use a new version")

        for previous_tag in tags:
            if previous_tag == tag:
                continue
            _, previous_build = parse_version(
                git("show", f"refs/tags/{previous_tag}:pubspec.yaml")
            )
            if build <= previous_build:
                raise SystemExit(
                    f"Build number {build} must exceed {previous_build} from {previous_tag}"
                )

    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write(f"version={name}+{build}\ntag={tag}\npublish={str(publish).lower()}\n")
    print(f"Version: {name}+{build}; tag: {tag}; publish: {publish}")


if __name__ == "__main__":
    main()
