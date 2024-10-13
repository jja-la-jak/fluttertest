import 'package:flutter/material.dart';
import 'package:flutter_project/widgets/google_sign_in_button.dart';
import 'package:flutter_project/screens/home_screen.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('로그인'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '음악 추천 앱에 오신 것을 환영합니다!',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            GoogleSignInButton(
              onSignInSuccess: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}