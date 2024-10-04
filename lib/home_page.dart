import 'package:flutter/material.dart';
import 'custom_scaffold.dart';  // custom_scaffold.dart 파일을 import 합니다.

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'GNU Music - 홈',
      body: Center(
        child: Text('홈 페이지 내용'),
      ),
    );
  }
}