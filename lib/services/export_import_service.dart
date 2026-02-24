import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../data/database.dart';
import 'group_service.dart';
import 'scan_root_service.dart';
import 'whitelist_service.dart';

class ExportImportService {
  final WhitelistService _whitelistService;
  final GroupService _groupService;
  final ScanRootService _scanRootService;

  ExportImportService(
    this._whitelistService,
    this._groupService,
    this._scanRootService,
  );

  Future<String> exportToJson() async {
    final items = await _whitelistService.getAllItems();
    final scanRoots = await _scanRootService.getAllScanRoots();

    final rootGroups = await _groupService.getRootGroups();
    final allGroups = <Map<String, dynamic>>[];
    final groupIndexMap = <int, int>{};

    Future<void> collectGroups(Group group, int? parentIndex) async {
      final currentIndex = allGroups.length;
      groupIndexMap[group.id] = currentIndex;

      allGroups.add({
        'name': group.name,
        'note': group.note,
        'parentIndex': parentIndex,
      });

      final children = await _groupService.getChildren(group.id);
      for (final child in children) {
        await collectGroups(child, currentIndex);
      }
    }

    for (final root in rootGroups) {
      await collectGroups(root, null);
    }

    final itemsData = <Map<String, dynamic>>[];
    for (final item in items) {
      int? groupIndex;
      if (item.groupId != null) {
        groupIndex = groupIndexMap[item.groupId];
      }
      itemsData.add({
        'path': item.path,
        'isDirectory': item.isDirectory,
        'name': item.name,
        'note': item.note,
        'groupIndex': groupIndex,
      });
    }


    final exportData = {
      'whitelistItems': itemsData,
      'groups': allGroups,
      'scanRoots': scanRoots
          .map((root) => {'path': root.path, 'enabled': root.enabled})
          .toList(),
    };

    return jsonEncode(exportData);
  }

  Future<void> exportToFile(String filePath) async {
    final json = await exportToJson();
    // On Android/iOS, file_picker requires bytes instead of direct file write
    if (Platform.isAndroid || Platform.isIOS) {
      final bytes = Uint8List.fromList(utf8.encode(json));
      await File(filePath).writeAsBytes(bytes);
    } else {
      await File(filePath).writeAsString(json);
    }
  }

  Future<void> importFromJson(String jsonString, {bool replace = false}) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // If replace mode, clear all existing data first
    if (replace) {
      // Delete all whitelist items
      final existingItems = await _whitelistService.getAllItems();
      for (final item in existingItems) {
        await _whitelistService.deleteItem(item.id);
      }
      // Delete all groups
      final existingGroups = await _groupService.getRootGroups();
      for (final group in existingGroups) {
        await _groupService.deleteGroupAndChildren(group.id);
      }
      // Delete all scan roots
      final existingScanRoots = await _scanRootService.getAllScanRoots();
      for (final root in existingScanRoots) {
        await _scanRootService.deleteScanRoot(root.id);
      }
    }


    final groupsData = (data['groups'] as List<dynamic>?) ?? [];
    final indexToGroupId = <int, int>{};

    for (var i = 0; i < groupsData.length; i++) {
      final groupData = groupsData[i] as Map<String, dynamic>;
      final parentIndex = groupData['parentIndex'] as int?;
      final parentId = parentIndex != null ? indexToGroupId[parentIndex] : null;

      final group = await _groupService.createGroup(
        name: groupData['name'] as String,
        note: groupData['note'] as String?,
        parentId: parentId,
      );

      indexToGroupId[i] = group.id;
    }

    final itemsData = (data['whitelistItems'] as List<dynamic>?) ?? [];
    for (final itemData in itemsData) {
      int? groupId;
      final groupIndices = (itemData['groupIndices'] as List<dynamic>?) ?? [];
      if (groupIndices.isNotEmpty) {
        // Backward compatibility: old format (many-to-many), take first
        groupId = indexToGroupId[groupIndices.first as int];
      } else if (itemData['groupIndex'] != null) {
        // New format (many-to-one)
        groupId = indexToGroupId[itemData['groupIndex'] as int];
      }
      
      // In merge mode, skip if path already exists
      if (!replace) {
        try {
          final existingItems = await _whitelistService.getAllItems();
          final pathExists = existingItems.any(
            (item) => item.path == itemData['path'] as String,
          );
          if (pathExists) {
            continue; // Skip duplicate path
          }
        } catch (_) {
          // If check fails, try to add anyway
        }
      }
      await _whitelistService.addItem(
        path: itemData['path'] as String,
        isDirectory: itemData['isDirectory'] as bool,
        name: itemData['name'] as String?,
        note: itemData['note'] as String?,
        groupId: groupId,
      );
    }

    final scanRootsData = (data['scanRoots'] as List<dynamic>?) ?? [];
    for (final rootData in scanRootsData) {
      // In merge mode, skip if path already exists
      if (!replace) {
        try {
          final existingRoots = await _scanRootService.getAllScanRoots();
          final pathExists = existingRoots.any(
            (root) => root.path == rootData['path'] as String,
          );
          if (pathExists) {
            continue; // Skip duplicate path
          }
        } catch (_) {
          // If check fails, try to add anyway
        }
      }
      await _scanRootService.addScanRoot(rootData['path'] as String);
    }
  }

  Future<void> importFromFile(String filePath, {bool replace = false}) async {
    try {
      final json = await File(filePath).readAsString();
      await importFromJson(json, replace: replace);
    } on FileSystemException catch (e) {
      throw Exception('Failed to read import file: ${e.message}');
    } on IOException catch (e) {
      throw Exception('Failed to read import file: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON format: ${e.message}');
    }
}
