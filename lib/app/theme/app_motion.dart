import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const instant = Duration(milliseconds: 180),
      fast = Duration(milliseconds: 180),
      normal = Duration(milliseconds: 240),
      slow = Duration(milliseconds: 300),
      emphasized = Duration(milliseconds: 300);
  static const enter = Curves.easeOutCubic,
      exit = Curves.easeInCubic,
      state = Curves.easeInOutCubic;
}
