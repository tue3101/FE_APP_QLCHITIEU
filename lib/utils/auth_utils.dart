import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart'; // Adjust this import to your LoginPage path

//hàm xử lý phản hồi từ API và trả kq bool
Future<bool> handleApiResponse(BuildContext context, http.Response response, String token, dynamic idnguodung) async {
  //nếu token hết hạn, chưa đăng nhập
  if (response.statusCode == 401) {
    print('Authentication error (401). Logging out user.');
    Future.microtask(() => logoutUser(context, token, idnguodung));
    return true;
  }
  return false;
}

Future<void> logoutUser(BuildContext context, String token, dynamic idnguodung) async {
  try {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/logout');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      print('Logout successful');
    } else {
      print('Logout failed with status: ${response.statusCode}');
    }

    // Clear stored credentials regardless of API logout success
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('idnguodung');
    print('Cleared local storage for token and idnguodung.');

    // Navigate to login page and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()), // Assuming your login page is LoginPage
      (Route<dynamic> route) => false,
    );
  } catch (e) {
    print('Error during logout: $e');
    // Even if there's an error with the API call, try to clear local storage and navigate
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('idnguodung');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }
} 