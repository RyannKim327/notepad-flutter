import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/note_block.dart';

// File formats a note can be exported to.
enum NoteExportFormat { pdf, json }

// Builds and saves notes as stand-alone files.
class NoteExporter {
  Future<String?> exportNote(
    Map<String, String> note,
    NoteExportFormat format,
  ) async {
    final name = _safeFileName(note['title'] ?? '');

    switch (format) {
      case NoteExportFormat.pdf:
        return _save(
          name: name,
          bytes: await buildPdf(note),
          extension: 'pdf',
          mimeType: MimeType.pdf,
        );
      case NoteExportFormat.json:
        return _save(
          name: name,
          bytes: buildJson(note),
          extension: 'json',
          mimeType: MimeType.json,
        );
    }
  }

  // Ask where to save on platforms that have a save dialog, otherwise save
  // straight to the Downloads folder (or the browser's downloads on web).
  Future<String?> _save({
    required String name,
    required Uint8List bytes,
    required String extension,
    required MimeType mimeType,
  }) {
    if (_hasSaveDialog) {
      return FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        fileExtension: extension,
        mimeType: mimeType,
      );
    }

    return FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: extension,
      mimeType: mimeType,
    );
  }

  bool get _hasSaveDialog {
    if (kIsWeb) return false;

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  // Renders text and sketches into a read-only PDF document.
  Future<Uint8List> buildPdf(Map<String, String> note) async {
    final title = (note['title'] ?? '').trim();
    final blocks = decodeBlocks(note);
    final document = pw.Document();

    const margin = 40.0;
    const drawingHeight = 220.0;
    final drawingWidth = PdfPageFormat.a4.width - margin * 2;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(margin),
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              title.isEmpty ? 'Untitled Note' : title,
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF3E2723),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Exported ${_formatDate(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            pw.Container(height: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 16),
          ];

          for (final block in blocks) {
            if (block.type == NoteBlockType.text) {
              widgets.add(
                pw.Text(
                  block.text,
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
                ),
              );
            } else {
              final backgroundBytes = decodeBackgroundImage(
                block.backgroundImage,
              );

              widgets.add(
                pw.SizedBox(
                  width: drawingWidth,
                  height: drawingHeight,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                      image: backgroundBytes == null
                          ? null
                          : pw.DecorationImage(
                              image: pw.MemoryImage(backgroundBytes),
                              fit: pw.BoxFit.cover,
                            ),
                    ),
                    child: pw.CustomPaint(
                      size: PdfPoint(drawingWidth, drawingHeight),
                      painter: (canvas, size) {
                        _paintStrokes(canvas, size, block.strokes);
                      },
                    ),
                  ),
                ),
              );
            }

            widgets.add(pw.SizedBox(height: 16));
          }

          return widgets;
        },
      ),
    );

    return document.save();
  }

  // Serializes the note blocks into a portable JSON file.
  Uint8List buildJson(Map<String, String> note) {
    final data = <String, dynamic>{
      'title': note['title'] ?? '',
      'exportedAt': DateTime.now().toIso8601String(),
      'blocks': decodeBlocks(note).map((block) => block.toJson()).toList(),
    };

    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
  }

  void _paintStrokes(
    PdfGraphics graphics,
    PdfPoint size,
    List<List<Offset>> strokes,
  ) {
    final points = strokes.expand((stroke) => stroke).toList();

    if (points.isEmpty) return;

    var minX = points.first.dx;
    var minY = points.first.dy;
    var maxX = points.first.dx;
    var maxY = points.first.dy;

    for (final point in points) {
      minX = math.min(minX, point.dx);
      minY = math.min(minY, point.dy);
      maxX = math.max(maxX, point.dx);
      maxY = math.max(maxY, point.dy);
    }

    const padding = 12.0;
    final spanX = math.max(maxX - minX, 1.0);
    final spanY = math.max(maxY - minY, 1.0);
    final availableWidth = math.max(size.x - padding * 2, 1.0);
    final availableHeight = math.max(size.y - padding * 2, 1.0);
    final scale = math.min(availableWidth / spanX, availableHeight / spanY);
    final offsetX = padding + (availableWidth - spanX * scale) / 2;
    final offsetY = padding + (availableHeight - spanY * scale) / 2;

    PdfPoint transform(Offset point) {
      return PdfPoint(
        offsetX + (point.dx - minX) * scale,
        size.y - (offsetY + (point.dy - minY) * scale),
      );
    }

    const ink = PdfColor.fromInt(0xFF3E2723);

    graphics
      ..setColor(ink)
      ..setLineWidth(2)
      ..setLineCap(PdfLineCap.round)
      ..setLineJoin(PdfLineJoin.round);

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      if (stroke.length == 1) {
        final point = transform(stroke.first);

        graphics
          ..setFillColor(ink)
          ..drawEllipse(point.x, point.y, 1.2, 1.2)
          ..fillPath();
        continue;
      }

      final first = transform(stroke.first);

      graphics.moveTo(first.x, first.y);

      for (var i = 1; i < stroke.length; i++) {
        final point = transform(stroke[i]);

        graphics.lineTo(point.x, point.y);
      }

      graphics.strokePath();
    }
  }

  String _safeFileName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();

    if (cleaned.isEmpty) return 'Untitled note';

    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }

  String _formatDate(DateTime date) {
    String pad(int value) => value.toString().padLeft(2, '0');

    return '${date.year}-${pad(date.month)}-${pad(date.day)} '
        '${pad(date.hour)}:${pad(date.minute)}';
  }
}
