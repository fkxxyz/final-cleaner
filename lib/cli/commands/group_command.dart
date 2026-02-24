import 'package:args/command_runner.dart';

import '../../data/database.dart';
import '../../services/group_service.dart';
import 'cli_command.dart';

/// Branch command for group management.
class GroupCommand extends Command<void> {
  @override
  final String name = 'group';

  @override
  final String description = 'Manage whitelist groups.';

  GroupCommand(GroupService service) {
    addSubcommand(_ListCommand(service));
    addSubcommand(_CreateCommand(service));
    addSubcommand(_DeleteCommand(service));
    addSubcommand(_ItemsCommand(service));
    addSubcommand(_AddItemCommand(service));
    addSubcommand(_RemoveItemCommand(service));
  }
}

class _ListCommand extends CliCommand {
  final GroupService _service;

  @override
  final String name = 'list';

  @override
  final String description = 'List root groups.';

  _ListCommand(this._service);

  @override
  Future<void> run() async {
    final groups = await _service.getRootGroups();
    printResult(_groupsToData(groups));
  }

  @override
  void printHuman(Object data) {
    final groups = data as List<Map<String, dynamic>>;
    if (groups.isEmpty) {
      print('No groups.');
      return;
    }
    print('${'ID'.padRight(6)}${'Name'.padRight(30)}Note');
    print('-' * 60);
    for (final g in groups) {
      print(
        '${g['id'].toString().padRight(6)}'
        '${(g['name'] as String).padRight(30)}'
        '${(g['note'] as String?) ?? ''}',
      );
    }
  }
}

class _CreateCommand extends CliCommand {
  final GroupService _service;

  @override
  final String name = 'create';

  @override
  final String description = 'Create a new group.';

  _CreateCommand(this._service) {
    argParser
      ..addOption('note', help: 'Note for the group.')
      ..addOption('parent-id', help: 'Parent group ID.');
  }

  @override
  Future<void> run() async {
    final groupName = requiredArg(0, 'name');
    final note = argResults!.option('note');
    final parentIdStr = argResults!.option('parent-id');
    final parentId = parentIdStr != null ? int.tryParse(parentIdStr) : null;
    if (parentIdStr != null && parentId == null) {
      usageError('--parent-id must be an integer, got: $parentIdStr');
    }

    final group = await _service.createGroup(
      name: groupName,
      note: note,
      parentId: parentId,
    );
    printResult({'id': group.id, 'name': group.name, 'note': group.note});
  }

  @override
  void printHuman(Object data) {
    final d = data as Map<String, dynamic>;
    print('Created group: ${d['name']} (id: ${d['id']})');
  }
}

class _DeleteCommand extends CliCommand {
  final GroupService _service;

  @override
  final String name = 'delete';

  @override
  final String description = 'Delete a group.';

  _DeleteCommand(this._service) {
    argParser.addFlag(
      'recursive',
      help: 'Delete group and all children.',
      negatable: false,
    );
  }

  @override
  Future<void> run() async {
    final id = requiredIntArg(0, 'id');
    final recursive = argResults!.flag('recursive');
    if (recursive) {
      await _service.deleteGroupAndChildren(id);
    } else {
      await _service.deleteGroup(id);
    }
    printResult({'deleted': id, 'recursive': recursive});
  }

  @override
  void printHuman(Object data) {
    final d = data as Map<String, dynamic>;
    print('Deleted group ${d['deleted']}');
  }
}

class _ItemsCommand extends CliCommand {
  final GroupService _service;

  @override
  final String name = 'items';

  @override
  final String description = 'List items in a group.';

  _ItemsCommand(this._service);

  @override
  Future<void> run() async {
    final groupId = requiredIntArg(0, 'group-id');
    final items = await _service.getItemsInGroup(groupId);
    printResult(
      items
          .map(
            (item) => {
              'id': item.id,
              'path': item.path,
              'isDirectory': item.isDirectory,
              'name': item.name,
              'note': item.note,
            },
          )
          .toList(),
    );
  }

  @override
  void printHuman(Object data) {
    final items = data as List<Map<String, dynamic>>;
    if (items.isEmpty) {
      print('No items in this group.');
      return;
    }
    print(
      '${'ID'.padRight(6)}'
      '${'Path'.padRight(50)}'
      '${'Type'.padRight(6)}'
      '${'Name'.padRight(20)}'
      'Note',
    );
    print('-' * 90);
    for (final item in items) {
      print(
        '${item['id'].toString().padRight(6)}'
        '${(item['path'] as String).padRight(50)}'
        '${(item['isDirectory'] as bool ? 'dir' : 'file').padRight(6)}'
        '${((item['name'] as String?) ?? '').padRight(20)}'
        '${(item['note'] as String?) ?? ''}',
      );
    }
  }
}

class _AddItemCommand extends CliCommand {
  final GroupService _service;

  @override
  final String name = 'add-item';

  @override
  final String description = 'Add an item to a group.';

  _AddItemCommand(this._service);

  @override
  Future<void> run() async {
    final itemId = requiredIntArg(0, 'item-id');
    final groupId = requiredIntArg(1, 'group-id');
    await _service.addItemToGroup(itemId, groupId);
    printResult({'itemId': itemId, 'groupId': groupId});
  }

  @override
  void printHuman(Object data) {
    final d = data as Map<String, dynamic>;
    print('Added item ${d['itemId']} to group ${d['groupId']}');
  }
}

class _RemoveItemCommand extends CliCommand {
  final GroupService _service;

  @override
  final String name = 'remove-item';

  @override
  final String description = 'Remove an item from a group.';

  _RemoveItemCommand(this._service);

  @override
  Future<void> run() async {
    final itemId = requiredIntArg(0, 'item-id');
    final groupId = requiredIntArg(1, 'group-id');
    await _service.removeItemFromGroup(itemId);
    printResult({'itemId': itemId, 'groupId': groupId});
  }

  @override
  void printHuman(Object data) {
    final d = data as Map<String, dynamic>;
    print('Removed item ${d['itemId']} from group ${d['groupId']}');
  }
}

List<Map<String, dynamic>> _groupsToData(List<Group> groups) {
  return groups
      .map(
        (g) => {
          'id': g.id,
          'name': g.name,
          'note': g.note,
          'createdAt': g.createdAt.toIso8601String(),
        },
      )
      .toList();
}
