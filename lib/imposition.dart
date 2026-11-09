/// Booklet imposition for nested saddle-stitched signatures.
class BookletImposition {
  BookletImposition._();

  static const supportedSignatures = [8, 16];

  /// Standard landscape sheet duplex orientation.
  static const duplexInstruction =
      'Print double-sided, flipping on the short edge (landscape).';

  static String instructionForFlip(String flipEdge) {
    if (flipEdge == 'long') {
      return 'Print double-sided, flipping on the long edge (portrait feed). Warning: may cause upside-down booklet pages unless printer driver handles landscape orientation inversion.';
    }
    return duplexInstruction;
  }

  static const foldGuidance =
      'After printing both sides, fold each sheet in half along the vertical center crease. Assemble the folded sheets nested in numerical order (Sheet 1 outer cover, Sheet 2 inside), then staple along the center spine (saddle-stitch).';

  /// Map sequential reading pages into sheets with front/back slots.
  ///
  /// Supplied pages map to reading order (1-indexed). Null elements or counts
  /// shorter than [signature] become blank pages.
  static List<ImposedSheet> impose(
    List<String?> readingPages, {
    int signature = 8,
  }) {
    if (!supportedSignatures.contains(signature)) {
      throw ArgumentError.value(
        signature,
        'signature',
        'Signature must be 8 or 16 pages.',
      );
    }
    if (readingPages.isEmpty || readingPages.length > signature) {
      throw ArgumentError.value(
        readingPages.length,
        'readingPages',
        'Reading pages count must be between 1 and $signature.',
      );
    }

    final observed = <String>{};
    for (final page in readingPages) {
      if (page == null) continue;
      if (page.isEmpty) {
        throw ArgumentError.value(
          page,
          'readingPages',
          'Page ID cannot be empty.',
        );
      }
      if (!observed.add(page)) {
        throw ArgumentError.value(
          page,
          'readingPages',
          'Duplicate page ID: $page',
        );
      }
    }

    final slots = List<PageSlot>.generate(signature, (index) {
      final pageNumber = index + 1;
      final pageId = index < readingPages.length ? readingPages[index] : null;
      return PageSlot(pageNumber: pageNumber, pageId: pageId);
    });

    final sheetCount = signature ~/ 4;
    return List.generate(sheetCount, (sheetIndex) {
      // Outer-to-inner nested sheet numbering.
      final frontLeftNumber = signature - (sheetIndex * 2);
      final frontRightNumber = 1 + (sheetIndex * 2);
      final backLeftNumber = 2 + (sheetIndex * 2);
      final backRightNumber = signature - 1 - (sheetIndex * 2);

      return ImposedSheet(
        sheetNumber: sheetIndex + 1,
        front: SheetSide(
          left: slots[frontLeftNumber - 1],
          right: slots[frontRightNumber - 1],
        ),
        back: SheetSide(
          left: slots[backLeftNumber - 1],
          right: slots[backRightNumber - 1],
        ),
      );
    });
  }
}

class ImposedSheet {
  const ImposedSheet({
    required this.sheetNumber,
    required this.front,
    required this.back,
  });

  final int sheetNumber;
  final SheetSide front;
  final SheetSide back;

  List<PageSlot> get slots => [front.left, front.right, back.left, back.right];
}

class SheetSide {
  const SheetSide({required this.left, required this.right});

  final PageSlot left;
  final PageSlot right;
}

class PageSlot {
  const PageSlot({required this.pageNumber, this.pageId});

  final int pageNumber;
  final String? pageId;

  bool get isBlank => pageId == null;

  @override
  String toString() => 'PageSlot($pageNumber: ${pageId ?? "blank"})';
}
