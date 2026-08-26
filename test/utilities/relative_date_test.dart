import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/utilities/format.dart';

void main() {
  // A fixed "now" so these never depend on when the suite runs.
  final now = DateTime(2026, 8, 26, 14, 30);

  int ts(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  String rel(DateTime d) =>
      Format.extractRelativeDateFrom(ts(d), now: now);

  test("today is named, not dated", () {
    expect(rel(DateTime(2026, 8, 26, 9, 5)), "Today, 9:05");
    expect(rel(DateTime(2026, 8, 26, 22, 32)), "Today, 22:32");
  });

  test("yesterday is named", () {
    expect(rel(DateTime(2026, 8, 25, 10, 6)), "Yesterday, 10:06");
  });

  test("late last night is Yesterday, not Today", () {
    // Only ~15h earlier, but a different calendar day - elapsed-hours logic
    // would wrongly call this "Today".
    expect(rel(DateTime(2026, 8, 25, 23, 50)), "Yesterday, 23:50");
  });

  test("earlier this year leaves the year implicit", () {
    expect(rel(DateTime(2026, 7, 23, 22, 32)), "23 Jul, 22:32");
    expect(rel(DateTime(2026, 1, 4, 9, 43)), "4 Jan, 9:43");
  });

  test("a previous year is spelled out", () {
    expect(rel(DateTime(2025, 12, 31, 23, 59)), "31 Dec 2025, 23:59");
  });

  test("minutes are always two digits", () {
    expect(rel(DateTime(2026, 8, 26, 8, 0)), "Today, 8:00");
    expect(rel(DateTime(2026, 8, 26, 8, 9)), "Today, 8:09");
  });

  test("the absolute formatter is untouched", () {
    // Detail views still want the unambiguous form.
    expect(
      Format.extractDateFrom(ts(DateTime(2026, 7, 23, 22, 32))),
      "23 Jul 2026, 22:32",
    );
  });
}
