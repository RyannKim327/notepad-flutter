import 'package:flutter/material.dart';

import '../services/note_exporter.dart';
import '../services/note_importer.dart';
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

  List<String> folders = [];

  String searchQuery = '';

  String? selectedFolder;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  // Load saved notes and folders from local storage.
  Future<void> loadNotes() async {
    final savedNotes = await _store.loadNotes();
    final savedFolders = await _store.loadFolders();

    if (!mounted) return;

    setState(() {
      notes = savedNotes;
      folders = savedFolders;
      isLoading = false;
    });
  }

  // Save notes to local storage.
  Future<void> saveNotes() async {
    await _store.saveNotes(notes);
  }

  // Save folders to local storage.
  Future<void> saveFolders() async {
    await _store.saveFolders(folders);
  }

  // Create a new note or edit an existing note.
  Future<void> openNoteEditor({int? index}) async {
    final existingNote = index != null ? notes[index] : null;

    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (context) {
          return NoteEditorPage(
            existingNote: existingNote,
            folders: folders,
            initialFolder: existingNote?['folder'] ?? selectedFolder ?? '',
          );
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

  // Ask for a folder name and create the folder.
  Future<void> createFolder() async {
    final name = await _promptFolderName(title: 'New Folder');

    if (name == null) return;

    setState(() {
      folders.add(name);
    });

    await saveFolders();
  }

  // Rename an existing folder and keep its notes in sync.
  Future<void> renameFolder(String folder) async {
    final name = await _promptFolderName(
      title: 'Rename Folder',
      initialValue: folder,
      currentFolder: folder,
    );

    if (name == null || name == folder) return;

    setState(() {
      final folderIndex = folders.indexOf(folder);
      folders[folderIndex] = name;

      for (var i = 0; i < notes.length; i++) {
        if ((notes[i]['folder'] ?? '') == folder) {
          notes[i] = {...notes[i], 'folder': name};
        }
      }
    });

    await saveFolders();
    await saveNotes();
  }

  // Delete a folder, moving its notes back to the unfiled list.
  Future<void> deleteFolder(String folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Folder'),
          content: const Text(
            'Delete this folder? Its notes will be moved out of the folder.',
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
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      folders.remove(folder);

      for (var i = 0; i < notes.length; i++) {
        if ((notes[i]['folder'] ?? '') == folder) {
          notes[i] = {...notes[i], 'folder': ''};
        }
      }

      if (selectedFolder == folder) {
        selectedFolder = null;
      }
    });

    await saveFolders();
    await saveNotes();
  }

  // Show a dialog and return a valid, unique folder name.
  Future<String?> _promptFolderName({
    required String title,
    String initialValue = '',
    String? currentFolder,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return _FolderNameDialog(
          title: title,
          initialValue: initialValue,
          existingFolders: folders,
          currentFolder: currentFolder,
        );
      },
    );
  }

  // Import a note from a JSON file exported by the app.
  Future<void> importNote() async {
    try {
      final imported = await NoteImporter().pickAndImport();

      if (!mounted || imported == null) return;

      final exportedFolder = imported['folder'] ?? '';
      final importedFolder = exportedFolder.isEmpty
          ? (selectedFolder ?? '')
          : exportedFolder;
      final needsFolder =
          importedFolder.isNotEmpty && !folders.contains(importedFolder);

      setState(() {
        if (needsFolder) {
          folders.add(importedFolder);
        }

        notes.insert(0, {...imported, 'folder': importedFolder});
      });

      if (needsFolder) {
        await saveFolders();
      }

      await saveNotes();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note imported.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not import note: $error')));
    }
  }

  // Export a note as a stand-alone PDF or JSON file.
  Future<void> exportNote(int index, NoteExportFormat format) async {
    try {
      final path = await NoteExporter().exportNote(notes[index], format);

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
    final query = searchQuery.toLowerCase();

    bool matchesSearch(Map<String, String> note) {
      final title = note['title'] ?? '';
      final content = note['content'] ?? '';

      return title.toLowerCase().contains(query) ||
          content.toLowerCase().contains(query);
    }

    // On the home screen show folders first, then unfiled notes.
    final isHome = selectedFolder == null;

    final visibleFolders = isHome
        ? folders
              .where((folder) => folder.toLowerCase().contains(query))
              .toList()
        : <String>[];

    final filteredNotes = notes.where((note) {
      final folder = note['folder'] ?? '';

      if (isHome) {
        if (folder.isNotEmpty) return false;
      } else if (folder != selectedFolder) {
        return false;
      }

      return matchesSearch(note);
    }).toList();

    final isEmptyList = visibleFolders.isEmpty && filteredNotes.isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF2),
        leading: isHome
            ? null
            : IconButton(
                tooltip: 'Back to notes',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedFolder = null;
                    searchQuery = '';
                  });
                },
              ),
        title: Text(
          selectedFolder ?? 'My Notes',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
        ),
        centerTitle: false,
        actions: [
          if (isHome)
            IconButton(
              tooltip: 'New folder',
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: createFolder,
            ),
          IconButton(
            tooltip: 'Import JSON note',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: importNote,
          ),
        ],
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

                  // Folders first, then notes.
                  Expanded(
                    child: isEmptyList
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isHome
                                      ? Icons.note_alt_outlined
                                      : Icons.folder_open_outlined,
                                  size: 80,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchQuery.isEmpty
                                      ? (isHome
                                            ? 'No notes yet!'
                                            : 'This folder is empty.')
                                      : 'No matching notes found.',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (searchQuery.isEmpty)
                                  Text(
                                    isHome
                                        ? 'Tap + to type or sketch a note.'
                                        : 'Tap + to add a note here.',
                                  ),
                              ],
                            ),
                          )
                        : ListView(
                            children: [
                              if (visibleFolders.isNotEmpty) ...[
                                const _SectionHeader('Folders'),
                                for (final folder in visibleFolders)
                                  _buildFolderTile(folder),
                                if (filteredNotes.isNotEmpty)
                                  const SizedBox(height: 8),
                              ],
                              if (filteredNotes.isNotEmpty) ...[
                                if (isHome && visibleFolders.isNotEmpty)
                                  const _SectionHeader('Notes'),
                                for (final note in filteredNotes)
                                  NoteCard(
                                    note: note,
                                    onTap: () {
                                      openNoteEditor(
                                        index: notes.indexOf(note),
                                      );
                                    },
                                    onDelete: () {
                                      deleteNote(notes.indexOf(note));
                                    },
                                    onExport: (format) {
                                      exportNote(notes.indexOf(note), format);
                                    },
                                  ),
                              ],
                            ],
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

  Widget _buildFolderTile(String folder) {
    final noteCount = notes
        .where((note) => (note['folder'] ?? '') == folder)
        .length;

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.folder, color: Colors.amber.shade800),
        ),
        title: Text(
          folder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(noteCount == 1 ? '1 note' : '$noteCount notes'),
        ),
        onTap: () {
          setState(() {
            selectedFolder = folder;
            searchQuery = '';
          });
        },
        trailing: PopupMenuButton<String>(
          tooltip: 'Folder options',
          onSelected: (value) {
            if (value == 'rename') {
              renameFolder(folder);
            } else if (value == 'delete') {
              deleteFolder(folder);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'rename',
              child: ListTile(
                leading: Icon(Icons.drive_file_rename_outline),
                title: Text('Rename'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog for naming a new folder or renaming an existing one.
class _FolderNameDialog extends StatefulWidget {
  final String title;

  final String initialValue;

  final List<String> existingFolders;

  final String? currentFolder;

  const _FolderNameDialog({
    required this.title,
    required this.initialValue,
    required this.existingFolders,
    this.currentFolder,
  });

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;

  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();

    if (value.isEmpty) {
      setState(() {
        _error = 'Please enter a folder name.';
      });
      return;
    }

    final duplicate = widget.existingFolders.any(
      (folder) =>
          folder.toLowerCase() == value.toLowerCase() &&
          folder != widget.currentFolder,
    );

    if (duplicate) {
      setState(() {
        _error = 'A folder with that name already exists.';
      });
      return;
    }

    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Folder name',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Colors.brown.shade400,
        ),
      ),
    );
  }
}
