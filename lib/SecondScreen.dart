import 'package:flutter/material.dart';
class SecondScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('두 번째 화면'),
      ),
      body: Center(
        child: ElevatedButton(
          child: Text('첫 번째 화면으로 돌아가기'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}