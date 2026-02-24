import '../data/database.dart';
import '../data/repositories/group_repository.dart';

class GroupService {
  final GroupRepository _repo;

  GroupService(this._repo);

  Future<Group> createGroup({
    required String name,
    String? note,
    int? parentId,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }
    return _repo.createGroup(
      name: name.trim(),
      note: note?.trim(),
      parentId: parentId,
    );
  }

  Future<Group> updateGroup(int id, {String? name, String? note}) {
    if (name != null && name.trim().isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }
    return _repo.updateGroup(id, name: name?.trim(), note: note?.trim());
  }

  Future<void> deleteGroup(int id) => _repo.deleteGroup(id);

  Future<void> deleteGroupAndChildren(int id) =>
      _repo.deleteGroupAndChildren(id);

  Future<Group?> getGroupById(int id) => _repo.getGroupById(id);

  Future<List<Group>> getRootGroups() => _repo.getRootGroups();

  Future<List<Group>> getChildren(int groupId) => _repo.getChildren(groupId);

  Future<List<Group>> getDescendants(int groupId) =>
      _repo.getDescendants(groupId);

  Future<List<Group>> getAncestors(int groupId) => _repo.getAncestors(groupId);

  Future<void> moveGroup(int groupId, {required int newParentId}) =>
      _repo.moveGroup(groupId, newParentId: newParentId);

  Future<List<WhitelistItem>> getItemsInGroup(int groupId) =>
      _repo.getItemsInGroup(groupId);

  Stream<List<WhitelistItem>> watchItemsInGroup(int groupId) =>
      _repo.watchItemsInGroup(groupId);

  Future<Group?> getGroupForItem(int itemId) => _repo.getGroupForItem(itemId);

  Future<void> addItemToGroup(int itemId, int groupId) =>
      _repo.addItemToGroup(itemId, groupId);

  Future<void> removeItemFromGroup(int itemId) =>
      _repo.removeItemFromGroup(itemId);
}
