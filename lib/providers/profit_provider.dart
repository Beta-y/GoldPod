import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/gold_transaction.dart';
import '../providers/transaction_provider.dart';
import 'dart:math';

class ProfitProvider with ChangeNotifier {
  Map<String, dynamic>? _cachedProfitData;
  String? _cachedLedgerId;
  InventoryStrategy? _cachedStrategy;

  InventoryStrategy _currentStrategy = InventoryStrategy.lifo;

  InventoryStrategy get currentStrategy => _currentStrategy;

  void setStrategy(InventoryStrategy strategy) {
    if (_currentStrategy != strategy) {
      _currentStrategy = strategy;
      _cachedProfitData = null; // 清除缓存
      notifyListeners();
    }
  }

  void clearCache() {
    _cachedProfitData = null;
    _cachedLedgerId = null;
    notifyListeners();
  }

  Map<String, dynamic> _calculateProfitBaseData(String ledgerId) {
    if (_cachedProfitData != null &&
        _cachedLedgerId == ledgerId &&
        _cachedStrategy == _currentStrategy) {
      return _cachedProfitData!;
    }

    // 清除旧缓存
    _cachedProfitData = null;

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
    final relatedBuysMap = <String, List<GoldTransaction>>{}; // 新增：记录每笔卖出的关联买入
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

        // 记录关联买入
        final relatedBuys = <GoldTransaction>[];
        var remainingToDeduct = sell.weight;

        for (final buy in eligibleBuys) {
          final available = remainingMap[buy.id] ?? 0;
          final ratio = available / totalAvailableWeight;
          final intendedDeduct = sell.weight * ratio;
          final deducted = min(available, intendedDeduct);

          if (deducted > 0) {
            relatedBuys.add(buy); // 直接添加原始买入单据
            remainingMap[buy.id] = available - deducted;
            remainingToDeduct -= deducted;
          }
        }

        // 处理浮点精度误差
        if (remainingToDeduct.abs() > 1e-6) {
          for (final buy
              in eligibleBuys.where((buy) => remainingMap[buy.id]! > 0)) {
            final adjust = min(remainingMap[buy.id]!, remainingToDeduct);
            remainingMap[buy.id] = remainingMap[buy.id]! - adjust;
            remainingToDeduct -= adjust;
            if (remainingToDeduct == 0) break;
          }
        }

        relatedBuysMap[sell.id] = relatedBuys;
      }
    } else {
      // 其他策略逻辑
      for (final sell in sells) {
        List<GoldTransaction> eligibleBuys = allBuys
            .where((buy) => buy.date.isBefore(sell.date))
            .where((buy) => (remainingMap[buy.id] ?? 0) > 0)
            .toList();

        // 按策略排序
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

        // 记录关联买入
        final relatedBuys = <GoldTransaction>[];
        double remaining = sell.weight;
        double sellCost = 0;

        for (final buy in eligibleBuys) {
          if (remaining <= 0) break;
          final available = remainingMap[buy.id] ?? 0;
          final used = min(available, remaining);

          if (used > 0) {
            relatedBuys.add(buy);
            sellCost += used * buy.price;
            remainingMap[buy.id] = available - used;
            remaining -= used;
          }
        }

        relatedBuysMap[sell.id] = relatedBuys;
        final revenue = sell.weight * sell.price;
        totalCost += sellCost;
        totalRevenue += revenue;
        profitHistory.add(revenue - sellCost);
      }
    }

    _cachedProfitData = {
      'sells': sells,
      'profitHistory': profitHistory,
      'totalCost': totalCost,
      'totalRevenue': totalRevenue,
      'relatedBuysMap': relatedBuysMap,
    };

    _cachedLedgerId = ledgerId;
    _cachedStrategy = _currentStrategy;

    return _cachedProfitData!;
  }

  List<YearProfit> calculateGroupedProfits(
      String ledgerId, InventoryStrategy strategy) {
    setStrategy(strategy);
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
    final data = _calculateProfitBaseData(ledgerId);
    return data['relatedBuysMap'][sellId] ?? [];
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
