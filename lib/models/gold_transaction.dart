import 'package:hive/hive.dart';

part 'gold_transaction.g.dart';

@HiveType(typeId: 1)
class GoldTransaction {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final TransactionType type;

  @HiveField(3)
  final double weight;

  @HiveField(4)
  final double price;

  @HiveField(5)
  final String? note;

  const GoldTransaction({
    required this.id,
    required this.date,
    required this.type,
    required this.weight,
    required this.price,
    this.note,
  });

  // Hive 存储方法
  Future<void> save() async {
    final box = Hive.box<GoldTransaction>('transactions');
    await box.put(id, this);
  }

  // 删除方法
  Future<void> delete() async {
    final box = Hive.box<GoldTransaction>('transactions');
    await box.delete(id);
  }

  // 带更新的复制方法
  GoldTransaction copyWith({
    String? id,
    DateTime? date,
    TransactionType? type,
    double? weight,
    double? price,
    String? note,
  }) {
    return GoldTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      weight: weight ?? this.weight,
      price: price ?? this.price,
      note: note ?? this.note,
    );
  }

  // 计算交易金额
  double get amount => weight * price;

  // 格式化日期显示
  String get formattedDate =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

@HiveType(typeId: 2)
enum TransactionType {
  @HiveField(0)
  buy,

  @HiveField(1)
  sell
}
