import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Color hexToColor(String hex) {
  print('Converting hex to color: $hex');
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  Color parsedColor = Color(int.parse(hex, radix: 16));
  print('Parsed Color: $parsedColor');
  return parsedColor;
}


IconData getFaIconDataFromUnicode(String unicodeHex) {
  print('Converting unicode hex to icon: $unicodeHex');
  try {
    String hexWithPrefix = '0x' + unicodeHex.toLowerCase();
    int codePoint = int.parse(hexWithPrefix);
    IconData iconData = IconData(codePoint, fontFamily: 'FontAwesomeSolid', fontPackage: 'font_awesome_flutter');
    return iconData;
  } catch (e) {
    print('Error converting hex to icon: $unicodeHex - $e');
    return Icons.question_mark;
  }
} 