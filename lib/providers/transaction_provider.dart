import 'package:flutter/material.dart';
import '../models/gold_transaction.dart';
import 'dart:math';

class TransactionProvider extends ChangeNotifier {
  // 原始账目记录（用户手动操作）
  final List<GoldTransaction> _ledger = [];

  // 当前仓位策略
  InventoryStrategy _strategy = InventoryStrategy.fifo;

  // 获取账目记录（只读）
  List<GoldTransaction> get ledgerTransactions => [..._ledger];

  // 获取当前策略
  InventoryStrategy get currentStrategy => _strategy;

  // 当前计算的库存结果
  // List<InventoryItem> get currentInventory => calculateInventory();

  // 添加交易记录
  void addTransaction(GoldTransaction transaction) {
    if (transaction.type == TransactionType.sell) {
      _processSell(transaction);
    } else {
      _ledger.add(transaction);
    }
    notifyListeners();
  }

  // 仓位计算方法（使用账目数据作为输入）
  List<InventoryItem> calculateInventory() {
    final inventory = <InventoryItem>[];
    final buys = _getSortedBuys();
    final sells = _ledger.where((t) => t.type == TransactionType.sell).toList();

    final remainingMap = {for (var buy in buys) buy.id: buy.weight};

    for (final sell in sells) {
      double remainingSell = sell.weight;
      if (remainingSell <= 0) continue;

      // 按照策略顺序卖出
      for (final buy in buys) {
        if (remainingSell <= 0) break;
        final available = remainingMap[buy.id] ?? 0;
        final deducted = min(available, remainingSell);
        remainingMap[buy.id] = available - deducted;
        remainingSell -= deducted;
      }

      if (remainingSell > 0) {
        debugPrint('警告: 未能完全匹配卖出 ${sell.weight}g');
      }
    }

    // 生成最终仓位
    for (final buy in buys) {
      final remaining = remainingMap[buy.id] ?? 0;
      if (remaining > 0) {
        inventory.add(InventoryItem(buy, remaining));
      }
    }

    // debugPrint('当前策略: $_strategy');
    // debugPrint(
    //     '买入记录: ${buys.map((b) => '${b.weight}g@${b.price}元').join(', ')}');
    // debugPrint(
    //     '卖出记录: ${sells.map((b) => '${b.weight}g@${b.price}元').join(', ')}');
    // debugPrint(
    //     '计算结果: ${inventory.map((i) => '${i.remainingWeight}g@${i.transaction.price}元').join(', ')}');
    return inventory;
  }

  List<GoldTransaction> _getSortedBuys() {
    final buys = _ledger.where((t) => t.type == TransactionType.buy).toList();

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
    }
    return buys;
  }

  // 处理卖出交易
  void _processSell(GoldTransaction sell) {
    final isEditing = _ledger.any((t) => t.id == sell.id);
    if (isEditing) _ledger.removeWhere((t) => t.id == sell.id);

    final availableBuys = _getAvailableBuys(sell);
    double remaining = sell.weight;

    for (final buy in availableBuys) {
      if (remaining <= 0) break;
      final used = min(buy.weight, remaining);

      _ledger.add(sell.copyWith(weight: used));
      remaining -= used;
    }

    // 4. 处理未完全卖出的部分
    if (remaining > 0) {
      _ledger.add(sell.copyWith(weight: remaining));
    }
  }

  // 获取可用买入记录（根据策略）
  List<GoldTransaction> _getAvailableBuys(GoldTransaction sell) {
    final buys = _ledger.where((t) => t.type == TransactionType.buy).toList();

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
    }

    return buys;
  }

  // 更新交易记录
  void updateTransaction(String id, GoldTransaction newTransaction) {
    final index = _ledger.indexWhere((t) => t.id == id);
    if (index != -1) {
      _ledger[index] = newTransaction;
      notifyListeners();
    }
  }

  // 删除交易记录
  void removeTransaction(String id) {
    _ledger.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // 设置仓位策略
  void setStrategy(InventoryStrategy strategy) {
    if (_strategy == strategy) return; // 避免不必要的计算
    _strategy = strategy;
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
}
