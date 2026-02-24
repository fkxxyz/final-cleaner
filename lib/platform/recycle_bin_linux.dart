import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'recycle_bin.dart';

class RecycleBinLinux implements RecycleBin {
  String get _trashFilesDir => p.join(
    Platform.environment['HOME']!,
    '.local',
    'share',
    'Trash',
    'files',
  );

  String get _trashInfoDir =>
      p.join(Platform.environment['HOME']!, '.local', 'share', 'Trash', 'info');

  @override
  bool get isSupported => true;

  @override
  Future<bool> moveToTrash(String path) async {
    try {
      final entity = FileSystemEntity.typeSync(path);
      if (entity == FileSystemEntityType.notFound) return false;

      await Directory(_trashFilesDir).create(recursive: true);
      await Directory(_trashInfoDir).create(recursive: true);

      final baseName = p.basename(path);
      var trashPath = p.join(_trashFilesDir, baseName);
      var count = 1;
      while (FileSystemEntity.typeSync(trashPath) !=
          FileSystemEntityType.notFound) {
        final nameWithoutExt = p.basenameWithoutExtension(baseName);
        final ext = p.extension(baseName);
        trashPath = p.join(_trashFilesDir, '$nameWithoutExt.$count$ext');
        count++;
      }

      if (entity == FileSystemEntityType.directory) {
        await Directory(path).rename(trashPath);
      } else {
        await File(path).rename(trashPath);
      }

      final infoFile = File(
        p.join(_trashInfoDir, '${p.basename(trashPath)}.trashinfo'),
      );
      final deletionDate = DateTime.now().toIso8601String();
      await infoFile.writeAsString(
        '[Trash Info]\nPath=$path\nDeletionDate=$deletionDate\n',
      );

      return true;
    } catch (e) {
      debugPrint('Failed to move $path to trash: $e');
      return false;
    }
  }

  @override
  Future<List<String>> moveMultipleToTrash(List<String> paths) async {
    final failed = <String>[];
    for (final path in paths) {
      if (!await moveToTrash(path)) {
        failed.add(path);
      }
    }
    return failed;
  }
}
