import 'package:drift/drift.dart';
import '../database.dart';

class GroupRepository {
  final AppDatabase _db;

  GroupRepository(this._db);

  Future<Group> createGroup({
    required String name,
    String? note,
    int? parentId,
  }) async {
    return await _db.transaction(() async {
      final id = await _db
          .into(_db.groups)
          .insert(GroupsCompanion.insert(name: name, note: Value(note)));

      await _db
          .into(_db.groupClosure)
          .insert(
            GroupClosureCompanion.insert(
              ancestor: id,
              descendant: id,
              depth: 0,
            ),
          );

      if (parentId != null) {
        await _db.customInsert(
          '''
          INSERT INTO group_closure (ancestor, descendant, depth)
          SELECT ancestor, ?, depth + 1
          FROM group_closure
          WHERE descendant = ?
          ''',
          variables: [Variable.withInt(id), Variable.withInt(parentId)],
          updates: {_db.groupClosure},
        );
      }

      return (await getGroupById(id))!;
    });
  }

  Future<Group> updateGroup(int id, {String? name, String? note}) async {
    await (_db.update(_db.groups)..where((t) => t.id.equals(id))).write(
      GroupsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        note: Value(note),
      ),
    );
    return (await getGroupById(id))!;
  }

  Future<void> deleteGroup(int id) async {
    final children = await getChildren(id);
    if (children.isNotEmpty) {
      throw Exception(
        'Cannot delete group with children. Use deleteGroupAndChildren instead.',
      );
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.groupClosure,
      )..where((t) => t.ancestor.equals(id) | t.descendant.equals(id))).go();

      // Update whitelist items to remove group association
      await (_db.update(_db.whitelistItems)..where((t) => t.groupId.equals(id)))
          .write(const WhitelistItemsCompanion(groupId: Value(null)));

      await (_db.delete(_db.groups)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> deleteGroupAndChildren(int id) async {
    await _db.transaction(() async {
      final descendantIds = await _db
          .customSelect(
            'SELECT descendant FROM group_closure WHERE ancestor = ?',
            variables: [Variable.withInt(id)],
            readsFrom: {_db.groupClosure},
          )
          .map((row) => row.read<int>('descendant'))
          .get();

      if (descendantIds.isEmpty) return;

      await (_db.delete(_db.groupClosure)..where(
            (t) =>
                t.ancestor.isIn(descendantIds) |
                t.descendant.isIn(descendantIds),
          ))
          .go();

      // Update whitelist items to remove group associations
      await (_db.update(_db.whitelistItems)
            ..where((t) => t.groupId.isIn(descendantIds)))
          .write(const WhitelistItemsCompanion(groupId: Value(null)));

      await (_db.delete(
        _db.groups,
      )..where((t) => t.id.isIn(descendantIds))).go();
    });
  }

  Future<Group?> getGroupById(int id) async {
    return await (_db.select(
      _db.groups,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<Group>> getRootGroups() async {
    final rootIds = await _db
        .customSelect(
          '''
      SELECT g.id
      FROM groups g
      WHERE NOT EXISTS (
        SELECT 1 FROM group_closure gc
        WHERE gc.descendant = g.id AND gc.depth > 0
      )
      ''',
          readsFrom: {_db.groups, _db.groupClosure},
        )
        .map((row) => row.read<int>('id'))
        .get();

    if (rootIds.isEmpty) return [];

    return await (_db.select(
      _db.groups,
    )..where((t) => t.id.isIn(rootIds))).get();
  }

  Future<List<Group>> getChildren(int groupId) async {
    final childIds = await _db
        .customSelect(
          'SELECT descendant FROM group_closure WHERE ancestor = ? AND depth = 1',
          variables: [Variable.withInt(groupId)],
          readsFrom: {_db.groupClosure},
        )
        .map((row) => row.read<int>('descendant'))
        .get();

    if (childIds.isEmpty) return [];

    return await (_db.select(
      _db.groups,
    )..where((t) => t.id.isIn(childIds))).get();
  }

  Future<List<Group>> getDescendants(int groupId) async {
    final descendantIds = await _db
        .customSelect(
          'SELECT descendant FROM group_closure WHERE ancestor = ? AND depth > 0',
          variables: [Variable.withInt(groupId)],
          readsFrom: {_db.groupClosure},
        )
        .map((row) => row.read<int>('descendant'))
        .get();

    if (descendantIds.isEmpty) return [];

    return await (_db.select(
      _db.groups,
    )..where((t) => t.id.isIn(descendantIds))).get();
  }

  Future<List<Group>> getAncestors(int groupId) async {
    final ancestorRows = await _db
        .customSelect(
          'SELECT ancestor, depth FROM group_closure WHERE descendant = ? AND depth > 0 ORDER BY depth DESC',
          variables: [Variable.withInt(groupId)],
          readsFrom: {_db.groupClosure},
        )
        .get();

    if (ancestorRows.isEmpty) return [];

    final ancestorIds = ancestorRows
        .map((row) => row.read<int>('ancestor'))
        .toList();

    final groups = await (_db.select(
      _db.groups,
    )..where((t) => t.id.isIn(ancestorIds))).get();

    final groupMap = {for (var g in groups) g.id: g};
    return ancestorIds.map((id) => groupMap[id]!).toList();
  }

  Future<void> moveGroup(int groupId, {required int newParentId}) async {
    await _db.transaction(() async {
      final subtreeIds = await _db
          .customSelect(
            'SELECT descendant FROM group_closure WHERE ancestor = ?',
            variables: [Variable.withInt(groupId)],
            readsFrom: {_db.groupClosure},
          )
          .map((row) => row.read<int>('descendant'))
          .get();
      await (_db.delete(_db.groupClosure)..where(
            (t) =>
                t.descendant.isIn(subtreeIds) & t.ancestor.isNotIn(subtreeIds),
          ))
          .go();

      await _db.customInsert(
        '''
        INSERT INTO group_closure (ancestor, descendant, depth)
        SELECT p.ancestor, c.descendant, p.depth + c.depth + 1
        FROM group_closure p
        CROSS JOIN group_closure c
        WHERE p.descendant = ? AND c.ancestor = ?
        ''',
        variables: [Variable.withInt(newParentId), Variable.withInt(groupId)],
        updates: {_db.groupClosure},
      );
    });
  }

  Future<List<WhitelistItem>> getItemsInGroup(int groupId) async {
    return await (_db.select(
      _db.whitelistItems,
    )..where((t) => t.groupId.equals(groupId))).get();
  }

  Stream<List<WhitelistItem>> watchItemsInGroup(int groupId) {
    return (_db.select(
      _db.whitelistItems,
    )..where((t) => t.groupId.equals(groupId))).watch();
  }

  Future<Group?> getGroupForItem(int itemId) async {
    final item = await (_db.select(
      _db.whitelistItems,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();

    final groupId = item?.groupId;
    if (groupId == null) return null;
    return await getGroupById(groupId);
  }

  Future<void> addItemToGroup(int itemId, int groupId) async {
    await (_db.update(_db.whitelistItems)..where((t) => t.id.equals(itemId)))
        .write(WhitelistItemsCompanion(groupId: Value(groupId)));
  }

  Future<void> removeItemFromGroup(int itemId) async {
    await (_db.update(_db.whitelistItems)..where((t) => t.id.equals(itemId)))
        .write(const WhitelistItemsCompanion(groupId: Value(null)));
  }
}
