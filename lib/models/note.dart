/// A site note with optional photos and reminder.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.project,
    required this.body,
    required this.photos,
    required this.createdAt,
    required this.updatedAt,
    this.reminderAt,
    this.reminderLogged = false,
  });

  final String id;
  final String title;
  final String project;
  final String body;

  /// Photo file names inside the notes photo folder (never full paths, which
  /// change between app installs on iOS).
  final List<String> photos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reminderAt;

  /// True once the due reminder has been added to the in-app notifications.
  final bool reminderLogged;

  static final _safeFileName = RegExp(r'^[A-Za-z0-9_.-]+$');

  bool get hasUpcomingReminder =>
      reminderAt != null && reminderAt!.isAfter(DateTime.now());

  bool get reminderDue =>
      reminderAt != null && !reminderAt!.isAfter(DateTime.now());

  /// Stable 31-bit id for the platform notification (FNV-1a of [id]).
  int get notificationId {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  Note copyWith({
    String? title,
    String? project,
    String? body,
    List<String>? photos,
    DateTime? updatedAt,
    DateTime? Function()? reminderAt,
    bool? reminderLogged,
  }) => Note(
    id: id,
    title: title ?? this.title,
    project: project ?? this.project,
    body: body ?? this.body,
    photos: photos ?? this.photos,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    reminderAt: reminderAt == null ? this.reminderAt : reminderAt(),
    reminderLogged: reminderLogged ?? this.reminderLogged,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'project': project,
    'body': body,
    'photos': photos,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reminderAt': reminderAt?.toIso8601String(),
    'reminderLogged': reminderLogged,
  };

  /// Parses stored JSON, rejecting malformed entries and any photo name that
  /// could point outside the photo folder.
  factory Note.fromJson(Map<String, dynamic> json) {
    final reminder = json['reminderAt'];
    return Note(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      project: json['project'] as String? ?? '',
      body: json['body'] as String? ?? '',
      photos: [
        for (final p in json['photos'] as List? ?? const [])
          if (p is String && _safeFileName.hasMatch(p)) p,
      ],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      reminderAt: reminder is String ? DateTime.tryParse(reminder) : null,
      reminderLogged: json['reminderLogged'] as bool? ?? false,
    );
  }
}
