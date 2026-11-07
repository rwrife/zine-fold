import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ZineFoldApp());

class ZineFoldApp extends StatelessWidget {
  const ZineFoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    const content = Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Zine Fold\nBooklet tools are in development.',
          textAlign: TextAlign.center,
        ),
      ),
    );
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => const CupertinoApp(
        title: 'Zine Fold',
        home: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(middle: Text('Zine Fold')),
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
        builder: (context, child) => const ColoredBox(
          color: Color(0xfff4f6fa),
          child: DefaultTextStyle(
            style: TextStyle(fontSize: 20, color: Color(0xff203e63)),
            child: content,
          ),
        ),
      ),
    };
  }
}
