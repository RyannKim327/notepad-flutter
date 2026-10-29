import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:notepad/models/note_block.dart';
import 'package:notepad/services/note_exporter.dart';

void main() {
  final note = <String, String>{
    'title': 'Ideas',
    'blocks': encodeBlocks([
      const NoteBlockData.text('Sketch below'),
      NoteBlockData.drawing([
        [const Offset(1, 2), const Offset(20, 40)],
      ]),
    ]),
  };

  test('builds a PDF document', () async {
    final bytes = await NoteExporter().buildPdf(note);

    expect(bytes.length, greaterThan(4));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('builds a JSON document with all blocks', () {
    final bytes = NoteExporter().buildJson(note);
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

    expect(decoded['title'], 'Ideas');
    expect(decoded['blocks'], hasLength(2));
    expect((decoded['blocks'] as List).first['type'], 'text');
    expect((decoded['blocks'] as List).last['type'], 'drawing');
  });
}
