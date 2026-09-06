import 'package:flutter/material.dart';

import 'src/home_page.dart';
import 'src/timer_controller.dart';
import 'src/timer_platform.dart';
import 'src/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TimerManagerApp());
}

class TimerManagerApp extends StatefulWidget {
  const TimerManagerApp({super.key, this.controller});
  final TimerController? controller;

  @override
  State<TimerManagerApp> createState() => _TimerManagerAppState();
}

class _TimerManagerAppState extends State<TimerManagerApp> {
  late final TimerController _controller =
      widget.controller ??
      TimerController(platform: const AndroidTimerPlatform());

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '计时管理',
    debugShowCheckedModeBanner: false,
    theme: timerTheme,
    home: HomePage(controller: _controller),
  );
}
