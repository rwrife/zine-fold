import 'package:flutter_test/flutter_test.dart';
import 'package:zinefold/imposition.dart';

void main() {
  test('8- and 16-page saddle fold places each page exactly once', () {
    final expected = <int, List<List<int>>>{
      8: [
        [8, 1, 2, 7],
        [6, 3, 4, 5],
      ],
      16: [
        [16, 1, 2, 15],
        [14, 3, 4, 13],
        [12, 5, 6, 11],
        [10, 7, 8, 9],
      ],
    };
    for (final entry in expected.entries) {
      final pages = List.generate(entry.key, (index) => 'page-${index + 1}');
      final sheets = BookletImposition.impose(pages, signature: entry.key);
      expect(sheets.length, entry.key ~/ 4);
      for (var index = 0; index < sheets.length; index++) {
        final sheet = sheets[index];
        final positions = entry.value[index];
        expect(sheet.front.left.pageId, pages[positions[0] - 1]);
        expect(sheet.front.right.pageId, pages[positions[1] - 1]);
        expect(sheet.back.left.pageId, pages[positions[2] - 1]);
        expect(sheet.back.right.pageId, pages[positions[3] - 1]);
      }
      final placed = [
        for (final sheet in sheets) ...sheet.slots.map((slot) => slot.pageId),
      ];
      expect(placed.toSet(), pages.toSet());
      expect(placed.length, pages.length);
      // Folding each nested sheet reveals consecutive reading pages.
      for (var page = 1; page <= entry.key; page += 2) {
        final sheet =
            sheets[(page - 1) ~/ 2 < sheets.length
                ? (page - 1) ~/ 2
                : (entry.key - page) ~/ 2];
        final ids = sheet.slots.map((slot) => slot.pageId).toList();
        expect(ids, contains(pages[page - 1]));
        expect(ids, contains(pages[page]));
      }
    }
  });

  test('missing and explicit blank pages retain their numbered slots', () {
    final sheets = BookletImposition.impose([
      'cover',
      null,
      'inside',
    ], signature: 8);
    expect(sheets.first.front.right.pageId, 'cover');
    expect(sheets.first.back.left.isBlank, isTrue); // explicit blank page 2
    expect(sheets[1].front.right.pageId, 'inside');
    expect(sheets[1].back.left.isBlank, isTrue); // padded page 4
    expect(sheets.first.front.left.isBlank, isTrue); // padded page 8
    expect(sheets.expand((sheet) => sheet.slots).length, 8);
  });

  test('rejects unsupported signatures, counts and duplicate page ids', () {
    expect(
      () => BookletImposition.impose(['a'], signature: 4),
      throwsArgumentError,
    );
    expect(
      () => BookletImposition.impose([], signature: 8),
      throwsArgumentError,
    );
    expect(
      () => BookletImposition.impose(List.filled(9, 'x'), signature: 8),
      throwsArgumentError,
    );
    expect(
      () => BookletImposition.impose(['a', 'a'], signature: 8),
      throwsArgumentError,
    );
    expect(
      () => BookletImposition.impose([''], signature: 8),
      throwsArgumentError,
    );
  });

  test('names landscape duplex flip direction and fold guidance', () {
    expect(BookletImposition.duplexInstruction, contains('short edge'));
    expect(
      BookletImposition.instructionForFlip('short'),
      contains('short edge'),
    );
    expect(BookletImposition.instructionForFlip('long'), contains('long edge'));
    expect(BookletImposition.foldGuidance, contains('saddle-stitch'));
  });
}
