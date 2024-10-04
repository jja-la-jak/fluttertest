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
      title: Text(title),
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

class CustomScaffold extends StatefulWidget {
  final Widget body;
  final String title;

  CustomScaffold({
    required this.body,
    required this.title,
  });

  @override
  _CustomScaffoldState createState() => _CustomScaffoldState();
}

class _CustomScaffoldState extends State<CustomScaffold> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // TODO: 여기에 각 탭에 대한 네비게이션 로직을 추가하세요
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.title,
        onFirstImageTap: () {
          // TODO: 알람 화면으로 이동하는 로직 추가
        },
        onSecondImageTap: () {
          // TODO: 프로필 화면으로 이동하는 로직 추가
        },
      ),
      body: widget.body,
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}