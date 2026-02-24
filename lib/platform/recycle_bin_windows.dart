import 'dart:io';
import 'package:flutter/foundation.dart';
import 'recycle_bin.dart';
class RecycleBinWindows implements RecycleBin {
  @override
  bool get isSupported => true;

  @override
  Future<bool> moveToTrash(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.notFound) return false;
      // Escape single quotes for PowerShell string literal
      final escapedPath = path.replaceAll("'", "''");

      // Build PowerShell command to move file to recycle bin
      const command = 'powershell';
      final args = [
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        'Add-Type -AssemblyName Microsoft.VisualBasic; '
            "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('$escapedPath', 'OnlyErrorDialogs', 'SendToRecycleBin')",
      ];

      final result = await Process.run(command, args);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Failed to move $path to recycle bin: $e');
      return false;
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
