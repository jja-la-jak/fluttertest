
import 'package:flutter/material.dart';
import 'package:flutter_project/chatting.dart';
import 'home_page.dart';  // home_page.dart 파일을 import 합니다.

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
      home: chatting(),  // HomePage 위젯을 사용합니다.
    );
  }
}