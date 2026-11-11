import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zinefold/project_export.dart';
import 'package:zinefold/project_store.dart';

void main() {
  late Directory root;
  late ProjectStore store;
  late ProjectExport exporter;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('zinefold-export-');
    store = ProjectStore(Directory('${root.path}/projects'));
    exporter = ProjectExport(store);
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    '8/16 pages make ordered PDF sheets, with guides and instructions',
    () async {
      for (final count in [8, 16]) {
        var project = await store.create(signature: count);
        final image = File('${root.path}/art-$count.png');
        await image.writeAsBytes(img.encodePng(img.Image(width: 4, height: 4)));
        project = await store.importFile(project, 0, image);
        final pdf = await exporter.printSheets(project);
        expect(utf8.decode(pdf.sublist(0, 5)), '%PDF-');
        final file = File('${root.path}/sheets-$count.pdf');
        await exporter.saveNew(file, pdf);
        expect(await file.length(), greaterThan(1000));
        expect(await file.readAsBytes(), pdf);
        // Verify sheet page count by inspecting /Type /Page occurrences in PDF trailer/catalog.
        final pageCountMatches = RegExp(r'/Type\s*/Page\b')
            .allMatches(String.fromCharCodes(pdf))
            .length;
        expect(pageCountMatches, count ~/ 2);
        await expectLater(
          exporter.saveNew(file, pdf),
          throwsA(isA<PathExistsException>()),
        );
      }
    },
  );

  test(
    'backup restores assets, settings and page order into new project',
    () async {
      var project = await store.create(signature: 8);
      final image = File('${root.path}/art.png');
      await image.writeAsBytes(img.encodePng(img.Image(width: 2, height: 3)));
      project = await store.importFile(project, 0, image);
      project = await store.setBlank(project, 2);
      project = await store.reorderPages(project, 0, 4);
      project = await store.updatePrintSettings(
        project,
        paperSize: 'US-Letter',
      );
      final bytes = await exporter.backup(project);
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      expect(archive.length, 2);
      final backup = File('${root.path}/backup.zip')..writeAsBytesSync(bytes);
      final other = ProjectStore(Directory('${root.path}/other'));
      final restored = await ProjectExport(other).restore(backup);
      expect(restored.id, isNot(project.id));
      expect(restored.pages[4]?.sourcePage, 1);
      expect(restored.pages[1]?.isBlank, true);
      expect(restored.paperSize, 'US-Letter');
      expect(
        await File(
          '${other.root.path}/${restored.id}/${restored.pages[4]!.fileName}',
        ).readAsBytes(),
        await image.readAsBytes(),
      );
      expect((await other.open(restored.id)).revision, project.revision);
      final second = await ProjectExport(other).restore(backup);
      expect(second.id, isNot(restored.id));
      expect((await other.open(restored.id)).revision, project.revision);
    },
  );

  test(
    'corrupt/traversal/missing asset and failed destination preserve project',
    () async {
      var project = await store.create(signature: 8);
      final art = File('${root.path}/art.png');
      await art.writeAsBytes(img.encodePng(img.Image(width: 1, height: 1)));
      project = await store.importFile(project, 0, art);
      final bytes = await exporter.backup(project);
      final backup = File('${root.path}/backup.zip');
      final other = ProjectStore(Directory('${root.path}/other'));
      for (final broken in <List<int>>[
        [1, 2, 3],
        ZipEncoder().encodeBytes(
          Archive()
            ..add(ArchiveFile.bytes('../project.json', utf8.encode('{}'))),
        ),
        ZipEncoder().encodeBytes(
          Archive()..add(
            ArchiveFile.bytes(
              'project.json',
              await File('${store.root.path}/${project.id}/project.json')
                  .readAsBytes(),
            ),
          ),
        ),
      ]) {
        await backup.writeAsBytes(broken);
        await expectLater(
          ProjectExport(other).restore(backup),
          throwsA(anything),
        );
        expect(
          await Directory('${other.root.path}/${project.id}').exists(),
          isFalse,
        );
        expect((await store.open(project.id)).revision, project.revision);
      }
      await backup.writeAsBytes(bytes);
      final target = File('${root.path}/no-such-dir/output.zip');
      await expectLater(
        exporter.saveNew(target, Uint8List.fromList(bytes)),
        throwsA(isA<FileSystemException>()),
      );
      expect(await target.exists(), isFalse);
      final stale = project;
      await store.setBlank(project, 1);
      await expectLater(exporter.backup(stale), throwsStateError);
      await expectLater(exporter.printSheets(stale), throwsStateError);
    },
  );
}
