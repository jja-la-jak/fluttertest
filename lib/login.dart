import 'package:flutter/material.dart';

class login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('상단바'),
        backgroundColor: Color(0xFFF7AB5A), // 상단바 색상
      ),
      body: Container(
        color: Color(0xFFFBD0A3), // 중단(본문) 색상
        child: Center(
          child: Text(
            '본문',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Color(0xF7AB5A00), // 하단바 색상
        child: Container(
          height: 50.0,
          child: Center(
            child: Text(
              '하단바',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}