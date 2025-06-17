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
  InventoryStrategy _strategy = InventoryStrategy.lifo;

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
    // 获取所有买入记录（保持原始顺序）
    final allBuys = transactions
        .where((t) => t.ledgerId == ledgerId && t.type == TransactionType.buy)
        .toList();

    // 获取所有卖出记录并按时间从早到晚排序
    final sells = transactions
        .where((t) => t.ledgerId == ledgerId && t.type == TransactionType.sell)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final remainingMap = {for (var buy in allBuys) buy.id: buy.weight};
    final profitHistory = <double>[];
    double totalCost = 0;
    double totalRevenue = 0;

    if (_strategy == InventoryStrategy.average) {
      // 专用平均成本法逻辑（动态比例）
      for (final sell in sells) {
        // 1. 筛选卖出日期之前的可用买入记录
        final eligibleBuys = allBuys
            .where((buy) => buy.date.isBefore(sell.date))
            .where((buy) => (remainingMap[buy.id] ?? 0) > 0)
            .toList();

        // 2. 计算当前可用库存的总重量和平均成本
        final totalAvailableWeight = eligibleBuys.fold(
            0.0, (sum, buy) => sum + (remainingMap[buy.id] ?? 0));

        if (totalAvailableWeight == 0) continue;

        final avgPrice = eligibleBuys.fold(
              0.0,
              (sum, buy) => sum + (remainingMap[buy.id] ?? 0) * buy.price,
            ) /
            totalAvailableWeight;

        // 3. 计算本次卖出的成本
        final cost = sell.weight * avgPrice;
        final revenue = sell.weight * sell.price;
        totalCost += cost;
        totalRevenue += revenue;
        profitHistory.add(revenue - cost);

        // 4. 动态按比例扣除库存
        var remainingToDeduct = sell.weight;
        for (final buy in eligibleBuys) {
          final available = remainingMap[buy.id] ?? 0;
          final ratio = available / totalAvailableWeight;
          final intendedDeduct = sell.weight * ratio; // 基于原始卖出量计算
          final deducted = min(available, intendedDeduct);

          remainingMap[buy.id] = available - deducted;
          remainingToDeduct -= deducted;
        }

        // 处理浮点精度误差（如有剩余）
        if (remainingToDeduct.abs() > 1e-6) {
          for (final buy
              in eligibleBuys.where((buy) => remainingMap[buy.id]! > 0)) {
            final adjust = min(remainingMap[buy.id]!, remainingToDeduct);
            remainingMap[buy.id] = remainingMap[buy.id]! - adjust;
            remainingToDeduct -= adjust;
            if (remainingToDeduct == 0) break;
          }
        }
      }
    } else {
      // 其他策略保持原有逻辑（FIFO/LIFO/最低价/最高价）
      for (final sell in sells) {
        // 获取卖出日期之前的买入记录并按策略排序
        List<GoldTransaction> eligibleBuys = allBuys
            .where((buy) => buy.date.isBefore(sell.date))
            .where((buy) => (remainingMap[buy.id] ?? 0) > 0)
            .toList();

        // 按策略排序（与_getSortedBuys一致）
        switch (_strategy) {
          case InventoryStrategy.fifo:
            eligibleBuys.sort((a, b) => a.date.compareTo(b.date));
            break;
          case InventoryStrategy.lifo:
            eligibleBuys.sort((a, b) => b.date.compareTo(a.date));
            break;
          case InventoryStrategy.lowest:
            eligibleBuys.sort((a, b) => a.price.compareTo(b.price));
            break;
          case InventoryStrategy.highest:
            eligibleBuys.sort((a, b) => b.price.compareTo(a.price));
            break;
          case InventoryStrategy.average:
            break; // 不会执行到这里
        }

        // 按策略扣除库存（非比例方式）
        double remaining = sell.weight;
        double sellCost = 0;
        for (final buy in eligibleBuys) {
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

    // 计算累计利润（保持不变）
    List<double> cumulative = [];
    double total = 0;
    for (final p in profitHistory) {
      total += p;
      cumulative.add(total);
    }

    return {
      'buys': allBuys,
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

    // 对data['buys']应用策略排序
    final buys = (data['buys'] as List<GoldTransaction>)
      ..sort((a, b) {
        switch (_strategy) {
          case InventoryStrategy.fifo:
            return a.date.compareTo(b.date); // 先进先出（按时间升序）
          case InventoryStrategy.lifo:
            return b.date.compareTo(a.date); // 后进先出（按时间降序）
          case InventoryStrategy.lowest:
            return a.price.compareTo(b.price); // 最低价优先
          case InventoryStrategy.highest:
            return b.price.compareTo(a.price); // 最高价优先
          case InventoryStrategy.average:
            return 0; // 平均价保持原顺序
        }
      });

    return [
      for (final buy in buys)
        if ((remainingMap[buy.id] ?? 0) >= 0.00005)
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
