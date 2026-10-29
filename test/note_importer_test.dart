import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:notebook/models/note_block.dart';
import 'package:notebook/services/note_exporter.dart';
import 'package:notebook/services/note_importer.dart';

void main() {
  test('round trips an exported JSON note', () {
    final exported = NoteExporter().buildJson({
      'title': 'Ideas',
      'blocks': encodeBlocks([
        const NoteBlockData.text('Sketch below'),
        NoteBlockData.drawing([
          [const Offset(1, 2), const Offset(20, 40)],
        ]),
      ]),
    });

    final note = NoteImporter().parse(utf8.decode(exported));
    final blocks = decodeBlocks(note);

    expect(note['title'], 'Ideas');
    expect(note['content'], 'Sketch below');
    expect(blocks, hasLength(2));
    expect(blocks.first.type, NoteBlockType.text);
    expect(blocks.last.type, NoteBlockType.drawing);
    expect(blocks.last.strokes.single.last, const Offset(20, 40));
  });

  test('rejects files that are not exported notes', () {
    expect(
      () => NoteImporter().parse('not json'),
      throwsFormatException,
    );
    expect(
      () => NoteImporter().parse(jsonEncode({'title': 'No blocks'})),
      throwsFormatException,
    );
  });
}
