import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/firebase_config.dart'; // LMS로 받은 파일
import 'screens/weather_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // runApp 전에 플러그인을 쓰기 위한 준비
  await Firebase.initializeApp(options: firebaseOptions); // firebase_config.dart의 상수로 교수용 프로젝트에 연결
  runApp(const WeatherLabApp());
}

class WeatherLabApp extends StatelessWidget {
  const WeatherLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '지금 날씨 보여줘',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const WeatherHomePage(),
    );
  }
}
