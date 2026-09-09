import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

class P2PMessengerApp extends StatelessWidget {
  const P2PMessengerApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'P2P Messenger',
      theme: buildAppTheme(),
      home: HomeShell(controller: controller),
    );
  }
}
