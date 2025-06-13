import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/gold_transaction.dart';
import '../providers/transaction_provider.dart';
import 'dart:math';

class ProfitProvider with ChangeNotifier {
  InventoryStrategy _currentStrategy = InventoryStrategy.fifo;

  InventoryStrategy get currentStrategy => _currentStrategy;

  void setStrategy(InventoryStrategy strategy) {
    _currentStrategy = strategy;
    notifyListeners();
  }

  // 复制自TransactionProvider的_calculateBaseData实现
  Map<String, dynamic> _calculateProfitBaseData(String ledgerId) {
    final transactionBox = Hive.box<GoldTransaction>('transactions');

    // 获取所有买入记录
    final allBuys = transactionBox.values
        .where((t) => t.ledgerId == ledgerId && t.type == TransactionType.buy)
        .toList();

    // 获取所有卖出记录并按时间从早到晚排序
    final sells = transactionBox.values
        .where((t) => t.ledgerId == ledgerId && t.type == TransactionType.sell)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final remainingMap = {for (var buy in allBuys) buy.id: buy.weight};
    final profitHistory = <double>[];
    double totalCost = 0;
    double totalRevenue = 0;

    if (_currentStrategy == InventoryStrategy.average) {
      // 平均成本法逻辑
      for (final sell in sells) {
        final eligibleBuys = allBuys
            .where((buy) => buy.date.isBefore(sell.date))
            .where((buy) => (remainingMap[buy.id] ?? 0) > 0)
            .toList();

        final totalAvailableWeight = eligibleBuys.fold(
            0.0, (sum, buy) => sum + (remainingMap[buy.id] ?? 0));

        if (totalAvailableWeight == 0) continue;

        final avgPrice = eligibleBuys.fold(
              0.0,
              (sum, buy) => sum + (remainingMap[buy.id] ?? 0) * buy.price,
            ) /
            totalAvailableWeight;

        final cost = sell.weight * avgPrice;
        final revenue = sell.weight * sell.price;
        totalCost += cost;
        totalRevenue += revenue;
        profitHistory.add(revenue - cost);

        var remainingToDeduct = sell.weight;
        for (final buy in eligibleBuys) {
          final available = remainingMap[buy.id] ?? 0;
          final ratio = available / totalAvailableWeight;
          final intendedDeduct = sell.weight * ratio;
          final deducted = min(available, intendedDeduct);

          remainingMap[buy.id] = available - deducted;
          remainingToDeduct -= deducted;
        }

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
      // 其他策略逻辑
      for (final sell in sells) {
        List<GoldTransaction> eligibleBuys = allBuys
            .where((buy) => buy.date.isBefore(sell.date))
            .where((buy) => (remainingMap[buy.id] ?? 0) > 0)
            .toList();

        switch (_currentStrategy) {
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

    return {
      'sells': sells,
      'profitHistory': profitHistory,
      'totalCost': totalCost,
      'totalRevenue': totalRevenue,
    };
  }

  List<YearProfit> calculateGroupedProfits(String ledgerId) {
    final data = _calculateProfitBaseData(ledgerId);
    final sells = data['sells'] as List<GoldTransaction>;
    final profitHistory = data['profitHistory'] as List<double>;

    final yearMap = <int, Map<int, Map<int, List<TransactionProfit>>>>{};

    for (int i = 0; i < sells.length; i++) {
      final sell = sells[i];
      final profit = profitHistory[i];

      final year = sell.date.year;
      final month = sell.date.month;
      final day = sell.date.day;

      yearMap.putIfAbsent(year, () => {});
      yearMap[year]!.putIfAbsent(month, () => {});
      yearMap[year]![month]!.putIfAbsent(day, () => []);

      yearMap[year]![month]![day]!.add(TransactionProfit(
        date: sell.date,
        profit: profit,
        transactionId: sell.id,
      ));
    }

    return yearMap.entries.map((yearEntry) {
      final year = yearEntry.key;
      final monthMap = yearEntry.value;

      final monthProfits = monthMap.entries.map((monthEntry) {
        final month = monthEntry.key;
        final dayMap = monthEntry.value;

        final dayProfits = dayMap.entries.map((dayEntry) {
          final day = dayEntry.key;
          final transactions = dayEntry.value
            ..sort((a, b) => b.date.compareTo(a.date));

          return DayProfit(
            day: day,
            totalProfit: transactions.fold(0.0, (sum, t) => sum + t.profit),
            transactionProfits: transactions,
          );
        }).toList()
          ..sort((a, b) => b.day.compareTo(a.day));

        return MonthProfit(
          month: month,
          totalProfit: dayProfits.fold(0.0, (sum, d) => sum + d.totalProfit),
          dayProfits: dayProfits,
        );
      }).toList()
        ..sort((a, b) => b.month.compareTo(a.month));

      return YearProfit(
        year: year,
        totalProfit: monthProfits.fold(0.0, (sum, m) => sum + m.totalProfit),
        monthProfits: monthProfits,
      );
    }).toList()
      ..sort((a, b) => b.year.compareTo(a.year));
  }

  List<GoldTransaction> findRelatedBuys(String sellId, String ledgerId) {
    final transactionBox = Hive.box<GoldTransaction>('transactions');
    final sellTransaction = transactionBox.get(sellId);

    // 空安全检查
    if (sellTransaction?.type != TransactionType.sell) return [];

    // 获取所有可能关联的买入记录（按当前策略排序）
    final allBuys = transactionBox.values
        .where((t) =>
            t.ledgerId == ledgerId &&
            t.type == TransactionType.buy &&
            t.date.isBefore(sellTransaction!.date))
        .toList()
      ..sort((a, b) {
        switch (_currentStrategy) {
          case InventoryStrategy.fifo:
            return a.date.compareTo(b.date);
          case InventoryStrategy.lifo:
            return b.date.compareTo(a.date);
          case InventoryStrategy.lowest:
            return a.price.compareTo(b.price);
          case InventoryStrategy.highest:
            return b.price.compareTo(b.price);
          case InventoryStrategy.average:
            return 0;
        }
      });

    // 模拟库存扣除过程，只记录关联的原始买入单据
    final relatedBuys = <GoldTransaction>[];
    final sell = sellTransaction!;
    double remainingWeight = sell.weight;
    final availableMap = <String, double>{};

    // 计算每笔买入的剩余可用重量
    for (final buy in allBuys) {
      availableMap[buy.id] =
          buy.weight - _getUsedWeight(buy.id, sellTransaction.date);
    }

    // 找出实际关联的原始买入单据
    for (final buy in allBuys) {
      if (remainingWeight <= 0) break;

      final available = availableMap[buy.id] ?? 0;
      final used = min(available, remainingWeight);

      if (used > 0) {
        relatedBuys.add(buy); // 这里直接添加原始买入单据
        remainingWeight -= used;
      }
    }

    return relatedBuys;
  }

// 辅助方法：计算某买入在指定时间前已被使用的重量
  double _getUsedWeight(String buyId, DateTime beforeDate) {
    final transactionBox = Hive.box<GoldTransaction>('transactions');
    double used = 0;

    // 找出所有在该卖出之前的卖出交易
    final previousSells = transactionBox.values
        .where((t) =>
            t.type == TransactionType.sell && t.date.isBefore(beforeDate))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // 按时间顺序处理

    // 模拟历史扣除过程
    for (final sell in previousSells) {
      final relatedBuys = _simulateSellDeduction(sell, sell.ledgerId);
      used += relatedBuys[buyId] ?? 0;
    }

    return used;
  }

// 模拟单笔卖出交易的扣除过程
  Map<String, double> _simulateSellDeduction(
      GoldTransaction sell, String ledgerId) {
    final transactionBox = Hive.box<GoldTransaction>('transactions');
    final result = <String, double>{};

    final allBuys = transactionBox.values
        .where((t) =>
            t.ledgerId == ledgerId &&
            t.type == TransactionType.buy &&
            t.date.isBefore(sell.date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // 默认按FIFO处理

    double remaining = sell.weight;
    for (final buy in allBuys) {
      if (remaining <= 0) break;

      final available = buy.weight - (result[buy.id] ?? 0);
      final used = min(available, remaining);

      if (used > 0) {
        result[buy.id] = (result[buy.id] ?? 0) + used;
        remaining -= used;
      }
    }

    return result;
  }
}

// 利润模型类
class TransactionProfit {
  final DateTime date;
  final double profit;
  final String transactionId;

  TransactionProfit({
    required this.date,
    required this.profit,
    required this.transactionId,
  });
}

class YearProfit {
  final int year;
  final double totalProfit;
  final List<MonthProfit> monthProfits;

  YearProfit({
    required this.year,
    required this.totalProfit,
    required this.monthProfits,
  });
}

class MonthProfit {
  final int month;
  final double totalProfit;
  final List<DayProfit> dayProfits;

  MonthProfit({
    required this.month,
    required this.totalProfit,
    required this.dayProfits,
  });
}

class DayProfit {
  final int day;
  final double totalProfit;
  final List<TransactionProfit> transactionProfits;

  DayProfit({
    required this.day,
    required this.totalProfit,
    required this.transactionProfits,
  });
}
