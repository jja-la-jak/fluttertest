import 'package:flutter/material.dart';
import 'package:flutter_project/screens/SecondScreen.dart';
import 'package:flutter_project/modules/custom_scaffold.dart';

class Chatting extends StatefulWidget {
  const Chatting({Key? key}) : super(key: key);

  @override
  _ChattingState createState() => _ChattingState();
}

class _ChattingState extends State<Chatting> {
  int _currentIndex = 1; // 채팅 아이콘이 선택된 상태로 시작

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // TODO: 여기에 각 탭에 대한 네비게이션 로직을 추가하세요
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      currentIndex: _currentIndex,
      onTabTapped: _onTabTapped,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Prompt',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('구현예정'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SecondScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}