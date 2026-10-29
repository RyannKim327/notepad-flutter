import 'package:flutter/material.dart';

import '../services/note_store.dart';
import '../widgets/note_card.dart';
import 'note_editor_page.dart';

class NotepadHomepage extends StatefulWidget {
  const NotepadHomepage({super.key});

  @override
  State<NotepadHomepage> createState() => _Homepage();
}

class _Homepage extends State<NotepadHomepage> {
  final NoteStore _store = NoteStore();

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
    final savedNotes = await _store.loadNotes();

    if (!mounted) return;

    setState(() {
      notes = savedNotes;
      isLoading = false;
    });
  }

  // Save notes to local storage.
  Future<void> saveNotes() async {
    await _store.saveNotes(notes);
  }

  // Create a new note or edit an existing note.
  Future<void> openNoteEditor({int? index}) async {
    final existingNote = index != null ? notes[index] : null;

    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (context) {
          return NoteEditorPage(existingNote: existingNote);
        },
      ),
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
          content: const Text('Are you sure you want to delete this note?'),
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
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

      return title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          content.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF2),
        title: const Text(
          'My Notes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
        ),
        centerTitle: false,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
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
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                  const Text('Tap + to type or sketch a note.'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredNotes.length,
                            itemBuilder: (context, i) {
                              final note = filteredNotes[i];

                              // Find the original note index.
                              final originalIndex = notes.indexOf(note);

                              return NoteCard(
                                note: note,
                                onTap: () {
                                  openNoteEditor(index: originalIndex);
                                },
                                onDelete: () {
                                  deleteNote(originalIndex);
                                },
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
