import 'package:flutter/material.dart';
import 'package:flutter_project/screens/chatting.dart';
import 'screens/home_page.dart';  // home_page.dart 파일을 import 합니다.
import 'package:flutter_project/screens/login_screen.dart';
import 'package:flutter_project/screens/splash_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GNU Music App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginScreen(),  // HomePage 위젯을 사용합니다.
    );
  }
}