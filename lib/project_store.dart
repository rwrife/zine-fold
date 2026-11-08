import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';

/// One page within an app-owned copy. PDF pages share one copied file.
class ProjectPage {
  const ProjectPage(this.fileName, this.sourcePage);

  final String fileName;
  final int sourcePage; // 1-based; images always use page 1.
}

class ZineProject {
  const ZineProject(this.id, this.signature, this.revision, this.pages);

  final String id;
  final int signature;
  final int revision;
  final List<ProjectPage?> pages;
}

typedef PageCounter = Future<int> Function(File file, String extension);

/// Local-only project store. Call [inAppDocuments] for platform-private root.
class ProjectStore {
  ProjectStore(this.root, {PageCounter? countPages})
    : _countPages = countPages ?? _defaultPageCounter;

  final Directory root;
  final PageCounter _countPages;
  static final Map<String, Future<void>> _pending = {};
  static const maxFileBytes = 50 * 1024 * 1024;

  static Future<ProjectStore> inAppDocuments() async => ProjectStore(
    Directory('${(await getApplicationDocumentsDirectory()).path}/zinefold'),
  );

  /// Native OS picker; only invoked on explicit user action. A cancelled pick
  /// leaves the project untouched.
  Future<ZineProject?> pickAndImport(ZineProject snapshot, int slot) async {
    const types = XTypeGroup(
      label: 'Image or PDF',
      extensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
      uniformTypeIdentifiers: ['public.image', 'com.adobe.pdf'],
    );
    final picked = await openFile(acceptedTypeGroups: [types]);
    if (picked == null) return null;
    return importFile(snapshot, slot, File(picked.path));
  }

  static String _id() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  // Same-process queue supplements OS lock, which does not serialize all
  // asynchronous writers within one Dart isolate.
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final key = root.absolute.path;
    final previous = _pending[key];
    final done = Completer<void>();
    _pending[key] = done.future;
    if (previous != null) await previous;
    try {
      await root.create(recursive: true);
      final lock = await File('${root.path}/.lock').open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.exclusive);
        return await action();
      } finally {
        await lock.unlock();
        await lock.close();
      }
    } finally {
      if (identical(_pending[key], done.future)) _pending.remove(key);
      done.complete();
    }
  }

  Directory _directory(String id) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw const FormatException('Invalid project ID');
    }
    return Directory('${root.path}${Platform.pathSeparator}$id');
  }

  Future<ZineProject> create({required int signature}) => _exclusive(() async {
    if (signature != 8 && signature != 16) {
      throw ArgumentError.value(signature, 'signature', 'Expected 8 or 16');
    }
    final project = ZineProject(
      _id(),
      signature,
      0,
      List<ProjectPage?>.filled(signature, null),
    );
    final directory = _directory(project.id);
    await directory.create();
    await _save(directory, project);
    return project;
  });

  Future<ZineProject> open(String id) =>
      _exclusive(() => _read(_directory(id)));

  /// [slot] is zero-based; never overwrite populated slots or a newer revision.
  Future<ZineProject> importFile(ZineProject snapshot, int slot, File source) =>
      _exclusive(() async {
        final directory = _directory(snapshot.id);
        final current = await _read(directory);
        if (current.revision != snapshot.revision) {
          throw StateError('Project changed; reopen before importing');
        }
        if (slot < 0 || slot >= current.signature) {
          throw RangeError.range(slot, 0, current.signature - 1, 'slot');
        }
        final extension = source.path.split('.').last.toLowerCase();
        if (!['png', 'jpg', 'jpeg', 'webp', 'pdf'].contains(extension)) {
          throw const FormatException('Unsupported file type');
        }
        if (!await source.exists()) {
          throw FileSystemException('Source missing', source.path);
        }
        final length = await source.length();
        if (length == 0 || length > maxFileBytes) {
          throw const FormatException('File empty or exceeds 50 MB');
        }
        final fileName = '${_id()}.$extension';
        final staged = File('${directory.path}/$fileName.part');
        final copied = File('${directory.path}/$fileName');
        try {
          // Recheck size while copying: source may grow after initial stat.
          final sink = staged.openWrite();
          try {
            var copiedBytes = 0;
            await for (final chunk in source.openRead()) {
              copiedBytes += chunk.length;
              if (copiedBytes > maxFileBytes) {
                throw const FormatException('File exceeds 50 MB');
              }
              sink.add(chunk);
            }
          } finally {
            await sink.close();
          }
          final count = await _countPages(staged, extension);
          if (count < 1 ||
              count > current.signature ||
              slot + count > current.signature) {
            throw const FormatException('Invalid page count for booklet');
          }
          if (current.pages
              .skip(slot)
              .take(count)
              .any((page) => page != null)) {
            throw StateError('Cannot overwrite an imported page');
          }
          final pages = List<ProjectPage?>.of(current.pages);
          for (var i = 0; i < count; i++) {
            pages[slot + i] = ProjectPage(fileName, i + 1);
          }
          await staged.rename(copied.path);
          final updated = ZineProject(
            current.id,
            current.signature,
            current.revision + 1,
            pages,
          );
          await _save(directory, updated);
          return updated;
        } finally {
          if (await staged.exists()) await staged.delete();
          // Failed saves may leave an unreferenced copy; never delete a file
          // referenced by a successfully committed manifest.
        }
      });

  Future<void> _save(Directory directory, ZineProject project) async {
    final manifest = File('${directory.path}/project.json');
    final staged = File('${directory.path}/project.json.${_id()}.part');
    final bytes = utf8.encode(
      jsonEncode({
        'version': 1,
        'id': project.id,
        'signature': project.signature,
        'revision': project.revision,
        'pages': [
          for (final page in project.pages)
            if (page == null)
              null
            else
              {'file': page.fileName, 'page': page.sourcePage},
        ],
      }),
    );
    try {
      final handle = await staged.open(mode: FileMode.write);
      try {
        await handle.writeFrom(bytes);
        await handle.flush();
      } finally {
        await handle.close();
      }
      await staged.rename(manifest.path);
    } finally {
      if (await staged.exists()) await staged.delete();
    }
  }

  Future<ZineProject> _read(Directory directory) async {
    final manifest = File('${directory.path}/project.json');
    final Object? data;
    try {
      data = jsonDecode(await manifest.readAsString());
    } on FormatException {
      throw const FormatException(
        'Malformed project manifest; original left intact',
      );
    }
    if (data is! Map<String, dynamic> ||
        data['version'] != 1 ||
        data['id'] != directory.path.split(Platform.pathSeparator).last ||
        (data['signature'] != 8 && data['signature'] != 16) ||
        data['revision'] is! int ||
        (data['revision'] as int) < 0 ||
        data['pages'] is! List ||
        (data['pages'] as List).length != data['signature']) {
      throw const FormatException(
        'Invalid project manifest; original left intact',
      );
    }
    final pages = <ProjectPage?>[];
    for (final entry in data['pages'] as List) {
      if (entry == null) {
        pages.add(null);
        continue;
      }
      if (entry is! Map ||
          entry['file'] is! String ||
          !RegExp(r'^[a-f0-9]{32}\.(png|jpg|jpeg|webp|pdf)$')
              .hasMatch(entry['file'] as String) ||
          entry['page'] is! int ||
          (entry['page'] as int) < 1 ||
          (entry['page'] as int) > data['signature'] ||
          (entry['file'] as String).endsWith('.pdf') == false &&
              entry['page'] != 1) {
        throw const FormatException(
          'Invalid page reference; original left intact',
        );
      }
      final page = ProjectPage(entry['file'] as String, entry['page'] as int);
      if (!await File('${directory.path}/${page.fileName}').exists()) {
        throw FileSystemException('Imported page missing', page.fileName);
      }
      pages.add(page);
    }
    return ZineProject(
      data['id'] as String,
      data['signature'] as int,
      data['revision'] as int,
      pages,
    );
  }

  static Future<int> _defaultPageCounter(File file, String extension) async {
    if (extension == 'pdf') {
      final header = await file.openRead(0, 5).first;
      if (ascii.decode(header, allowInvalid: true) != '%PDF-') {
        throw const FormatException('Invalid PDF header');
      }
      final document = await PdfDocument.openFile(file.path);
      try {
        return document.pagesCount;
      } finally {
        await document.close();
      }
    }
    final bytes = await file.readAsBytes();
    final magicMatches = switch (extension) {
      'png' =>
        bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            ascii.decode(bytes.sublist(1, 4), allowInvalid: true) == 'PNG',
      'jpg' || 'jpeg' =>
        bytes.length >= 3 &&
            bytes[0] == 0xff &&
            bytes[1] == 0xd8 &&
            bytes[2] == 0xff,
      'webp' =>
        bytes.length >= 12 &&
            ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
            ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP',
      _ => false,
    };
    if (!magicMatches || img.decodeImage(bytes) == null) {
      throw const FormatException('Invalid image');
    }
    return 1;
  }
}
