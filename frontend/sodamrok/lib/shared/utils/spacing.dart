import 'package:flutter/widgets.dart';

class Insets {
  Insets._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class Gaps {
  Gaps._();

  static const SizedBox xs = SizedBox(height: Insets.xs, width: Insets.xs);
  static const SizedBox sm = SizedBox(height: Insets.sm, width: Insets.sm);
  static const SizedBox md = SizedBox(height: Insets.md, width: Insets.md);
  static const SizedBox lg = SizedBox(height: Insets.lg, width: Insets.lg);
  static const SizedBox xl = SizedBox(height: Insets.xl, width: Insets.xl);
}
