import '../../models/directory_node.dart';
import '../../models/file_node.dart';
import '../../models/scan_result.dart';
import '../../services/scan_service.dart';
import 'cli_command.dart';

/// Scans the filesystem and outputs non-whitelisted files.
class ScanCommand extends CliCommand {
  final ScanService _service;

  @override
  final String name = 'scan';

  @override
  final String description = 'Scan filesystem for non-whitelisted files.';

  ScanCommand(this._service);

  @override
  Future<void> run() async {
    final roots = await _service.scanRoots();
    final results = _flattenToScanResults(roots);
    printResult(results);
  }

  /// Converts DirectoryNode tree to flat list of ScanResult
  List<ScanResult> _flattenToScanResults(List<DirectoryNode> roots) {
    final results = <ScanResult>[];
    
    void traverse(DirectoryNode node) {
      // Add all files
      for (final file in node.files) {
        results.add(ScanResult(
          path: file.path,
          sizeBytes: file.sizeBytes,
          modifiedAt: file.modifiedAt,
          isDirectory: false,
        ));
      }
      
      // Add folders (as directories)
      for (final folder in node.folders) {
        results.add(ScanResult(
          path: folder.path,
          sizeBytes: folder.sizeBytes ?? 0,
          modifiedAt: folder.modifiedAt,
          isDirectory: true,
        ));
      }
    }
    
    for (final root in roots) {
      traverse(root);
    }
    
    return results;
  }

  @override
  void printHuman(Object data) {
    final results = data as List<ScanResult>;
    if (results.isEmpty) {
      print('No non-whitelisted files found.');
      return;
    }

    for (final r in results) {
      final date =
          '${r.modifiedAt.year}-'
          '${r.modifiedAt.month.toString().padLeft(2, '0')}-'
          '${r.modifiedAt.day.toString().padLeft(2, '0')}';
      print(
        '${r.path.padRight(60)}'
        '${r.formattedSize.padRight(12)}'
        '$date',
      );
    }

    final totalBytes = results.fold<int>(0, (sum, r) => sum + r.sizeBytes);
    print('');
    print('共 ${results.length} 个文件，${_formatBytes(totalBytes)}');
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(2)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
