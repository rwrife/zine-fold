import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'booklet_workspace.dart';
import 'project_store.dart';

void main() => runApp(const ZineFoldApp());

class ZineFoldApp extends StatelessWidget {
  const ZineFoldApp({super.key, this.store, this.initialProject});

  final ProjectStore? store;
  final ZineProject? initialProject;

  @override
  Widget build(BuildContext context) {
    final content = BookletWorkspace(
      store: store,
      initialProject: initialProject,
    );
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => CupertinoApp(
        title: 'Zine Fold',
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Zine Fold'),
          ),
          child: SafeArea(child: content),
        ),
      ),
      TargetPlatform.android => MaterialApp(
        title: 'Zine Fold',
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(title: const Text('Zine Fold')),
          body: content,
        ),
      ),
      _ => WidgetsApp(
        color: const Color(0xff203e63),
        title: 'Zine Fold',
        builder: (context, child) =>
            ColoredBox(color: const Color(0xfff4f6fa), child: content),
      ),
    };
  }
}
