import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zinefold/main.dart';

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    testWidgets('$platform uses its own shell', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await tester.pumpWidget(const ZineFoldApp());
        expect(
          find.text('Zine Fold\nBooklet tools are in development.'),
          findsOneWidget,
        );
        expect(
          find.byType(CupertinoApp),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(MaterialApp),
          platform == TargetPlatform.android ? findsOneWidget : findsNothing,
        );
        expect(find.byType(WidgetsApp), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
