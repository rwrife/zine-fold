import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zinefold/project_store.dart';

void main() {
  late Directory root;
  late ProjectStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zinefold-project-');
    store = ProjectStore(Directory('${root.path}/projects'));
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'copies image; reopening survives source removal; refuses overwrite',
    () async {
      final source = File('${root.path}/drawing.png');
      await source.writeAsBytes(img.encodePng(img.Image(width: 2, height: 2)));
      final original = await store.create(signature: 8);
      final imported = await store.importFile(original, 0, source);
      await source.delete();
      final reopened = await store.open(original.id);
      expect(reopened.pages.first?.fileName, imported.pages.first?.fileName);
      expect(reopened.pages.first?.sourcePage, 1);
      expect(reopened.pages.skip(1).every((page) => page == null), true);
      await expectLater(
        store.importFile(imported, 0, File('${root.path}/missing.png')),
        throwsA(isA<FileSystemException>()),
      );
      final replacement = File('${root.path}/replacement.png');
      await replacement.writeAsBytes(
        img.encodePng(img.Image(width: 2, height: 2)),
      );
      await expectLater(
        store.importFile(imported, 0, replacement),
        throwsStateError,
      );
      await expectLater(
        store.importFile(original, 1, replacement),
        throwsStateError,
      );
      expect(
        (await store.open(original.id)).pages.first?.fileName,
        imported.pages.first?.fileName,
      );
    },
  );

  test(
    'malformed and unsupported input leave existing manifest unchanged',
    () async {
      final project = await store.create(signature: 16);
      final manifest = File('${root.path}/projects/${project.id}/project.json');
      final before = await manifest.readAsBytes();
      for (final filename in ['bad.png', 'bad.pdf', 'bad.txt']) {
        final source = File('${root.path}/$filename');
        await source.writeAsString('not a document');
        await expectLater(
          store.importFile(project, 0, source),
          throwsA(anything),
        );
        expect(await manifest.readAsBytes(), before);
      }
      expect((await store.open(project.id)).revision, 0);
      await manifest.writeAsString('broken');
      await expectLater(store.open(project.id), throwsFormatException);
      expect(await manifest.readAsString(), 'broken');
    },
  );

  test(
    'multipage PDF maps contiguous slots; rejects overflow without mutation',
    () async {
      final source = File('${root.path}/drawing.pdf');
      await source.writeAsString('%PDF-mock');
      final stub = ProjectStore(
        Directory('${root.path}/projects'),
        countPages: (file, extension) async {
          expect(extension, 'pdf');
          expect(await file.readAsString(), '%PDF-mock');
          return 3;
        },
      );
      final project = await store.create(signature: 8);
      final updated = await stub.importFile(project, 1, source);
      expect(updated.pages.skip(1).take(3).map((p) => p?.sourcePage), [
        1,
        2,
        3,
      ]);
      await source.delete();
      expect((await store.open(project.id)).pages[3]?.sourcePage, 3);
      final overflow = ProjectStore(
        Directory('${root.path}/projects'),
        countPages: (file, extension) async => 9,
      );
      final more = File('${root.path}/more.pdf');
      await more.writeAsString('%PDF-mock');
      await expectLater(
        overflow.importFile(updated, 4, more),
        throwsFormatException,
      );
      expect((await store.open(project.id)).revision, 1);
    },
  );

  test(
    'blank, reorder, settings persist and protect stale revisions',
    () async {
      final project = await store.create(signature: 8);
      final blank = await store.setBlank(project, 0);
      expect(blank.pages[0]?.isBlank, true);
      expect((await store.open(project.id)).pages[0]?.isBlank, true);
      final moved = await store.reorderPages(blank, 0, 7);
      expect(moved.pages[0], isNull);
      expect(moved.pages[7]?.isBlank, true);
      final changed = await store.updatePrintSettings(
        moved,
        paperSize: 'US-Letter',
        flipEdge: 'long',
      );
      final reopened = await store.open(project.id);
      expect(reopened.paperSize, 'US-Letter');
      expect(reopened.flipEdge, 'long');
      await expectLater(store.setBlank(project, 1), throwsStateError);
      await expectLater(store.reorderPages(changed, -1, 0), throwsRangeError);
      await expectLater(
        store.updatePrintSettings(changed, flipEdge: 'diagonal'),
        throwsArgumentError,
      );
      final cleared = await store.clearSlot(changed, 7);
      expect((await store.open(project.id)).pages[7], isNull);
      expect(cleared.paperSize, 'US-Letter');
      final source = File('${root.path}/imported.png');
      await source.writeAsBytes(img.encodePng(img.Image(width: 1, height: 1)));
      final imported = await store.importFile(cleared, 0, source);
      expect(imported.flipEdge, 'long');
      await expectLater(store.setBlank(imported, 0), throwsStateError);
      await expectLater(store.clearSlot(imported, 0), throwsStateError);
    },
  );

  test(
    'two store instances serialize writes and protect stale revision',
    () async {
      final project = await store.create(signature: 8);
      final a = File('${root.path}/a.png');
      final b = File('${root.path}/b.png');
      final image = img.encodePng(img.Image(width: 1, height: 1));
      await a.writeAsBytes(image);
      await b.writeAsBytes(image);
      final other = ProjectStore(Directory('${root.path}/projects'));
      final results = await Future.wait([
        store
            .importFile(project, 0, a)
            .then((_) => true, onError: (Object _) => false),
        other
            .importFile(project, 1, b)
            .then((_) => true, onError: (Object _) => false),
      ]);
      expect(results.where((result) => result).length, 1);
      expect((await store.open(project.id)).revision, 1);
    },
  );
}
