import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import '../models/note_block.dart';

// Restores notes from the JSON files written by NoteExporter.
class NoteImporter {
  static const XTypeGroup _jsonTypeGroup = XTypeGroup(
    label: 'JSON note',
    extensions: ['json'],
    mimeTypes: ['application/json'],
    uniformTypeIdentifiers: ['public.json'],
  );

  // Opens a file picker and returns the selected note, if any.
  Future<Map<String, String>?> pickAndImport() async {
    final file = await openFile(
      acceptedTypeGroups: const [_jsonTypeGroup],
    );

    if (file == null) return null;

    return parse(await file.readAsString());
  }

  // Converts an exported JSON note back into the format used by the app.
  Map<String, String> parse(String raw) {
    final dynamic decoded;

    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('The selected file is not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The selected file is not a note.');
    }

    final rawBlocks = decoded['blocks'];

    if (rawBlocks is! List) {
      throw const FormatException('The selected file has no note blocks.');
    }

    final blocks = <NoteBlockData>[];

    for (final rawBlock in rawBlocks) {
      if (rawBlock is! Map<String, dynamic>) {
        throw const FormatException('The selected file has an invalid block.');
      }

      try {
        blocks.add(NoteBlockData.fromJson(rawBlock));
      } catch (_) {
        throw const FormatException('The selected file has an invalid block.');
      }
    }

    final title = decoded['title'];

    if (title != null && title is! String) {
      throw const FormatException('The selected file has an invalid title.');
    }

    final content = blocks
        .where((block) => block.type == NoteBlockType.text)
        .map((block) => block.text)
        .join('\n\n');

    return <String, String>{
      'title': title as String? ?? '',
      'content': content,
      'blocks': encodeBlocks(blocks),
    };
  }
}
