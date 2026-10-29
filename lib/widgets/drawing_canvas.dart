import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/note_block.dart';

// Pen colors offered in the handwriting canvas.
const List<Color> _penColors = [
  Color(0xFF3E2723),
  Color(0xFF1565C0),
  Color(0xFFC62828),
  Color(0xFF2E7D32),
];

// A freehand drawing surface for handwritten note blocks.
class DrawingCanvas extends StatefulWidget {
  final List<List<Offset>> initialStrokes;

  final String? initialBackgroundImage;

  const DrawingCanvas({
    super.key,
    this.initialStrokes = const [],
    this.initialBackgroundImage,
  });

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  static const XTypeGroup _imageTypeGroup = XTypeGroup(
    label: 'Image',
    extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
    mimeTypes: ['image/*'],
    uniformTypeIdentifiers: ['public.image'],
  );

  late final List<List<Offset>> _strokes;

  List<Offset>? _currentStroke;

  int? _activePointer;

  Color _penColor = _penColors.first;

  String? _backgroundImage;

  @override
  void initState() {
    super.initState();

    _strokes = widget.initialStrokes
        .map((stroke) => List<Offset>.from(stroke))
        .toList();

    _backgroundImage = widget.initialBackgroundImage;
  }

  // Includes the stroke that is currently being drawn, if any.
  List<List<Offset>> get allStrokes {
    return [
      ..._strokes,
      if (_currentStroke != null) List<Offset>.from(_currentStroke!),
    ];
  }

  // The base64-encoded image currently used as the canvas background.
  String? get backgroundImage => _backgroundImage;

  // Pick an image to show behind the current sketch.
  Future<void> _pickBackground() async {
    try {
      final file = await openFile(acceptedTypeGroups: const [_imageTypeGroup]);

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _backgroundImage = base64Encode(bytes);
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load image: $error')));
    }
  }

  void _removeBackground() {
    setState(() {
      _backgroundImage = null;
    });
  }

  void _startStroke(Offset position) {
    setState(() {
      _currentStroke = [position];
    });
  }

  void _extendStroke(Offset position) {
    if (_currentStroke == null) return;

    setState(() {
      _currentStroke!.add(position);
    });
  }

  void _endStroke() {
    if (_currentStroke == null) return;

    setState(() {
      if (_currentStroke!.isNotEmpty) {
        _strokes.add(_currentStroke!);
      }
      _currentStroke = null;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;

    _activePointer = event.pointer;
    _startStroke(event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;

    _extendStroke(event.localPosition);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;

    _activePointer = null;
    _endStroke();
  }

  void _undo() {
    setState(() {
      if (_currentStroke != null) {
        _currentStroke = null;
      } else if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      }
    });
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasStrokes = _strokes.isNotEmpty || _currentStroke != null;

    final backgroundBytes = decodeBackgroundImage(_backgroundImage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final color in _penColors)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _penColor = color;
                  });
                },
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _penColor == color
                          ? Colors.amber.shade700
                          : Colors.black12,
                      width: _penColor == color ? 3 : 1,
                    ),
                  ),
                ),
              ),
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Background image',
              icon: Icon(
                _backgroundImage == null ? Icons.image_outlined : Icons.image,
                color: _backgroundImage == null ? null : Colors.amber.shade800,
              ),
              onSelected: (value) {
                if (value == 'pick') {
                  _pickBackground();
                } else if (value == 'remove') {
                  _removeBackground();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pick',
                  child: ListTile(
                    leading: Icon(Icons.add_photo_alternate_outlined),
                    title: Text('Choose image'),
                  ),
                ),
                if (_backgroundImage != null)
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.hide_image_outlined),
                      title: Text('Remove image'),
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: 'Undo',
              visualDensity: VisualDensity.compact,
              onPressed: hasStrokes ? _undo : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Clear',
              visualDensity: VisualDensity.compact,
              onPressed: hasStrokes ? _clear : null,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          // Eagerly claim the gesture so the editor's scroll view
          // does not scroll while a stroke is being drawn.
          child: RawGestureDetector(
            gestures: {
              EagerGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                    (EagerGestureRecognizer instance) {},
                  ),
            },
            child: Listener(
              key: const ValueKey('drawing-canvas'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerEnd,
              onPointerCancel: _handlePointerEnd,
              child: MouseRegion(
                cursor: SystemMouseCursors.precise,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                          painter: StrokePainter(
                            strokes: allStrokes,
                            color: _penColor,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Paints freehand strokes.
class StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  final Color color;

  final double strokeWidth;

  const StrokePainter({
    required this.strokes,
    required this.color,
    this.strokeWidth = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          strokeWidth / 2,
          Paint()..color = color,
        );
        continue;
      }

      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);

      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
