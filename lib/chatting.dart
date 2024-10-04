import 'package:flutter/material.dart';
import 'package:flutter_project/SecondScreen.dart';
import 'package:flutter_project/profile.dart';
import 'package:flutter_project/custom_scaffold.dart';

class chatting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'main',

      body: Center(
        child: ElevatedButton(
          child: Text('두 번째 화면으로 이동'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SecondScreen()),
            );
          },
        ),
      ),
    );
  }
}