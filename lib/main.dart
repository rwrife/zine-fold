import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

import 'booklet_workspace.dart';
import 'project_store.dart';

void main() => runApp(const ZineFoldApp());

class ZineFoldApp extends StatefulWidget {
  const ZineFoldApp({super.key, this.store, this.initialProject});

  final ProjectStore? store;
  final ZineProject? initialProject;

  @override
  State<ZineFoldApp> createState() => _ZineFoldAppState();
}

class _ZineFoldAppState extends State<ZineFoldApp> {
  int _section = 0;

  void _select(int value) => setState(() => _section = value);

  @override
  Widget build(BuildContext context) {
    final content = BookletWorkspace(
      store: widget.store,
      initialProject: widget.initialProject,
      section: _section,
    );
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => CupertinoApp(
        title: 'Zine Fold',
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Zine Fold'),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: CupertinoSlidingSegmentedControl<int>(
                    key: const ValueKey('ios-navigation'),
                    groupValue: _section,
                    children: const {0: Text('Pages'), 1: Text('Sheets')},
                    onValueChanged: (value) {
                      if (value != null) _select(value);
                    },
                  ),
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
      TargetPlatform.android => MaterialApp(
        title: 'Zine Fold',
        theme: ThemeData(useMaterial3: true),
        home: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            final navigation = wide
                ? NavigationRail(
                    selectedIndex: _section,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.auto_stories_outlined),
                        label: Text('Pages'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.view_carousel_outlined),
                        label: Text('Sheets'),
                      ),
                    ],
                  )
                : null;
            return Scaffold(
              appBar: AppBar(title: const Text('Zine Fold')),
              body: wide
                  ? Row(
                      children: [
                        navigation!,
                        Expanded(child: content),
                      ],
                    )
                  : content,
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      selectedIndex: _section,
                      onDestinationSelected: _select,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.auto_stories_outlined),
                          label: 'Pages',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.view_carousel_outlined),
                          label: 'Sheets',
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
      _ => fluent.FluentApp(
        title: 'Zine Fold',
        home: fluent.NavigationView(
          pane: fluent.NavigationPane(
            selected: _section,
            onChanged: _select,
            displayMode: fluent.PaneDisplayMode.auto,
            items: [
              fluent.PaneItem(
                icon: const fluent.Icon(fluent.FluentIcons.page),
                title: const Text('Pages'),
                body: const SizedBox.shrink(),
              ),
              fluent.PaneItem(
                icon: const fluent.Icon(fluent.FluentIcons.page_list),
                title: const Text('Sheets'),
                body: const SizedBox.shrink(),
              ),
            ],
          ),
          paneBodyBuilder: (item, body) => fluent.ScaffoldPage(
            header: const fluent.PageHeader(title: Text('Zine Fold')),
            content: content,
          ),
        ),
      ),
    };
  }
}
