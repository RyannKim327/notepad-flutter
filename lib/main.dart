import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const Notepad());
}

class Notepad extends StatelessWidget {
  const Notepad({super.key});
  
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'Notepad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFBF2),
        useMaterial3: true,
      ),
      home: const NotepadHomepage(),
    );
  }
}

class NotepadHomepage extends StatefulWidget{
  const NotepadHomepage({super.key});
  @override
  State<NotepadHomepage> createState() => _Homepage();
}

class _Homepage extends State<NotepadHomepage> {
  List<Map<String, String>> notes = [];

  String searchQuery = '';

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  // Load saved notes from local storage.
  Future<void> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();

    final savedNotes = prefs.getString('notes');

    if (savedNotes != null) {
      final List<dynamic> decodedNotes = jsonDecode(savedNotes);

      notes = decodedNotes.map((note) {
        return Map<String, String>.from(note);
      }).toList();
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  // Save notes to local storage.
  Future<void> saveNotes() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'notes',
      jsonEncode(notes),
    );
  }

  // Create a new note or edit an existing note.
  Future<void> openNoteEditor({int? index}) async {
    final existingNote =
        index != null ? notes[index] : null;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return NoteEditorDialog(
          existingNote: existingNote,
        );
      },
    );

    if (result == null) return;

    setState(() {
      if (index != null) {
        notes[index] = result;
      } else {
        notes.insert(0, result);
      }
    });

    await saveNotes();
  }

  // Delete a note.
  Future<void> deleteNote(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Note'),
          content: const Text(
            'Are you sure you want to delete this note?',
          ),
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
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      notes.removeAt(index);
    });

    await saveNotes();
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = notes.where((note) {
      final title = note['title'] ?? '';
      final content = note['content'] ?? '';

      return title.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
          content.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF2),
        title: const Text(
          'My Notes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        centerTitle: false,
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search bar.
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search your notes...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Notes list.
                  Expanded(
                    child: filteredNotes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.note_alt_outlined,
                                  size: 80,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchQuery.isEmpty
                                      ? 'No notes yet!'
                                      : 'No matching notes found.',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (searchQuery.isEmpty)
                                  const Text(
                                    'Tap + to create your first note.',
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredNotes.length,
                            itemBuilder: (context, i) {
                              final note = filteredNotes[i];

                              // Find the original note index.
                              final originalIndex =
                                  notes.indexOf(note);

                              return Card(
                                color: Colors.white,
                                elevation: 1,
                                margin: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.all(16),

                                  title: Text(
                                    note['title']!.isEmpty
                                        ? 'Untitled Note'
                                        : note['title']!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),

                                  subtitle: Padding(
                                    padding:
                                        const EdgeInsets.only(
                                      top: 8,
                                    ),
                                    child: Text(
                                      note['content']!,
                                      maxLines: 3,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ),

                                  onTap: () {
                                    openNoteEditor(
                                      index: originalIndex,
                                    );
                                  },

                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () {
                                      deleteNote(originalIndex);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

      // Add note button.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          openNoteEditor();
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Note editor dialog.
class NoteEditorDialog extends StatefulWidget {
  final Map<String, String>? existingNote;

  const NoteEditorDialog({
    super.key,
    this.existingNote,
  });

  @override
  State<NoteEditorDialog> createState() =>
      _NoteEditorDialogState();
}

class _NoteEditorDialogState
    extends State<NoteEditorDialog> {
  late final TextEditingController titleController;

  late final TextEditingController contentController;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.existingNote?['title'] ?? '',
    );

    contentController = TextEditingController(
      text: widget.existingNote?['content'] ?? '',
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  void saveNote() {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title or some content.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      <String, String>{
        'title': title,
        'content': content,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingNote != null;

    return AlertDialog(
      backgroundColor: const Color(0xFFFFFBF2),
      title: Text(
        isEditing ? 'Edit Note' : 'New Note',
      ),

      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter note title',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: contentController,
                maxLines: 8,
                minLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Write your note here...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),

        FilledButton(
          onPressed: saveNote,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
