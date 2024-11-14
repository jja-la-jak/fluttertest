import 'package:flutter/material.dart';
import 'package:flutter_project/screens/chatting_page.dart';
import 'package:flutter_project/screens/playlist_page.dart';
import 'package:flutter_project/screens/login_screen.dart';
import 'package:flutter_project/screens/splash_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GNU Music App',
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(),  // HomePage 위젯을 사용합니다.
    );
  }
}