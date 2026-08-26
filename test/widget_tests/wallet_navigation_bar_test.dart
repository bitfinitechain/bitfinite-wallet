import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/widgets/wallet_navigation_bar/components/wallet_navigation_bar_item.dart';
import 'package:bitfinite/widgets/wallet_navigation_bar/wallet_navigation_bar.dart';

import '../sample_data/theme_json.dart';

void main() {
  testWidgets("floating dock stretches its actions across the full width", (
    tester,
  ) async {
    final theme = StackTheme.fromJson(json: lightThemeJsonMap);

    WalletNavigationBarItemData item(String label) =>
        WalletNavigationBarItemData(
          label: label,
          icon: const SizedBox(width: 20, height: 20),
          onTap: () {},
        );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            extensions: [StackColors.fromStackColorTheme(theme)],
          ),
          home: Scaffold(
            body: WalletNavigationBar(
              floating: true,
              items: [item("Receive"), item("Send")],
              moreItems: [item("Anything")],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The pill itself. Keyed rather than found by type, because the surface is
    // wrapped in a BackdropFilter only on iOS - Android gets a solid fill.
    final dock = tester.getRect(find.byKey(const Key("walletDockSurface")));

    // Two items + the generated "More" button.
    final buttons = find.byType(InkWell);
    expect(buttons, findsNWidgets(3));

    // Measure edges, not centres against a fixed button size. The dock's
    // actions became variable-width when they gained labels, so any assertion
    // built on "48px square" describes one past revision rather than the
    // intent, which is that the row of actions fills the pill.
    final rects = <Rect>[
      for (int i = 0; i < 3; i++) tester.getRect(buttons.at(i)),
    ];

    // 6px horizontal padding plus the 1px hairline border inset the content
    // box the actions are laid out in.
    const inset = 6.0 + 1.0;

    expect(
      rects.first.left,
      closeTo(dock.left + inset, 1.0),
      reason: "first action should start at the dock's content edge",
    );
    expect(
      rects.last.right,
      closeTo(dock.right - inset, 1.0),
      reason: "last action should end at the dock's content edge",
    );

    // No action overlaps its neighbour, and none is stranded by a gap wider
    // than an action - either would read as a broken row rather than a dock.
    for (int i = 1; i < rects.length; i++) {
      final gap = rects[i].left - rects[i - 1].right;
      expect(gap, greaterThanOrEqualTo(-0.5), reason: "actions must not overlap");
      expect(
        gap,
        lessThan(rects[i].width),
        reason: "gap between actions should not exceed an action's own width",
      );
    }
  });
}
