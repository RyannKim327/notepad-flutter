import 'package:flutter/material.dart';

import '../models/note_block.dart';
import '../services/note_exporter.dart';
import 'drawing_thumbnail.dart';

// A note row in the notes list, with a sketch thumbnail when present.
class NoteCard extends StatelessWidget {
  final Map<String, String> note;

  final VoidCallback onTap;

  final VoidCallback onDelete;

  final ValueChanged<NoteExportFormat> onExport;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final title = note['title'] ?? '';

    final blocks = decodeBlocks(note);

    String preview = '';
    List<List<Offset>>? sketch;
    String? sketchBackground;

    for (final block in blocks) {
      if (block.type == NoteBlockType.text) {
        final text = block.text.trim();

        if (preview.isEmpty && text.isNotEmpty) {
          preview = text;
        }
      } else if (sketch == null &&
          (block.strokes.isNotEmpty || block.backgroundImage != null)) {
        sketch = block.strokes;
        sketchBackground = block.backgroundImage;
      }
    }

    final hasSketch = sketch != null;

    if (preview.isEmpty && hasSketch) {
      preview = 'Handwritten note';
    }

    final isHandwrittenOnly = hasSketch && preview == 'Handwritten note';

    final backgroundBytes = decodeBackgroundImage(sketchBackground);

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),

        leading: hasSketch
            ? Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (backgroundBytes != null)
                        Image.memory(
                          backgroundBytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.expand();
                          },
                        ),
                      CustomPaint(
                        painter: DrawingThumbnailPainter(strokes: sketch),
                        child: const SizedBox.expand(),
                      ),
                    ],
                  ),
                ),
              )
            : null,

        title: Text(
          title.isEmpty ? 'Untitled Note' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            preview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: isHandwrittenOnly
                ? const TextStyle(fontStyle: FontStyle.italic)
                : null,
          ),
        ),

        onTap: onTap,

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<NoteExportFormat>(
              tooltip: 'Export note',
              icon: const Icon(Icons.ios_share),
              onSelected: onExport,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: NoteExportFormat.pdf,
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Export as PDF'),
                  ),
                ),
                PopupMenuItem(
                  value: NoteExportFormat.json,
                  child: ListTile(
                    leading: Icon(Icons.data_object),
                    title: Text('Export as JSON'),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
