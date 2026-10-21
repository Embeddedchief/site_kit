import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/note.dart';
import 'notifications.dart';

/// Stores notes as JSON and their photos as files in the app's private
/// documents folder. Listen to [notes] for updates (newest first).
class NotesRepository {
  NotesRepository._();
  static final instance = NotesRepository._();

  static const maxPhotosPerNote = 20;

  final notes = ValueNotifier<List<Note>>(const []);
  Directory? _root;
  final _random = Random.secure();

  bool get isReady => _root != null;

  File get _file => File('${_root!.path}/notes.json');
  Directory get _photos => Directory('${_root!.path}/photos');

  /// Loads notes. [root] overrides the storage folder (used by tests).
  Future<void> init({Directory? root}) async {
    final base =
        root ??
        Directory('${(await getApplicationDocumentsDirectory()).path}/notes');
    await Directory('${base.path}/photos').create(recursive: true);
    _root = base;

    var loaded = <Note>[];
    if (await _file.exists()) {
      try {
        final raw = jsonDecode(await _file.readAsString()) as List;
        for (final item in raw) {
          try {
            loaded.add(Note.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            debugPrint('Skipping unreadable note: $e');
          }
        }
      } catch (e) {
        // Keep the damaged file for recovery rather than overwriting it.
        debugPrint('Notes file unreadable, moved aside: $e');
        await _file.rename('${base.path}/notes.corrupt.json');
        loaded = [];
      }
    }
    loaded.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notes.value = loaded;
  }

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${_random.nextInt(1 << 32)}';

  Note? byId(String id) {
    for (final n in notes.value) {
      if (n.id == id) return n;
    }
    return null;
  }

  File photoFile(String name) => File('${_photos.path}/$name');

  /// Copies a picked image into private storage; returns its file name.
  Future<String> importPhoto(String sourcePath) async {
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot == -1 ? '' : sourcePath.substring(dot).toLowerCase();
    final safeExt =
        const {'.jpg', '.jpeg', '.png', '.heic', '.webp'}.contains(ext)
        ? ext
        : '.jpg';
    final name = 'p${newId()}$safeExt';
    await File(sourcePath).copy(photoFile(name).path);
    return name;
  }

  Future<void> deletePhotos(Iterable<String> names) async {
    for (final name in names) {
      try {
        final f = photoFile(name);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('Could not delete photo $name: $e');
      }
    }
  }

  /// Inserts or replaces [note]; deletes photo files it no longer uses.
  Future<void> save(Note note) async {
    final old = byId(note.id);
    if (old != null) {
      await deletePhotos(old.photos.where((p) => !note.photos.contains(p)));
    }
    notes.value = [note, ...notes.value.where((n) => n.id != note.id)];
    await _write();
  }

  Future<void> delete(Note note) async {
    notes.value = notes.value.where((n) => n.id != note.id).toList();
    await deletePhotos(note.photos);
    await _write();
  }

  /// Adds an in-app notification for each reminder whose time has passed.
  Future<void> logDueReminders() async {
    final due = notes.value.where((n) => n.reminderDue && !n.reminderLogged);
    if (due.isEmpty) return;
    for (final n in due.toList()) {
      await Notifications.add(
        AppNotification(
          title: 'Reminder: ${n.title}',
          body: n.project.isNotEmpty ? n.project : _snippet(n.body),
          createdAt: n.reminderAt!,
        ),
      );
      notes.value = [
        for (final x in notes.value)
          x.id == n.id ? x.copyWith(reminderLogged: true) : x,
      ];
    }
    await _write();
  }

  static String _snippet(String s) {
    final line = s.trim().split('\n').first;
    return line.length > 80 ? '${line.substring(0, 80)}…' : line;
  }

  /// Writes to a temp file then renames, so a crash mid-write can't corrupt
  /// the saved notes.
  Future<void> _write() async {
    final tmp = File('${_root!.path}/notes.json.tmp');
    await tmp.writeAsString(
      jsonEncode([for (final n in notes.value) n.toJson()]),
      flush: true,
    );
    await tmp.rename(_file.path);
  }
}
