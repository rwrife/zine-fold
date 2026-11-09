import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'imposition.dart';
import 'project_store.dart';

/// Shared booklet editor; only controls change appearance per host platform.
class BookletWorkspace extends StatefulWidget {
  const BookletWorkspace({super.key, this.store, this.initialProject});

  final ProjectStore? store;
  final ZineProject? initialProject;

  @override
  State<BookletWorkspace> createState() => _BookletWorkspaceState();
}

class _BookletWorkspaceState extends State<BookletWorkspace> {
  ProjectStore? _store;
  ZineProject? _project;
  String? _error;
  bool _busy = false;
  int _signature = 8;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    _project = widget.initialProject;
    if (_project == null) _start();
  }

  Future<void> _start() async {
    try {
      final store = _store ?? await ProjectStore.inAppDocuments();
      final project = await store.create(signature: _signature);
      if (mounted) {
        setState(() {
          _store = store;
          _project = project;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Cannot open project: $error');
    }
  }

  Future<void> _change(
    Future<ZineProject?> Function(ProjectStore, ZineProject) action,
  ) async {
    final store = _store;
    final project = _project;
    if (_busy || store == null || project == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action(store, project);
      if (mounted && updated != null) setState(() => _project = updated);
    } catch (error) {
      if (mounted) setState(() => _error = 'Change not saved: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  Widget _control(String label, VoidCallback? onPressed, {Key? key}) {
    if (_ios) {
      return CupertinoButton(
        key: key,
        onPressed: onPressed,
        child: Text(label),
      );
    }
    if (_android) {
      return OutlinedButton(key: key, onPressed: onPressed, child: Text(label));
    }
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: FocusableActionDetector(
        key: key,
        enabled: onPressed != null,
        mouseCursor: onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: onPressed == null
                  ? const Color(0xffe6e8ed)
                  : const Color(0xffe1e9f4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xff79899c)),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xff203e63)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String> onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in options)
              Semantics(
                selected: selected == option,
                child: _control(
                  '$option${selected == option ? ' (selected)' : ''}',
                  selected == option || _busy ? null : () => onSelect(option),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _pageGrid(ZineProject project) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Reading order',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const Text(
        'Import a page, or mark an intentional blank. Move pages with Up/Down.',
      ),
      const SizedBox(height: 8),
      for (var index = 0; index < project.signature; index++)
        _pageRow(project, index),
    ],
  );

  Widget _pageRow(ZineProject project, int index) {
    final page = project.pages[index];
    final description = page == null
        ? 'Empty (not deliberate)'
        : page.isBlank
        ? 'Intentional blank'
        : '${page.fileName} • source page ${page.sourcePage}';
    return Semantics(
      label: 'Reading page ${index + 1}: $description',
      explicitChildNodes: true,
      child: Container(
        key: ValueKey('page-$index'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffbac6d3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Page ${index + 1} — $description',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _control(
                  'Import',
                  _busy || (page != null && !page.isBlank)
                      ? null
                      : () => _change(
                          (store, snapshot) =>
                              store.pickAndImport(snapshot, index),
                        ),
                  key: ValueKey('import-$index'),
                ),
                _control(
                  'Blank',
                  _busy || (page != null && !page.isBlank)
                      ? null
                      : () => _change(
                          (store, snapshot) => store.setBlank(snapshot, index),
                        ),
                  key: ValueKey('blank-$index'),
                ),
                _control(
                  'Clear',
                  _busy || page == null || !page.isBlank
                      ? null
                      : () => _change(
                          (store, snapshot) => store.clearSlot(snapshot, index),
                        ),
                  key: ValueKey('clear-$index'),
                ),
                _control(
                  'Up',
                  _busy || index == 0
                      ? null
                      : () => _change(
                          (store, snapshot) =>
                              store.reorderPages(snapshot, index, index - 1),
                        ),
                  key: ValueKey('up-$index'),
                ),
                _control(
                  'Down',
                  _busy || index == project.signature - 1
                      ? null
                      : () => _change(
                          (store, snapshot) =>
                              store.reorderPages(snapshot, index, index + 1),
                        ),
                  key: ValueKey('down-$index'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(ZineProject project) {
    // Distinct IDs for repeated PDF source pages; blank markers stay null.
    final pages = [
      for (var index = 0; index < project.signature; index++)
        if (project.pages[index] == null || project.pages[index]!.isBlank)
          null
        else
          'reading-$index',
    ];
    final sheets = BookletImposition.impose(
      pages,
      signature: project.signature,
    );
    final missing = project.pages.where((page) => page == null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sheet preview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          '$missing empty slots will print blank. Mark them Blank to confirm your intent.',
          key: const ValueKey('empty-warning'),
        ),
        const SizedBox(height: 12),
        // Zoom is visual-only. Numbered labels remain readable via semantics.
        for (final sheet in sheets) ...[
          Text(
            'Sheet ${sheet.sheetNumber} (outer to inner)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          _sheetSide('Front', sheet.front),
          _sheetSide('Back', sheet.back),
          const SizedBox(height: 14),
        ],
        Text(BookletImposition.instructionForFlip(project.flipEdge)),
        const SizedBox(height: 8),
        const Text(BookletImposition.foldGuidance),
        const SizedBox(height: 8),
        const Text(
          'Preview only. Check printer orientation with a test sheet; printer registration is not guaranteed.',
        ),
      ],
    );
  }

  Widget _sheetSide(String name, SheetSide side) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name),
        SizedBox(
          height: 110,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Row(
              children: [
                Expanded(child: _slot(side.left)),
                Container(width: 2, color: const Color(0xffb1b8c2)),
                Expanded(child: _slot(side.right)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _slot(PageSlot slot) {
    final project = _project!;
    final page = project.pages[slot.pageNumber - 1];
    final blank = page == null || page.isBlank;
    final label =
        'Page ${slot.pageNumber}: ${page == null
            ? 'empty'
            : page.isBlank
            ? 'blank'
            : page.fileName}';
    final file = blank
        ? null
        : File('${_store!.root.path}/${project.id}/${page.fileName}');
    final image = file == null
        ? null
        : page!.fileName.endsWith('.pdf')
        ? FutureBuilder<Uint8List?>(
            future: _renderPdf(file, page.sourcePage),
            builder: (context, snapshot) =>
                snapshot.hasData && snapshot.data != null
                ? Image.memory(snapshot.data!, fit: BoxFit.contain)
                : const Text('PDF preview unavailable'),
          )
        : Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('Preview unavailable'),
          );
    return Semantics(
      label: label,
      child: Container(
        key: ValueKey('sheet-page-${slot.pageNumber}'),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xff9aa7b6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Page ${slot.pageNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (blank)
              Text(page == null ? 'Empty' : 'Blank')
            else if (image != null)
              Expanded(child: image),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _renderPdf(File file, int pageNumber) async {
    try {
      final doc = await PdfDocument.openFile(file.path);
      try {
        final page = await doc.getPage(pageNumber);
        try {
          final pageImage = await page.render(
            width: page.width / 2,
            height: page.height / 2,
            format: PdfPageImageFormat.png,
          );
          return pageImage?.bytes;
        } finally {
          await page.close();
        }
      } finally {
        await doc.close();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    if (project == null) {
      return Center(child: Text(_error ?? 'Opening local project…'));
    }
    final width = MediaQuery.sizeOf(context).width;
    final settings = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _choice('Booklet pages (new project)', ['8', '16'], '$_signature', (
          value,
        ) {
          setState(() => _signature = int.parse(value));
          _start();
        }),
        _choice(
          'Paper size',
          ['A4', 'US-Letter'],
          project.paperSize,
          (value) => _change(
            (store, snapshot) =>
                store.updatePrintSettings(snapshot, paperSize: value),
          ),
        ),
        _choice(
          'Duplex flip edge',
          ['short', 'long'],
          project.flipEdge,
          (value) => _change(
            (store, snapshot) =>
                store.updatePrintSettings(snapshot, flipEdge: value),
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Color(0xffb00020))),
        const SizedBox(height: 12),
      ],
    );
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 14, color: Color(0xff203e63)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            settings,
            if (width >= 900)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _pageGrid(project)),
                  const SizedBox(width: 20),
                  Expanded(child: _preview(project)),
                ],
              )
            else ...[
              _pageGrid(project),
              const SizedBox(height: 24),
              _preview(project),
            ],
          ],
        ),
      ),
    );
  }
}
