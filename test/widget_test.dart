import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
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
        expect(
          find.byType(fluent.FluentApp),
          platform == TargetPlatform.windows ? findsOneWidget : findsNothing,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('iOS segmented navigation switches sections', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ZineFoldApp(store: store, initialProject: project),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reading order'), findsOneWidget);
      expect(find.byKey(const ValueKey('ios-navigation')), findsOneWidget);

      await tester.tap(find.text('Sheets'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet preview'), findsOneWidget);
      expect(find.text('Reading order'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('all platforms survive narrow text scaling and resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.platformDispatcher.textScaleFactorTestValue = 2;
    try {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(
          ZineFoldApp(
            key: ValueKey(platform),
            store: store,
            initialProject: project,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$platform compact');
        tester.view.physicalSize = const Size(1100, 900);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$platform wide');
        tester.view.physicalSize = const Size(390, 844);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('Windows Fluent navigation selects sheets with keyboard', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ZineFoldApp(store: store, initialProject: project),
      );
      await tester.pumpAndSettle();
      expect(find.byType(fluent.NavigationView), findsOneWidget);
      expect(find.byType(fluent.Button), findsWidgets);
      expect(find.text('Reading order'), findsOneWidget);
      await tester.tap(find.text('Sheets').first);
      await tester.pumpAndSettle();
      expect(find.text('Sheet preview'), findsOneWidget);
      expect(find.text('Reading order'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android adapts navigation between compact and wide', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ZineFoldApp(store: store, initialProject: project),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      tester.view.physicalSize = const Size(1000, 800);
      await tester.pumpWidget(
        ZineFoldApp(store: store, initialProject: project),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
