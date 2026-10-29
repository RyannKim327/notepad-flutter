import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// Loads and saves notes and folders in local storage.
class NoteStore {
  static const String _notesKey = 'notes';

  static const String _foldersKey = 'folders';

  Future<List<Map<String, String>>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();

    final savedNotes = prefs.getString(_notesKey);

    if (savedNotes == null) return [];

    try {
      final decodedNotes = jsonDecode(savedNotes) as List<dynamic>;

      return decodedNotes
          .map(
            (note) => Map<String, String>.from(note as Map<dynamic, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotes(List<Map<String, String>> notes) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_notesKey, jsonEncode(notes));
  }

  Future<List<String>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();

    final savedFolders = prefs.getStringList(_foldersKey);

    if (savedFolders == null) return [];

    return savedFolders;
  }

  Future<void> saveFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_foldersKey, folders);
  }
}
