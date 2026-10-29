import 'package:flutter/material.dart';

import '../models/note_block.dart';
import '../widgets/drawing_canvas.dart';

// Mixed-content note editor: blocks of typed text and hand drawings.
class NoteEditorPage extends StatefulWidget {
  final Map<String, String>? existingNote;

  const NoteEditorPage({super.key, this.existingNote});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _EditorBlock {
  _EditorBlock.text({String text = ''})
    : type = NoteBlockType.text,
      controller = TextEditingController(text: text),
      strokes = const [];

  _EditorBlock.drawing(List<List<Offset>> strokes)
    : type = NoteBlockType.drawing,
      controller = null,
      strokes = strokes;

  final NoteBlockType type;

  final TextEditingController? controller;

  final List<List<Offset>> strokes;

  final Key key = UniqueKey();

  final GlobalKey<DrawingCanvasState> canvasKey =
      GlobalKey<DrawingCanvasState>();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _titleController;

  final List<_EditorBlock> _blocks = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.existingNote?['title'] ?? '',
    );

    final existingBlocks = widget.existingNote == null
        ? <NoteBlockData>[]
        : decodeBlocks(widget.existingNote!);

    if (existingBlocks.isEmpty) {
      _blocks.add(_EditorBlock.text());
    } else {
      for (final block in existingBlocks) {
        _blocks.add(
          block.type == NoteBlockType.text
              ? _EditorBlock.text(text: block.text)
              : _EditorBlock.drawing(block.strokes),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();

    for (final block in _blocks) {
      block.controller?.dispose();
    }

    _scrollController.dispose();
    super.dispose();
  }

  void _addTextBlock() {
    setState(() {
      _blocks.add(_EditorBlock.text());
    });

    _scrollToEnd();
  }

  void _addSketchBlock() {
    setState(() {
      _blocks.add(_EditorBlock.drawing(const []));
    });

    _scrollToEnd();
  }

  void _removeBlock(_EditorBlock block) {
    setState(() {
      _blocks.remove(block);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      block.controller?.dispose();
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _save() {
    final title = _titleController.text.trim();

    final savedBlocks = <NoteBlockData>[];

    for (final block in _blocks) {
      if (block.type == NoteBlockType.text) {
        final text = block.controller!.text.trim();

        if (text.isNotEmpty) {
          savedBlocks.add(NoteBlockData.text(text));
        }
      } else {
        final strokes =
            (block.canvasKey.currentState?.allStrokes ?? block.strokes)
                .where((stroke) => stroke.isNotEmpty)
                .toList();

        if (strokes.isNotEmpty) {
          savedBlocks.add(NoteBlockData.drawing(strokes));
        }
      }
    }

    if (title.isEmpty && savedBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type or sketch something first.')),
      );
      return;
    }

    final content = savedBlocks
        .where((block) => block.type == NoteBlockType.text)
        .map((block) => block.text)
        .join('\n\n');

    Navigator.pop(context, <String, String>{
      'title': title,
      'content': content,
      'blocks': encodeBlocks(savedBlocks),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingNote != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF2),
        title: Text(
          isEditing ? 'Edit Note' : 'New Note',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('note-title'),
              controller: _titleController,
              autofocus: !isEditing,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter note title',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            for (final block in _blocks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBlock(block),
              ),

            const SizedBox(height: 4),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addTextBlock,
                    icon: const Icon(Icons.keyboard_outlined),
                    label: const Text('Add text'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addSketchBlock,
                    icon: const Icon(Icons.draw_outlined),
                    label: const Text('Add sketch'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(_EditorBlock block) {
    if (block.type == NoteBlockType.text) {
      return Card(
        key: block.key,
        color: Colors.white,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: block.controller,
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Type something...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(8),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove text',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _removeBlock(block);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      key: block.key,
      color: Colors.white,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.draw_outlined,
                  size: 18,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sketch',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove sketch',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _removeBlock(block);
                  },
                ),
              ],
            ),
            SizedBox(
              height: 240,
              child: DrawingCanvas(
                key: block.canvasKey,
                initialStrokes: block.strokes,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
