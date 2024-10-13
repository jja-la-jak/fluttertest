import 'package:flutter/material.dart';
import '../modules/appbar.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: '프로필',
        // 프로필 페이지에서는 아이콘 동작을 다르게 설정할 수 있습니다
      ),
      body: Center(
        child: Text('프로필 페이지 내용'),
      ),
    );
  }
}