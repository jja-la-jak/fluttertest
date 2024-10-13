import 'package:flutter/material.dart';

class CustomScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final Function(int) onTabTapped;

  const CustomScaffold({
    Key? key,
    required this.body,
    required this.currentIndex,
    required this.onTabTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2D7B6), // 배경색 설정
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.black54),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '검색',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CircleAvatar(
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, color: Colors.black54),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: body,
      bottomNavigationBar: Container(
        height: 60,
        child: Row(
          children: [
            _buildNavItem(Icons.tiktok, 0, Color(0xFFF6C48A)),
            _buildNavItem(Icons.chat_bubble_outline, 1, Color(0xFFE89D63)),
            _buildNavItem(Icons.star_border, 2, Color(0xFFF6C48A)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabTapped(index),
        child: Container(
          color: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: currentIndex == index ? Colors.black : Colors.black54,
              ),
              SizedBox(height: 4),
              Container(
                height: 4,
                width: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentIndex == index ? Colors.black : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}