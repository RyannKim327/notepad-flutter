import 'package:flutter_test/flutter_test.dart';

import 'package:notebook/models/note_block.dart';

void main() {
  test('encode/decode round trips mixed blocks', () {
    final blocks = [
      const NoteBlockData.text('Hello'),
      NoteBlockData.drawing([
        [const Offset(1, 2), const Offset(3, 4)],
      ]),
    ];

    final decoded = decodeBlocks({
      'blocks': encodeBlocks(blocks),
    });

    expect(decoded.length, 2);
    expect(decoded[0].type, NoteBlockType.text);
    expect(decoded[0].text, 'Hello');
    expect(decoded[1].type, NoteBlockType.drawing);
    expect(decoded[1].strokes.single.first, const Offset(1, 2));
  });

  test('falls back to legacy content and drawing', () {
    final decoded = decodeBlocks({
      'content': 'Old text',
      'drawing': encodeStrokes([
        [const Offset(5, 6)],
      ]),
    });

    expect(decoded.length, 2);
    expect(decoded[0].type, NoteBlockType.text);
    expect(decoded[0].text, 'Old text');
    expect(decoded[1].type, NoteBlockType.drawing);
    expect(
      decoded[1].strokes.single.single,
      const Offset(5, 6),
    );
  });
}
