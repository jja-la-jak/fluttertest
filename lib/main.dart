import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 프레임워크 초기화
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); // 예시 코드

  runApp(const MyApp()); // 앱 구동
}

class MyApp extends StatelessWidget { //메인페이지 생성
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [Icon(Icons.star)], title: Text('앱임'),
          leading: Icon(Icons.star),
        ),
        body: SizedBox(
          child: IconButton(icon: Icon(Icons.star), onPressed: (){},

        )
        )

        ),
      );

  }
}

