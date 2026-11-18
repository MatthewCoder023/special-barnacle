import 'package:material_ui/material_ui.dart';

/// EVYAHE palette.
///
/// The three brand colors come from the design brief. The remaining colors are
/// derived tints and shades of those three, plus status colors that are always
/// paired with a text label so that meaning never depends on color alone.
class AppColors {
  AppColors._();

  // Brand
  static const sky = Color(0xFF87CEEB); // primary
  static const white = Color(0xFFFFFFFF); // background
  static const pink = Color(0xFFFF69B4); // accent

  // Derived from sky
  static const skySoft = Color(0xFFEAF6FC);
  static const skyMist = Color(0xFFF5FBFE);
  static const skyDeep = Color(0xFF2B86AE);

  // Derived from pink
  static const pinkSoft = Color(0xFFFFEAF4);
  static const pinkDeep = Color(0xFFD23A88);

  // Text and lines
  static const ink = Color(0xFF16263A);
  static const inkSoft = Color(0xFF5A6B7E);
  static const inkFaint = Color(0xFF9BA9B7);
  static const line = Color(0xFFE4EDF3);

  // Status
  static const success = Color(0xFF1F9D72);
  static const successSoft = Color(0xFFE4F6EF);
  static const warning = Color(0xFFC98512);
  static const warningSoft = Color(0xFFFFF3DC);
  static const danger = Color(0xFFD9485F);
  static const dangerSoft = Color(0xFFFDE8EC);
}
