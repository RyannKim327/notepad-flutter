import 'dart:convert';
import 'dart:ui';

// The kinds of content a note can contain.
enum NoteBlockType { text, drawing }

// A single piece of note content: either typed text or a sketch.
class NoteBlockData {
  final NoteBlockType type;

  final String text;

  final List<List<Offset>> strokes;

  const NoteBlockData.text(this.text)
    : type = NoteBlockType.text,
      strokes = const [];

  const NoteBlockData.drawing(this.strokes)
    : type = NoteBlockType.drawing,
      text = '';

  Map<String, dynamic> toJson() {
    if (type == NoteBlockType.text) {
      return {'type': 'text', 'text': text};
    }

    return {
      'type': 'drawing',
      'strokes': strokes
          .map((stroke) => stroke.map((point) => [point.dx, point.dy]).toList())
          .toList(),
    };
  }

  factory NoteBlockData.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'drawing') {
      final rawStrokes = json['strokes'] as List<dynamic>? ?? const [];

      final strokes = rawStrokes.map((stroke) {
        final points = stroke as List<dynamic>;

        return points.map((point) {
          final pair = point as List<dynamic>;

          return Offset(
            (pair[0] as num).toDouble(),
            (pair[1] as num).toDouble(),
          );
        }).toList();
      }).toList();

      return NoteBlockData.drawing(strokes);
    }

    return NoteBlockData.text(json['text'] as String? ?? '');
  }
}

// Serialize the blocks of a note for storage.
String encodeBlocks(List<NoteBlockData> blocks) {
  return jsonEncode(blocks.map((block) => block.toJson()).toList());
}

// Restore a note's blocks, falling back to the older text/drawing format.
List<NoteBlockData> decodeBlocks(Map<String, String> note) {
  final rawBlocks = note['blocks'];

  if (rawBlocks != null && rawBlocks.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawBlocks) as List<dynamic>;

      return decoded
          .map((block) => NoteBlockData.fromJson(block as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Ignore malformed block data and use the legacy format.
    }
  }

  final blocks = <NoteBlockData>[];

  final content = note['content'] ?? '';

  if (content.isNotEmpty) {
    blocks.add(NoteBlockData.text(content));
  }

  final drawing = decodeStrokes(note['drawing']);

  if (drawing.isNotEmpty) {
    blocks.add(NoteBlockData.drawing(drawing));
  }

  return blocks;
}

// Serialize stroke points for storage in SharedPreferences.
String encodeStrokes(List<List<Offset>> strokes) {
  return jsonEncode(
    strokes
        .map((stroke) => stroke.map((point) => [point.dx, point.dy]).toList())
        .toList(),
  );
}

// Restore stroke points saved with a note.
List<List<Offset>> decodeStrokes(String? raw) {
  if (raw == null || raw.isEmpty) return [];

  try {
    final decoded = jsonDecode(raw) as List<dynamic>;

    return decoded.map((stroke) {
      final points = stroke as List<dynamic>;

      return points.map((point) {
        final pair = point as List<dynamic>;

        return Offset((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
      }).toList();
    }).toList();
  } catch (_) {
    return [];
  }
}
