import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/note.dart';
import '../../services/notes_repository.dart';
import '../../services/reminder_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/common.dart';
import 'photo_viewer.dart';

/// Creates a note, or edits [note] when given.
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.note});

  final Note? note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _repo = NotesRepository.instance;
  final _picker = ImagePicker();

  late final _title = TextEditingController(text: widget.note?.title);
  late final _project = TextEditingController(text: widget.note?.project);
  late final _body = TextEditingController(text: widget.note?.body);
  late List<String> _photos = [...?widget.note?.photos];
  late DateTime? _reminderAt = widget.note?.hasUpcomingReminder ?? false
      ? widget.note!.reminderAt
      : null;

  /// Photos copied in during this edit; removed again if the edit is
  /// discarded.
  final _importedNow = <String>{};
  bool _saving = false;
  bool _picking = false;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();
    _recoverLostPhotos();
  }

  @override
  void dispose() {
    _title.dispose();
    _project.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _dirty {
    final n = widget.note;
    if (n == null) {
      return _title.text.trim().isNotEmpty ||
          _project.text.trim().isNotEmpty ||
          _body.text.trim().isNotEmpty ||
          _photos.isNotEmpty ||
          _reminderAt != null;
    }
    return _title.text != n.title ||
        _project.text != n.project ||
        _body.text != n.body ||
        !listEquals(_photos, n.photos) ||
        _reminderAt != (n.hasUpcomingReminder ? n.reminderAt : null);
  }

  // -------------------------------------------------------------------------
  // Photos
  // -------------------------------------------------------------------------

  /// Android can kill the app while the camera is open; recover that photo.
  Future<void> _recoverLostPhotos() async {
    if (!Platform.isAndroid) return;
    try {
      final lost = await _picker.retrieveLostData();
      if (!lost.isEmpty && lost.files != null) await _addFiles(lost.files!);
    } catch (e) {
      debugPrint('Lost photo recovery failed: $e');
    }
  }

  Future<void> _addFiles(List<XFile> files) async {
    final room = NotesRepository.maxPhotosPerNote - _photos.length;
    if (files.length > room && mounted) {
      showMessage(
        context,
        'A note can hold ${NotesRepository.maxPhotosPerNote} photos.',
      );
    }
    for (final f in files.take(room)) {
      final name = await _repo.importPhoto(f.path);
      _importedNow.add(name);
      if (mounted) setState(() => _photos = [..._photos, name]);
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    if (_photos.length >= NotesRepository.maxPhotosPerNote) {
      showMessage(
        context,
        'A note can hold ${NotesRepository.maxPhotosPerNote} photos.',
      );
      return;
    }
    _picking = true;
    try {
      // Downscale and compress: plenty for site records, far smaller files.
      final files = source == ImageSource.camera
          ? [
              ?await _picker.pickImage(
                source: source,
                maxWidth: 2048,
                maxHeight: 2048,
                imageQuality: 82,
              ),
            ]
          : await _picker.pickMultiImage(
              maxWidth: 2048,
              maxHeight: 2048,
              imageQuality: 82,
            );
      await _addFiles(files);
    } on PlatformException catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.code.contains('denied')
              ? 'Allow ${source == ImageSource.camera ? 'camera' : 'photo'} '
                    'access in Settings to add photos.'
              : 'Could not add the photo.',
        );
      }
    } catch (e) {
      debugPrint('Photo pick failed: $e');
      if (mounted) showMessage(context, 'Could not add the photo.');
    } finally {
      _picking = false;
    }
  }

  void _choosePhotoSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.red,
              ),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(sheet);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.red,
              ),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheet);
                _pick(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Reminder
  // -------------------------------------------------------------------------

  Future<void> _pickReminder({DateTime? initial}) async {
    final now = DateTime.now();
    final start = initial ?? _reminderAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: start.isBefore(now) ? now : start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time == null) return;
    setState(() {
      _reminderAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _preset(Duration fromNow) =>
      setState(() => _reminderAt = DateTime.now().add(fromNow));

  void _presetAt(int daysAhead, int hour) {
    final now = DateTime.now();
    setState(
      () => _reminderAt = DateTime(
        now.year,
        now.month,
        now.day + daysAhead,
        hour,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Save / delete / discard
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty && body.isEmpty && _photos.isEmpty) {
      showMessage(context, 'Add a title, some details or a photo first.');
      return;
    }
    final reminder = _reminderAt;
    if (reminder != null && !reminder.isAfter(DateTime.now())) {
      showMessage(context, 'Pick a reminder time in the future.');
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final fallbackTitle = body.isNotEmpty
          ? body.split('\n').first
          : 'Photo note';
      final previous = widget.note;
      final note = Note(
        id: previous?.id ?? _repo.newId(),
        title: (title.isEmpty ? fallbackTitle : title).characters
            .take(120)
            .toString(),
        project: _project.text.trim(),
        body: body,
        photos: _photos,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        reminderAt: reminder,
        reminderLogged: reminder != null && reminder == previous?.reminderAt
            ? previous!.reminderLogged
            : false,
      );
      await _repo.save(note);
      _importedNow.clear();

      var permissionNote = false;
      if (note.hasUpcomingReminder) {
        permissionNote = !await ReminderService.instance.requestPermission();
      }
      await ReminderService.instance.sync(note);

      if (!mounted) return;
      Navigator.pop(context);
      if (permissionNote) {
        showMessage(
          context,
          'Saved. Turn on notifications for SiteKit to get the reminder.',
        );
      }
    } catch (e) {
      debugPrint('Saving note failed: $e');
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, 'Could not save the note. Please try again.');
      }
    }
  }

  Future<void> _delete() async {
    final note = widget.note!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('The note and its photos will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ReminderService.instance.cancel(note);
    await _repo.delete(note);
    await _repo.deletePhotos(_importedNow);
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _leave() async {
    if (!await _confirmDiscard()) return;
    await _repo.deletePhotos(_importedNow);
    if (mounted) Navigator.pop(context);
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final projects = {
      for (final n in _repo.notes.value)
        if (n.project.isNotEmpty) n.project,
    }.take(6).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: Column(
            children: [
              PageHeader(
                title: _isNew ? 'New note' : 'Edit note',
                onBack: _leave,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isNew)
                      IconButton(
                        onPressed: _delete,
                        tooltip: 'Delete note',
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppColors.muted,
                      ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _card(
                      children: [
                        TextField(
                          controller: _title,
                          maxLength: 120,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Note title',
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        TextField(
                          controller: _project,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText:
                                'Project or location, e.g. Block 2, Level 3',
                            prefixIcon: Icon(
                              Icons.folder_outlined,
                              color: AppColors.muted,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                        if (projects.isNotEmpty && _project.text.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final p in projects)
                                  ActionChip(
                                    label: Text(p),
                                    onPressed: () =>
                                        setState(() => _project.text = p),
                                    backgroundColor: AppColors.bg,
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                    labelStyle: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.ink,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const Divider(height: 1, color: AppColors.border),
                        TextField(
                          controller: _body,
                          maxLength: 5000,
                          minLines: 6,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText:
                                'Details: observations, measurements, '
                                'snags, instructions…',
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _photosSection(),
                    const SizedBox(height: 12),
                    _reminderSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A Material surface (not a decorated box) so list tiles and ink wells
  // inside show their tap ripples.
  Widget _card({required List<Widget> children}) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _sectionLabel(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 10),
    child: Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    ),
  );

  Widget _photosSection() {
    final files = [for (final p in _photos) _repo.photoFile(p)];
    return _card(
      children: [
        _sectionLabel(
          'Photos',
          trailing: Text(
            '${_photos.length}/${NotesRepository.maxPhotosPerNote}',
            style: const TextStyle(fontSize: 12, color: AppColors.faint),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == _photos.length) {
                return InkWell(
                  onTap: _choosePhotoSource,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    width: 92,
                    decoration: BoxDecoration(
                      color: AppColors.redTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: AppColors.red),
                        SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PhotoViewer(files: files, initialIndex: i),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        files[i],
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        // Decode thumbnails small to save memory.
                        cacheWidth: 276,
                        errorBuilder: (_, _, _) => Container(
                          width: 92,
                          height: 92,
                          color: AppColors.border,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _photos = [..._photos]..removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                          semanticLabel: 'Remove photo',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _reminderSection() {
    final at = _reminderAt;
    final past = at != null && !at.isAfter(DateTime.now());
    return _card(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: at != null,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.red,
          title: const Text(
            'Remind me',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          subtitle: Text(
            at == null
                ? 'Get a notification about this note'
                : formatDateTime(at),
            style: TextStyle(
              fontSize: 12,
              color: past ? AppColors.red : AppColors.muted,
            ),
          ),
          onChanged: (on) {
            if (on) {
              _pickReminder();
            } else {
              setState(() => _reminderAt = null);
            }
          },
        ),
        if (at != null) ...[
          if (past)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'This time has passed. Pick a new one.',
                style: TextStyle(fontSize: 12, color: AppColors.red),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip('In 1 hour', () => _preset(const Duration(hours: 1))),
              _presetChip('Tomorrow 8:00', () => _presetAt(1, 8)),
              _presetChip('In 1 week', () => _presetAt(7, 8)),
              _presetChip('Custom…', _pickReminder, icon: Icons.edit_calendar),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _presetChip(String label, VoidCallback onTap, {IconData? icon}) =>
      ActionChip(
        avatar: icon == null
            ? null
            : Icon(icon, size: 16, color: AppColors.red),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.ink),
      );
}
