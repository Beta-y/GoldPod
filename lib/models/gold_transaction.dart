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

  @HiveField(6)
  final String ledgerId;

  @HiveField(7)
  final double amount;

  factory GoldTransaction.empty() => GoldTransaction(
        id: '',
        date: DateTime.now(),
        type: TransactionType.buy,
        weight: 0,
        price: 0,
        amount: 0,
        ledgerId: '',
      );

  GoldTransaction({
    required this.id,
    required this.date,
    required this.type,
    required this.weight,
    required this.price,
    required this.amount,
    this.note,
    required this.ledgerId,
  }) {
    // 构造函数内验证
    _validate();
  }

  // 验证方法
  void _validate() {
    if (id.isEmpty) throw ArgumentError('ID不能为空');
    if (price <= 0) throw ArgumentError('价格必须大于0');
    if (type == TransactionType.buy && amount <= 0) {
      throw ArgumentError('买入金额必须大于0');
    }
    if (type == TransactionType.sell && weight <= 0) {
      throw ArgumentError('卖出重量必须大于0');
    }
  }

  // 工厂方法：用于买入交易（输入金额和单价）
  factory GoldTransaction.buy({
    required String id,
    required DateTime date,
    required double amount,
    required double price,
    String? note,
    required String ledgerId,
  }) {
    if (price <= 0) throw ArgumentError('Price must be positive');

    return GoldTransaction(
      id: id,
      date: date,
      type: TransactionType.buy,
      weight: amount / price,
      price: price,
      amount: amount,
      note: note,
      ledgerId: ledgerId,
    );
  }

  // 工厂方法：用于卖出交易（输入克重和单价）
  factory GoldTransaction.sell({
    required String id,
    required DateTime date,
    required double weight,
    required double price,
    String? note,
    required String ledgerId,
  }) {
    if (price <= 0) throw ArgumentError('Price must be positive');

    return GoldTransaction(
      id: id,
      date: date,
      type: TransactionType.sell,
      weight: weight,
      price: price,
      amount: weight * price,
      note: note,
      ledgerId: ledgerId,
    );
  }

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
    double? amount,
    String? note,
    String? ledgerId,
  }) {
    return GoldTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      weight: weight ?? this.weight,
      price: price ?? this.price,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      ledgerId: ledgerId ?? this.ledgerId,
    );
  }

  // 格式化日期显示
  String get formattedDate =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type.index, // 0=buy, 1=sell
      'weight': weight,
      'price': price,
      'amount': amount,
      'note': note,
      'ledgerId': ledgerId,
    };
  }
}

@HiveType(typeId: 2)
enum TransactionType {
  @HiveField(0)
  buy,

  @HiveField(1)
  sell
}
