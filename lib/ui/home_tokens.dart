import 'package:flutter/material.dart';

/// Locked in-app home palette. Status never paints the page or cards.
abstract final class HomeTokens {
  static const background = Color(0xFF090B0F);
  static const card = Color(0xFF171A20);
  static const border = Color(0xFF2A2F38);
  static const primaryText = Color(0xFFF5F7FA);
  static const secondaryText = Color(0xFFA7ADB5);
  static const remaining = Color(0xFFDDFB55);
  static const used = Color(0xFF7467F0);
  static const iccid = Color(0xFF3B8EF3);
  static const expiry = Color(0xFFF2A514);
  static const previous = Color(0xFFA7ADB5);
  static const error = Color(0xFFF2A514);
  static const skeleton = Color(0xFF2A2F38);

  static const pageInset = 16.0;
  static const cardGap = 14.0;
  static const maxContentWidth = 600.0;
  static const minTap = 48.0;
  static const packageRowMin = 56.0;
  static const actionGap = 8.0;

  static const cardRadius = 16.0;
  static const iconCircle = 40.0;
}
