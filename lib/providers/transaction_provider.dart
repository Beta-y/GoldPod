import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:encrypt/encrypt.dart' as encrypt; // 添加别名
import 'package:bill_app/models/gold_transaction.dart';
import 'dart:math';

class TransactionProvider extends ChangeNotifier {
  final Box<GoldTransaction> _transactionBox;
  final encrypt.Encrypter _encrypter; // 使用完整限定名
  List<GoldTransaction>? _cachedTransactions; // 缓存优化

  TransactionProvider({required encrypt.Encrypter encrypter}) // 参数类型同步修改
      : _encrypter = encrypter,
        _transactionBox = Hive.box<GoldTransaction>('transactions');

  List<GoldTransaction> get transactions {
    return _transactionBox.values
        .map(_decryptTransaction) // 使用统一解密方法
        .toList();
  }

  // 修改：统一使用Hive作为数据源，移除_ledger
  InventoryStrategy _strategy = InventoryStrategy.fifo;

  // 获取当前策略
  InventoryStrategy get currentStrategy => _strategy;

  // 新增：创建买入交易（金额→克重）
  void addBuyTransaction({
    required String id,
    required DateTime date,
    required double amount,
    required double price,
    String? note,
    required String ledgerId,
  }) {
    if (amount <= 0) throw ArgumentError('总额必须大于0');
    if (price <= 0) throw ArgumentError('价格必须大于0');

    final transaction = GoldTransaction.buy(
      id: id,
      date: date,
      amount: amount,
      price: price,
      note: note,
      ledgerId: ledgerId,
    );

    _transactionBox.put(id, _encryptTransaction(transaction));
    _cachedTransactions = null;
    notifyListeners();
  }

  // 新增：创建卖出交易（克重→金额）
  void addSellTransaction({
    required String id,
    required DateTime date,
    required double weight,
    required double price,
    String? note,
    required String ledgerId,
  }) {
    if (weight <= 0) throw ArgumentError('克重必须大于0');
    if (price <= 0) throw ArgumentError('价格必须大于0');

    final transaction = GoldTransaction.sell(
      id: id,
      date: date,
      weight: weight,
      price: price,
      note: note,
      ledgerId: ledgerId,
    );

    _transactionBox.put(id, _encryptTransaction(transaction));
    _cachedTransactions = null;
    notifyListeners();
  }

  // 更新交易记录（带缓存清理）
  void updateTransaction(GoldTransaction transaction) {
    _transactionBox.put(transaction.id, transaction);
    _cachedTransactions = null;
    notifyListeners();
  }

  // 删除交易记录（带缓存清理）
  void deleteTransaction(String id) {
    _transactionBox.delete(id);
    _cachedTransactions = null;
    notifyListeners();
  }

  GoldTransaction? getTransactionById(String id) {
    final transaction = _transactionBox.get(id);
    return transaction != null
        ? _decryptTransaction(transaction) // 使用统一解密方法
        : null;
  }

  // 加密整个交易对象
  GoldTransaction _encryptTransaction(GoldTransaction t) {
    // return t.copyWith(
    //   note: t.note != null ? _encryptData(t.note!) : null,
    //   // 可以加密其他敏感字段...
    // );
    return t;
  }

  // 解密整个交易对象
  GoldTransaction _decryptTransaction(GoldTransaction transaction) {
    // return transaction.copyWith(
    //   note: transaction.note != null ? _decryptData(transaction.note!) : null,
    //   // 可以添加其他需要解密的字段...
    // );
    return transaction;
  }

  // 加密敏感数据的方法
  String _encryptData(String data) {
    try {
      // Hive 内部使用固定 IV，所以这里不需要 IV
      final encrypted = _encrypter.encrypt(data);
      return encrypted.base64;
    } catch (e) {
      debugPrint('加密失败: $e');
      throw Exception('数据加密失败');
    }
  }

  String _decryptData(String encryptedData) {
    try {
      // Hive 内部使用固定 IV
      return _encrypter.decrypt64(encryptedData);
    } catch (e) {
      debugPrint('解密失败: $e');
      throw Exception('数据解密失败');
    }
  }

  Map<String, dynamic> _calculateBaseData(String ledgerId) {
    final buys = _getSortedBuys(ledgerId);
    final sells = transactions
        .where((t) => t.ledgerId == ledgerId && t.type == TransactionType.sell)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final remainingMap = {for (var buy in buys) buy.id: buy.weight};
    final profitHistory = <double>[];
    double totalCost = 0;
    double totalRevenue = 0;

    if (_strategy == InventoryStrategy.average) {
      final totalBuyWeight = buys.fold(0.0, (sum, buy) => sum + buy.weight);
      final totalSellWeight = sells.fold(0.0, (sum, sell) => sum + sell.weight);
      final remainingTotalWeight = totalBuyWeight - totalSellWeight;
      final avgPrice = buys.isEmpty
          ? 0
          : buys.fold(0.0, (sum, buy) => sum + buy.weight * buy.price) /
              totalBuyWeight;

      // 计算利润
      for (final sell in sells) {
        final cost = sell.weight * avgPrice;
        final revenue = sell.weight * sell.price;
        totalCost += cost;
        totalRevenue += revenue;
        profitHistory.add(revenue - cost);
      }

      // 更新remainingMap（按比例分摊）
      for (final buy in buys) {
        final originalRatio = buy.weight / totalBuyWeight;
        remainingMap[buy.id] = max(0.0, remainingTotalWeight * originalRatio);
      }
    } else {
      for (final sell in sells) {
        double remaining = sell.weight;
        double sellCost = 0;

        for (final buy in buys) {
          if (remaining <= 0) break;
          final available = remainingMap[buy.id] ?? 0;
          final used = min(available, remaining);
          sellCost += used * buy.price;
          remainingMap[buy.id] = available - used;
          remaining -= used;
        }

        final revenue = sell.weight * sell.price;
        totalCost += sellCost;
        totalRevenue += revenue;
        profitHistory.add(revenue - sellCost);
      }
    }

    // 计算累计利润
    List<double> cumulative = [];
    double total = 0;
    for (final p in profitHistory) {
      total += p;
      cumulative.add(total);
    }

    return {
      'buys': buys,
      'sells': sells,
      'remainingMap': remainingMap,
      'totalCost': totalCost,
      'totalRevenue': totalRevenue,
      'profitHistory': profitHistory,
      'cumulativeProfits': cumulative,
    };
  }

  // 修改后的计算方法
  List<InventoryItem> calculateInventory(String ledgerId) {
    final data = _calculateBaseData(ledgerId);
    final remainingMap = data['remainingMap'] as Map<String, double>;
    final buys = data['buys'] as List<GoldTransaction>;

    return [
      for (final buy in buys)
        if ((remainingMap[buy.id] ?? 0) > 0)
          InventoryItem(buy, remainingMap[buy.id]!)
    ];
  }

  Map<String, double> calculateSellProfits(String ledgerId) {
    final data = _calculateBaseData(ledgerId);
    final cumulative = data['cumulativeProfits'] as List<double>;

    return {
      'totalCost': data['totalCost'] as double,
      'totalRevenue': data['totalRevenue'] as double,
      'latestProfit': cumulative.isNotEmpty ? cumulative.last : 0,
      'previousProfit':
          cumulative.length > 1 ? cumulative[cumulative.length - 2] : 0,
    };
  }

  // 优化后的买入记录排序方法
  List<GoldTransaction> _getSortedBuys(String ledgerId) {
    final buys = transactions
        .where(
            (t) => (t.type == TransactionType.buy) && (t.ledgerId == ledgerId))
        .toList();

    switch (_strategy) {
      case InventoryStrategy.fifo:
        buys.sort((a, b) => a.date.compareTo(b.date));
        break;
      case InventoryStrategy.lifo:
        buys.sort((a, b) => b.date.compareTo(a.date));
        break;
      case InventoryStrategy.lowest:
        buys.sort((a, b) => a.price.compareTo(b.price));
        break;
      case InventoryStrategy.highest:
        buys.sort((a, b) => b.price.compareTo(a.price));
        break;
      case InventoryStrategy.average:
        break; // 平均价策略不需要排序，直接返回原列表
    }
    return buys;
  }

  // 设置仓位策略（带缓存清理）
  void setStrategy(InventoryStrategy strategy) {
    if (_strategy == strategy) return;
    _strategy = strategy;
    _cachedTransactions = null; // 清除缓存
    notifyListeners();
  }
}

// 仓位项模型
class InventoryItem {
  final GoldTransaction transaction;
  final double remainingWeight;

  InventoryItem(this.transaction, this.remainingWeight);
}

// 仓位策略枚举
enum InventoryStrategy {
  fifo, // 先入先出
  lifo, // 先入后出
  lowest, // 低价先出
  highest, // 高价先出
  average, // 卖出只减克重
}
