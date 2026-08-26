import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/utilities/hero_ink.dart';

void main() {
  const bfxBlue = Color(0xFF2F6BFF);

  test("light themes get the theme's declared colour, untouched", () {
    expect(heroFill(bfxBlue, Brightness.light), bfxBlue);
    expect(
      heroFill(const Color(0xFFF36B43), Brightness.light),
      const Color(0xFFF36B43),
    );
  });

  test("dark themes settle the fill without shifting its hue", () {
    final seated = heroFill(bfxBlue, Brightness.dark);

    expect(seated, isNot(bfxBlue), reason: "should actually change");

    // Darker, but still clearly the same colour.
    expect(seated.computeLuminance(), lessThan(bfxBlue.computeLuminance()));

    final a = HSLColor.fromColor(bfxBlue);
    final b = HSLColor.fromColor(seated);
    expect(
      (b.hue - a.hue).abs(),
      lessThan(1.0),
      reason: "hue must survive - this seats the colour, it does not restyle it",
    );
  });

  test("the change is restrained, not a repaint", () {
    final seated = heroFill(bfxBlue, Brightness.dark);
    final drop = bfxBlue.computeLuminance() - seated.computeLuminance();
    expect(drop, greaterThan(0.0));
    expect(
      drop,
      lessThan(0.06),
      reason: "a nudge to seat it against the page, not a new colour",
    );
  });

  test("hero ink stays white regardless - the rule that was signed off", () {
    expect(heroInk(bfxBlue), Colors.white);
    expect(heroInk(heroFill(bfxBlue, Brightness.dark)), Colors.white);
    expect(heroInk(const Color(0xFFF36B43)), Colors.white);
  });
}
