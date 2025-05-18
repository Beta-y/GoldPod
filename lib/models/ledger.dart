import 'package:hive/hive.dart';

part 'ledger.g.dart';

@HiveType(typeId: 0)
class Ledger extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  bool isPinned;

  Ledger({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isPinned = false,
  });

  // 可选：添加复制方法
  Ledger copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? isPinned,
  }) {
    return Ledger(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
