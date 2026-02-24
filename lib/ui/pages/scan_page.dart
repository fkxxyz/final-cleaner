import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/directory_node.dart';
import '../../models/folder_node.dart';
import '../../models/scan_result.dart';
import '../../providers/providers.dart';
import '../widgets/tree_node_widget.dart';
import '../widgets/add_to_whitelist_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../services/permission_service.dart';

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  List<DirectoryNode>? _rootNodes;
  final Map<String, bool> _selectedPaths = {};
  final Map<String, DirectoryNode> _expandedDirectories = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoots();
  }

  Future<void> _loadRoots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final scanService = ref.read(scanServiceProvider);
      final roots = await scanService.scanRoots();

      setState(() {
        _rootNodes = roots;
        _isLoading = false;
        // Pre-populate expanded directories with roots (so they start expanded)
        for (final root in roots) {
          _expandedDirectories[root.path] = root;
        }
      });

      // Auto-expand folders with autoExpand flag
      await _autoExpandRecursively(roots);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorImportFailed(e.toString()))));
      }
    }
  }

  Future<void> _autoExpandRecursively(List<DirectoryNode> nodes) async {
    for (final node in nodes) {
      for (final folder in node.folders) {
        if (folder.autoExpand) {
          await _expandDirectory(folder.path);

          // Recursively expand children
          final childNode = _expandedDirectories[folder.path];
          if (childNode != null) {
            await _autoExpandRecursively([childNode]);
          }
        }
      }
    }
  }

  Future<void> _expandDirectory(String path) async {
    if (_expandedDirectories.containsKey(path)) {
      return; // Already expanded
    }

    try {
      final scanService = ref.read(scanServiceProvider);
      final node = await scanService.scanDirectory(path);
      // Get old size before expansion
      final oldSize = _getFolderSize(path);
      
      setState(() {
        _expandedDirectories[path] = node;
      });
      
      // Calculate new size after expansion
      final newSize = _calculateNodeSize(node);
      
      // If folder became calculable, update and propagate upward
      if (oldSize == null && newSize != null) {
        _updateFolderSizeAndPropagate(path, newSize);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorImportFailed(e.toString()))),
        );
      }
    }
  }

  /// Gets the current size of a folder from its parent's DirectoryNode.
  /// Returns null if folder is not calculable or is a root folder.
  int? _getFolderSize(String path) {
    final parentPath = _getParentPath(path);
    if (parentPath == null) {
      // This is a root folder, no parent to check
      return null;
    }
    
    final parentNode = _expandedDirectories[parentPath];
    if (parentNode == null) return null;
    
    try {
      final folderNode = parentNode.folders.firstWhere(
        (f) => f.path == path,
      );
      return folderNode.sizeBytes;
    } catch (e) {
      return null;
    }
  }

  /// Updates the folder's size in its parent's DirectoryNode and propagates upward.
  void _updateFolderSizeAndPropagate(String path, int size) {
    final parentPath = _getParentPath(path);
    if (parentPath == null) {
      // This is a root folder, no parent to update
      return;
    }
    
    final parentNode = _expandedDirectories[parentPath];
    if (parentNode == null) return;
    
    // Update the FolderNode in parent's DirectoryNode
    final updatedFolders = parentNode.folders.map((folder) {
      if (folder.path == path) {
        return folder.copyWith(sizeBytes: size);
      }
      return folder;
    }).toList();
    final updatedParentNode = parentNode.copyWith(folders: updatedFolders);
    
    // Get parent's old size before update
    final oldParentSize = _getFolderSize(parentPath);
    
    setState(() {
      _expandedDirectories[parentPath] = updatedParentNode;
    });
    
    // Calculate parent's new size
    final newParentSize = _calculateNodeSize(updatedParentNode);
    
    // If parent became calculable, propagate upward
    if (oldParentSize == null && newParentSize != null) {
      _updateFolderSizeAndPropagate(parentPath, newParentSize);
    }
  }
  /// Calculates the total size of a DirectoryNode.
  /// Returns null if any subfolder is not calculable (sizeBytes == null).
  int? _calculateNodeSize(DirectoryNode node) {
    var totalSize = 0;
    // Add all file sizes (files are always calculable)
    for (final file in node.files) {
      totalSize += file.sizeBytes;
    }
    // Check all subfolders
    for (final folder in node.folders) {
      final folderSize = folder.sizeBytes;
      if (folderSize == null) {
        // Subfolder not calculable
        return null;
      }
      totalSize += folderSize;
    }
    return totalSize;
  }
  /// Gets the parent path of a given path.
  /// Returns null if path is a root path.
  String? _getParentPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length <= 1) {
      return null; // Root path
    }
    // Reconstruct parent path
    final parentSegments = segments.sublist(0, segments.length - 1);
    return '/${parentSegments.join('/')}';
  }

  void _handleSelection(String path, bool selected) {
    setState(() {
      _selectedPaths[path] = selected;
      // Hierarchical selection: when selecting a folder, select all its children
      final childPaths = _collectPathsUnder(path);
      for (final childPath in childPaths) {
        _selectedPaths[childPath] = selected;
      }
    });
  }

  List<String> _collectPathsUnder(String path) {
    final paths = <String>[];
    final node = _expandedDirectories[path];
    if (node != null) {
      for (final file in node.files) {
        paths.add(file.path);
      }
      for (final folder in node.folders) {
        paths.add(folder.path);
        paths.addAll(_collectPathsUnder(folder.path));
      }
    }
    return paths;
  }

  Future<void> _handleAddToWhitelist(String path) async {
    final data = await AddToWhitelistDialog.show(context, path);
    if (data == null) return;

    try {
      final isDirectory = await FileSystemEntity.isDirectory(path);
      await ref
          .read(whitelistServiceProvider)
          .addItem(
            path: data.path,
            isDirectory: isDirectory,
            name: data.name,
            note: data.description,
            groupId: data.groupId,
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.resultsAddToWhitelist)));

        // Reload to reflect changes
        _loadRoots();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorImportFailed(e.toString()))),
        );
      }
    }
  }

  int _calculateSelectedSize() {
    int totalSize = 0;
    for (final entry in _selectedPaths.entries) {
      if (!entry.value) continue;
      final path = entry.key;
      totalSize += _getPathSize(path, _rootNodes ?? []);
    }
    return totalSize;
  }

  int _getPathSize(String path, List<DirectoryNode> nodes) {
    for (final node in nodes) {
      for (final file in node.files) {
        if (file.path == path) return file.sizeBytes;
      }
      for (final folder in node.folders) {
        if (folder.path == path) return folder.sizeBytes ?? 0;
        final expanded = _expandedDirectories[folder.path];
        if (expanded != null) {
          final size = _getPathSize(path, [expanded]);
          if (size > 0) return size;
        }
      }
    }
    return 0;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (bytes < 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
    }
  }

  Future<void> _handleDelete() async {
    final selectedPaths = _selectedPaths.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selectedPaths.isEmpty) return;

    final totalSize = _calculateSelectedSize();
    final formattedSize = _formatBytes(totalSize);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.dialogConfirmDelete),
        content: Text(AppLocalizations.of(context)!.dialogConfirmDeleteBatch(selectedPaths.length, formattedSize)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.dialogDelete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final deletionService = ref.read(deletionServiceProvider);
      
      // Build ScanResult list from selected paths
      final itemsToDelete = <ScanResult>[];
      for (final path in selectedPaths) {
        final size = _getPathSize(path, _rootNodes ?? []);
        final isDir = Directory(path).existsSync();
        itemsToDelete.add(ScanResult(
          path: path,
          sizeBytes: size,
          modifiedAt: DateTime.now(),
          isDirectory: isDir,
        ));
      }

      final result = await deletionService.deleteItems(itemsToDelete);
      final formattedFreed = _formatBytes(result.freedBytes);

      if (mounted) {
        if (result.failCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)!.successDelete(result.successCount, formattedFreed)}\n${AppLocalizations.of(context)!.errorImportFailed("${result.failCount} items failed")}',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.successDelete(result.successCount, formattedFreed),
              ),
            ),
          );
        }
        // Clear selection and reload
        setState(() {
          _selectedPaths.clear();
        });
        _loadRoots();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorImportFailed(e.toString()))));
      }
    }
  }

  void _selectAll() {
    setState(() {
      _collectAllPaths(_rootNodes ?? []).forEach((path) {
        _selectedPaths[path] = true;
      });
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedPaths.clear();
    });
  }

  List<String> _collectAllPaths(List<DirectoryNode> nodes) {
    final paths = <String>[];
    for (final node in nodes) {
      for (final file in node.files) {
        paths.add(file.path);
      }
      for (final folder in node.folders) {
        paths.add(folder.path);
        // Recursively collect from expanded directories
        final expanded = _expandedDirectories[folder.path];
        if (expanded != null) {
          paths.addAll(_collectAllPaths([expanded]));
        }
      }
    }
    return paths;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f5): const RefreshIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (_) => _loadRoots(),
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.resultsTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: AppLocalizations.of(context)!.scanRefresh,
                onPressed: _isLoading ? null : _loadRoots,
              ),
            ],
          ),
          body: _buildBody(),
          bottomNavigationBar: _buildActionBar(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rootNodes == null || _rootNodes!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.scanResultsEmpty,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _rootNodes!.length,
      itemBuilder: (context, index) {
        final root = _rootNodes![index];
        // Wrap root as a FolderNode so it can be rendered as a tree node
        final rootFolder = FolderNode(
          path: root.path,
          name: root.path,
          sizeBytes: null,
          autoExpand: true, // Roots start expanded
          modifiedAt: DateTime.now(),
        );
        return TreeNodeWidget(
          folder: rootFolder,
          selectedPaths: _selectedPaths,
          expandedDirectories: _expandedDirectories,
          onSelectionChanged: _handleSelection,
          onAddToWhitelist: _handleAddToWhitelist,
          onExpand: _expandDirectory,
          depth: 0,
        );
      },
    );
  }

  Widget? _buildActionBar() {
    final selectedCount = _selectedPaths.values.where((v) => v).length;

    if (selectedCount == 0 && (_rootNodes == null || _rootNodes!.isEmpty)) {
      return null;
    }

    return BottomAppBar(
      child: Row(
        children: [
          TextButton.icon(
            onPressed: selectedCount > 0 ? _deselectAll : _selectAll,
            icon: Icon(
              selectedCount > 0
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            label: Text(selectedCount > 0 ? AppLocalizations.of(context)!.resultsDeselectAll : AppLocalizations.of(context)!.resultsSelectAll),
          ),
          const Spacer(),
          if (selectedCount > 0) ...[
            FilledButton.icon(
              onPressed: _handleDelete,
              icon: const Icon(Icons.delete),
              label: Text(AppLocalizations.of(context)!.resultsDeleteSelected(selectedCount)),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
