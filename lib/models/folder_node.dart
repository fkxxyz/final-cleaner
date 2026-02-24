class FolderNode {
  final String path;
  final String name;
  final int? sizeBytes;
  final bool autoExpand;
  final DateTime modifiedAt;

  const FolderNode({
    required this.path,
    required this.name,
    this.sizeBytes,
    required this.autoExpand,
    required this.modifiedAt,
  });

  String? get formattedSize {
    final size = sizeBytes;
    if (size == null) return null;
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (size < 1024 * 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else {
      return '${(size / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
    }
  }

  FolderNode copyWith({
    String? path,
    String? name,
    int? sizeBytes,
    bool? autoExpand,
    DateTime? modifiedAt,
  }) {
    return FolderNode(
      path: path ?? this.path,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      autoExpand: autoExpand ?? this.autoExpand,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'sizeBytes': sizeBytes,
      'autoExpand': autoExpand,
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }

  factory FolderNode.fromJson(Map<String, dynamic> json) {
    return FolderNode(
      path: json['path'] as String,
      name: json['name'] as String,
      sizeBytes: json['sizeBytes'] as int?,
      autoExpand: json['autoExpand'] as bool,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FolderNode &&
        other.path == path &&
        other.name == name &&
        other.sizeBytes == sizeBytes &&
        other.autoExpand == autoExpand &&
        other.modifiedAt == modifiedAt;
  }

  @override
  int get hashCode {
    return Object.hash(path, name, sizeBytes, autoExpand, modifiedAt);
  }

  @override
  String toString() {
    return 'FolderNode(path: $path, name: $name, sizeBytes: $sizeBytes, autoExpand: $autoExpand, modifiedAt: $modifiedAt)';
  }
}
