import 'package:flutter/material.dart';

import '../models/note_block.dart';
import '../services/note_exporter.dart';
import '../widgets/drawing_canvas.dart';

// Mixed-content note editor: blocks of typed text and hand drawings.
class NoteEditorPage extends StatefulWidget {
  final Map<String, String>? existingNote;

  final List<String> folders;

  final String initialFolder;

  const NoteEditorPage({
    super.key,
    this.existingNote,
    this.folders = const [],
    this.initialFolder = '',
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _EditorBlock {
  _EditorBlock.text({String text = ''})
    : type = NoteBlockType.text,
      controller = TextEditingController(text: text),
      strokes = const [],
      backgroundImage = null;

  _EditorBlock.drawing(this.strokes, {this.backgroundImage})
    : type = NoteBlockType.drawing,
      controller = null;

  final NoteBlockType type;

  final TextEditingController? controller;

  final List<List<Offset>> strokes;

  final String? backgroundImage;

  final Key key = UniqueKey();

  final GlobalKey<DrawingCanvasState> canvasKey =
      GlobalKey<DrawingCanvasState>();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _titleController;

  late final List<String> _folders;

  late String _folder;

  final List<_EditorBlock> _blocks = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.existingNote?['title'] ?? '',
    );

    _folder = widget.existingNote?['folder'] ?? widget.initialFolder;

    _folders = [...widget.folders];

    if (_folder.isNotEmpty && !_folders.contains(_folder)) {
      _folders.add(_folder);
    }

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
              : _EditorBlock.drawing(
                  block.strokes,
                  backgroundImage: block.backgroundImage,
                ),
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

  Future<void> _removeBlock(_EditorBlock block) async {
    if (block.type == NoteBlockType.text) {
      if (block.controller!.text.isEmpty) {
        setState(() {
          _blocks.remove(block);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          block.controller?.dispose();
        });
        return;
      }
    } else if (block.type == NoteBlockType.drawing) {
      final canvas = block.canvasKey.currentState;

      final strokes = (canvas?.allStrokes ?? block.strokes)
          .where((stroke) => stroke.isNotEmpty)
          .toList();

      final hasBackground =
          (canvas?.backgroundImage ?? block.backgroundImage) != null;

      if (strokes.isEmpty && !hasBackground) {
        setState(() {
          _blocks.remove(block);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          block.controller?.dispose();
        });
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Block'),
          content: const Text('Are you sure you want to remove this block?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

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

  void _cancel() async {
    final title = _titleController.text.trim();

    final savedBlocks = _collectBlocks();

    if (title.isEmpty && savedBlocks.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Note'),
          content: const Text('Are you sure you want to cancel this note?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Yes', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context);
    }
  }

  List<NoteBlockData> _collectBlocks() {
    final savedBlocks = <NoteBlockData>[];

    for (final block in _blocks) {
      if (block.type == NoteBlockType.text) {
        final text = block.controller!.text.trim();

        if (text.isNotEmpty) {
          savedBlocks.add(NoteBlockData.text(text));
        }
      } else {
        final canvas = block.canvasKey.currentState;

        final strokes = (canvas?.allStrokes ?? block.strokes)
            .where((stroke) => stroke.isNotEmpty)
            .toList();

        final backgroundImage =
            canvas?.backgroundImage ?? block.backgroundImage;

        if (strokes.isNotEmpty || backgroundImage != null) {
          savedBlocks.add(
            NoteBlockData.drawing(strokes, backgroundImage: backgroundImage),
          );
        }
      }
    }

    return savedBlocks;
  }

  Map<String, String> _buildNote(String title, List<NoteBlockData> blocks) {
    final content = blocks
        .where((block) => block.type == NoteBlockType.text)
        .map((block) => block.text)
        .join('\n\n');

    return <String, String>{
      'title': title,
      'content': content,
      'blocks': encodeBlocks(blocks),
      'folder': _folder,
    };
  }

  void _save() {
    final title = _titleController.text.trim();

    final savedBlocks = _collectBlocks();

    if (title.isEmpty && savedBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type or sketch something first.')),
      );
      return;
    }

    Navigator.pop(context, _buildNote(title, savedBlocks));
  }

  Future<void> _export(NoteExportFormat format) async {
    final title = _titleController.text.trim();

    final savedBlocks = _collectBlocks();

    if (title.isEmpty && savedBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type or sketch something first.')),
      );
      return;
    }

    try {
      final path = await NoteExporter().exportNote(
        _buildNote(title, savedBlocks),
        format,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null ? 'Export cancelled.' : 'Note exported to $path',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export note: $error')));
    }
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
          PopupMenuButton<NoteExportFormat>(
            tooltip: 'Export note',
            icon: const Icon(Icons.ios_share),
            onSelected: _export,
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
          TextButton(onPressed: _cancel, child: const Text('Cancel')),
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

            DropdownButtonFormField<String>(
              key: const ValueKey('note-folder'),
              initialValue: _folder,
              decoration: const InputDecoration(
                labelText: 'Folder',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('No folder')),
                for (final folder in _folders)
                  DropdownMenuItem(value: folder, child: Text(folder)),
              ],
              onChanged: (value) {
                setState(() {
                  _folder = value ?? '';
                });
              },
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
                initialBackgroundImage: block.backgroundImage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
