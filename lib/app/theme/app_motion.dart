import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const instant = Duration(milliseconds: 80),
      fast = Duration(milliseconds: 140),
      normal = Duration(milliseconds: 240),
      slow = Duration(milliseconds: 360),
      emphasized = Duration(milliseconds: 480);
  static const enter = Curves.easeOutCubic,
      exit = Curves.easeInCubic,
      state = Curves.easeInOutCubic;
}
