// lib/config/environment.dart
class Environment {
  static const String _baseUrl = 'https://gnumusic.shop';
  // static const String _baseUrl = 'http://117.16.153.89:8080';

  static const String wsUrl = 'wss://gnumusic.shop';
  // static String wsUrl = "ws://117.16.153.89:8080";

  static String get apiUrl => '$_baseUrl/api';
}