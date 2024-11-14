import 'package:flutter/material.dart';
import 'package:flutter_project/widgets/google_sign_in_button.dart';
import 'package:flutter_project/screens/chatting_page.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 배경 이미지
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/image/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 로그인 컨텐츠
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'GNU',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  // 기존의 GoogleSignInButton 사용
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: GoogleSignInButton(
                      onSignInSuccess: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => Chatting()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}