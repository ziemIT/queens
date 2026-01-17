import 'package:flutter/material.dart';
import 'screens/game_screen.dart';
import 'screens/help_screen.dart';

void main() {
  runApp(const QueensApp());
}

class QueensApp extends StatelessWidget {
  const QueensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Queens Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HelpScreen(isFirstLaunch: true),
    );
  }
}
