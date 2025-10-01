import 'package:flutter/material.dart';

class DSXColors {
  static const Color base = Color(0xFF0B0F14);
  static const Color glass = Color.fromRGBO(255, 255, 255, 0.06);
  static const Color border = Color.fromRGBO(255, 255, 255, 0.12);
  static const Color accent = Color(0xFF7CFFB2);
  static const Color warn = Color(0xFFFFB84D);
  static const Color danger = Color(0xFFFF5E5E);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB8C0CC);
}

class DSXRadii {
  static const double sm = 12;
  static const double md = 20;
  static const double xl = 28;
}

class DSXBlur {
  static const double sm = 10;
  static const double md = 18;
}

class DSXSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
}

class DSXMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 220);
  static const Curve ease = Curves.easeInOut;
} 