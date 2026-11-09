import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zinefold/main.dart';
import 'package:zinefold/project_store.dart';

void main() {
  late Directory tempDir;
  late ProjectStore store;
  late ZineProject project;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zinefold-shell-');
    store = ProjectStore(Directory('${tempDir.path}/projects'));
    project = await store.create(signature: 8);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    testWidgets('$platform uses its own shell', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await tester.pumpWidget(
          ZineFoldApp(store: store, initialProject: project),
        );
        await tester.pumpAndSettle();
        expect(find.text('Reading order'), findsOneWidget);
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
