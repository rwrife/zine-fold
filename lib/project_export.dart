import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

import 'imposition.dart';
import 'project_store.dart';

/// Portable output. No printer-driver alignment or registration guarantee.
class ProjectExport {
  ProjectExport(this.store, {this.renderPdfPage});

  static String _id() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  final ProjectStore store;

  /// Test seam; production rasterizes each imported PDF page locally.
  final Future<Uint8List> Function(File, int)? renderPdfPage;

  static const _maxArchiveBytes = 16 * ProjectStore.maxFileBytes + 1024 * 1024;
  static final _assetName = RegExp(r'^[a-f0-9]{32}\.(png|jpg|jpeg|webp|pdf)$');

  Future<Uint8List> _raster(File file, int page) async {
    if (renderPdfPage != null) return renderPdfPage!(file, page);
    final document = await pdfx.PdfDocument.openFile(file.path);
    try {
      final pdfPage = await document.getPage(page);
      try {
        final rendered = await pdfPage.render(
          width: pdfPage.width * 2,
          height: pdfPage.height * 2,
          format: pdfx.PdfPageImageFormat.png,
        );
        if (rendered == null) {
          throw const FormatException('PDF page cannot render');
        }
        return rendered.bytes;
      } finally {
        await pdfPage.close();
      }
    } finally {
      await document.close();
    }
  }

  /// Builds front/back pairs in outer-to-inner order; rasterized source pages
  /// are centered without cropping. Empty slots remain visibly numbered.
  Future<Uint8List> printSheets(ZineProject snapshot) async {
    final project = await store.open(snapshot.id);
    if (project.revision != snapshot.revision) {
      throw StateError('Project changed; reopen before exporting');
    }
    final sheetSize = project.paperSize == 'A4'
        ? PdfPageFormat.a4
        : PdfPageFormat.letter;
    final landscape = PdfPageFormat(sheetSize.height, sheetSize.width);
    final document = pw.Document(compress: true);
    final images = <int, pw.MemoryImage>{};
    for (var index = 0; index < project.signature; index++) {
      final page = project.pages[index];
      if (page == null || page.isBlank) continue;
      final file = File('${store.root.path}/${project.id}/${page.fileName}');
      final raw = page.fileName.endsWith('.pdf')
          ? await _raster(file, page.sourcePage)
          : await file.readAsBytes();
      final decoded = img.decodeImage(raw);
      if (decoded == null) {
        throw FormatException('Cannot render page ${index + 1}');
      }
      images[index + 1] = pw.MemoryImage(
        Uint8List.fromList(img.encodePng(decoded)),
      );
    }
    final sheets = BookletImposition.impose([
      for (var index = 0; index < project.signature; index++)
        project.pages[index] == null || project.pages[index]!.isBlank
            ? null
            : 'page-$index',
    ], signature: project.signature);
    for (final sheet in sheets) {
      for (final side in [sheet.front, sheet.back]) {
        final front = identical(side, sheet.front);
        document.addPage(
          pw.Page(
            pageFormat: landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (_) => pw.Column(
              children: [
                pw.Text(
                  'Sheet ${sheet.sheetNumber} / ${sheets.length}  -  ${front ? 'Front' : 'Back'}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      _slot(side.left, images),
                      pw.Container(
                        width: 1,
                        color: PdfColors.grey600,
                      ), // fold guide
                      _slot(side.right, images),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  BookletImposition.instructionForFlip(project.flipEdge),
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'Fold at center line. Print one proof; printer alignment is not guaranteed.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        );
      }
    }
    return Uint8List.fromList(await document.save());
  }

  pw.Widget _slot(PageSlot slot, Map<int, pw.MemoryImage> images) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Page ${slot.pageNumber}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Expanded(
                child: images[slot.pageNumber] == null
                    ? pw.Center(child: pw.Text('Blank'))
                    : pw.Image(
                        images[slot.pageNumber]!,
                        fit: pw.BoxFit.contain,
                      ),
              ),
            ],
          ),
        ),
      );

  /// Saves only app-owned copies. Refuses stale snapshots and missing assets.
  Future<Uint8List> backup(ZineProject snapshot) async {
    final project = await store.open(snapshot.id);
    if (project.revision != snapshot.revision) {
      throw StateError('Project changed; reopen before backing up');
    }
    final directory = Directory('${store.root.path}/${project.id}');
    final archive = Archive();
    final manifest = await File('${directory.path}/project.json').readAsBytes();
    if (manifest.length > 65536) {
      throw const FormatException('Manifest too large');
    }
    archive.add(ArchiveFile.bytes('project.json', manifest));
    for (final name
        in project.pages
            .whereType<ProjectPage>()
            .where((page) => !page.isBlank)
            .map((page) => page.fileName)
            .toSet()) {
      final bytes = await File('${directory.path}/$name').readAsBytes();
      if (bytes.isEmpty || bytes.length > ProjectStore.maxFileBytes) {
        throw const FormatException('Asset empty or too large');
      }
      archive.add(ArchiveFile.bytes(name, bytes));
    }
    // ponytail: in-memory ZIP bounded by 16 assets; stream when larger signatures arrive.
    return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  }

  /// Restores as a new project only. Never replaces existing data, even on
  /// corrupt ZIP, invalid manifest, missing page, or destination failure.
  Future<ZineProject> restore(File source) async {
    final size = await source.length();
    if (size == 0 || size > _maxArchiveBytes) {
      throw const FormatException('Backup empty or too large');
    }
    final decoder = ZipDecoder();
    final archive = decoder.decodeBytes(
      await source.readAsBytes(),
      verify: true,
    );
    if (archive.isEmpty ||
        archive.length > 17 ||
        archive.length != decoder.directory.fileHeaders.length) {
      throw const FormatException('Invalid backup entries');
    }
    final entries = <String, Uint8List>{};
    var total = 0;
    for (final entry in archive) {
      if (!entry.isFile ||
          entry.isSymbolicLink ||
          entry.isHardLink ||
          entry.name != 'project.json' && !_assetName.hasMatch(entry.name) ||
          entry.size < 0 ||
          entry.size > ProjectStore.maxFileBytes ||
          entry.name == 'project.json' && entry.size > 65536) {
        throw const FormatException('Invalid backup path or size');
      }
      total += entry.size;
      if (total > _maxArchiveBytes) {
        throw const FormatException('Backup too large');
      }
      final bytes = entry.readBytes();
      if (bytes == null || bytes.length != entry.size || bytes.isEmpty) {
        throw const FormatException('Invalid backup entry');
      }
      entries[entry.name] = bytes;
    }
    final manifest = entries['project.json'];
    if (manifest == null) throw const FormatException('Missing manifest');
    final Object? data = jsonDecode(utf8.decode(manifest));
    if (data is! Map<String, dynamic> ||
        data['id'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(data['id'] as String)) {
      throw const FormatException('Invalid project ID in backup');
    }
    // Restored project gets a fresh ID so imports never collide with existing data.
    final id = _id();
    await store.root.create(recursive: true);
    final target = Directory('${store.root.path}/$id');
    final staging = await store.root.createTemp('.restore-');
    final candidate = Directory('${staging.path}/$id');
    try {
      await candidate.create();
      for (final entry in entries.entries) {
        if (entry.key == 'project.json') continue;
        await File('${candidate.path}/${entry.key}')
            .writeAsBytes(entry.value, flush: true);
      }
      final stagedStore = ProjectStore(staging);
      final rawManifest = Map<String, dynamic>.from(data);
      rawManifest['id'] = id;
      await File('${candidate.path}/project.json')
          .writeAsString(jsonEncode(rawManifest), flush: true);
      final project = await stagedStore.open(id);
      final referenced = project.pages
          .whereType<ProjectPage>()
          .where((page) => !page.isBlank)
          .map((page) => page.fileName)
          .toSet();
      if (entries.keys.toSet().difference({
            'project.json',
            ...referenced,
          }).isNotEmpty ||
          referenced.difference(entries.keys.toSet()).isNotEmpty) {
        throw const FormatException('Unexpected or missing backup assets');
      }
      for (final name in referenced) {
        final bytes = entries[name]!;
        if (bytes.length > ProjectStore.maxFileBytes || bytes.isEmpty) {
          throw const FormatException('Invalid asset size');
        }
        if (name.endsWith('.pdf')) {
          if (bytes.length < 5 ||
              ascii.decode(bytes.sublist(0, 5)) != '%PDF-') {
            throw const FormatException('Invalid PDF asset');
          }
          final pdf = await pdfx.PdfDocument.openFile(
            '${candidate.path}/$name',
          );
          try {
            if (pdf.pagesCount < 1 ||
                pdf.pagesCount > project.signature ||
                project.pages.whereType<ProjectPage>().any(
                  (page) =>
                      page.fileName == name && page.sourcePage > pdf.pagesCount,
                )) {
              throw const FormatException('Invalid PDF page reference');
            }
          } finally {
            await pdf.close();
          }
        } else if (img.decodeImage(bytes) == null) {
          throw const FormatException('Invalid image asset');
        }
      }
      if (await target.exists()) {
        throw StateError('Destination already exists; original left intact');
      }
      await candidate.rename(target.path);
      return project;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Claims a fresh destination exclusively; never truncates existing data.
  Future<void> saveNew(File destination, Uint8List bytes) async {
    await destination.create(exclusive: true);
    try {
      await destination.writeAsBytes(bytes, flush: true);
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }
}
