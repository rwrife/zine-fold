import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:zinefold/booklet_workspace.dart';
import 'package:zinefold/project_store.dart';

void main() {
  late Directory root;
  late ProjectStore store;
  late ZineProject project;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zinefold-workspace-');
    store = ProjectStore(Directory('${root.path}/projects'));
    project = await store.create(signature: 8);
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  testWidgets('8-page grid warns, persists blanks and reorders', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookletWorkspace(store: store, initialProject: project),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(
          '8 empty slots will print blank. Mark them Blank to confirm your intent.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('blank-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('down-0')), findsOneWidget);
      final blank = (await tester.runAsync(() => store.setBlank(project, 0)))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookletWorkspace(
              key: const ValueKey('after-blank'),
              store: store,
              initialProject: blank,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(
          '7 empty slots will print blank. Mark them Blank to confirm your intent.',
        ),
        findsOneWidget,
      );
      final moved = (await tester.runAsync(
        () => store.reorderPages(blank, 0, 1),
      ))!;
      expect(moved.pages[0], isNull);
      expect(
        (await tester.runAsync(() => store.open(project.id)))!
            .pages[1]
            ?.isBlank,
        true,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('16-page sheet mappings have accessible labels', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final sixteen = (await tester.runAsync(
        () => store.create(signature: 16),
      ))!;
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        fluent.FluentApp(
          home: BookletWorkspace(store: store, initialProject: sixteen),
        ),
      );
      await tester.pump();
      expect(
        find.text(
          '16 empty slots will print blank. Mark them Blank to confirm your intent.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sheet 4 (outer to inner)'), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet-page-16')), findsOneWidget);
      final semantics = tester.getSemantics(
        find.byKey(const ValueKey('sheet-page-16')),
      );
      expect(semantics.label, contains('Page 16: empty'));
      expect(find.textContaining('saddle-stitch'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
