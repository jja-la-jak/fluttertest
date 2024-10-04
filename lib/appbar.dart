import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onFirstImageTap;
  final VoidCallback? onSecondImageTap;

  CustomAppBar({
    required this.title,
    this.onFirstImageTap,
    this.onSecondImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text('GNU Music'),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Image.asset('assets/alarm.png'),
          onPressed: onFirstImageTap,
        ),
        IconButton(
          icon: Image.asset('assets/profile.png'),
          onPressed: onSecondImageTap,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  CustomBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: '홈',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: '검색',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.library_music),
          label: '라이브러리',
        ),
      ],
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // TODO: 여기에 각 탭에 대한 기능을 추가하세요
    print('Tapped on index: $index');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'GNU Music',
        onFirstImageTap: () {
          // TODO: 알람 아이콘 탭 기능 추가
          print('Alarm tapped');
        },
        onSecondImageTap: () {
          // TODO: 프로필 아이콘 탭 기능 추가
          print('Profile tapped');
        },
      ),
      body: Center(
        child: Text('Page $_currentIndex'),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}