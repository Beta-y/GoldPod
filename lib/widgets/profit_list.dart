import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../providers/profit_provider.dart';
import '../models/gold_transaction.dart';
import '../providers/transaction_provider.dart';

class ProfitScreen extends StatefulWidget {
  const ProfitScreen({super.key});

  @override
  State<ProfitScreen> createState() => _ProfitListState();
}

class _ProfitListState extends State<ProfitScreen> {
  final Map<String, bool> _expandedGroups = {};

  @override
  Widget build(BuildContext context) {
    final ledgerId = Provider.of<String>(context);
    final provider = context.watch<ProfitProvider>();
    final providerTrans = context.watch<TransactionProvider>();
    final profits = provider.calculateGroupedProfits(
        ledgerId, providerTrans.currentStrategy);

    if (profits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无利润数据',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // 初始化所有分组键
    for (final yearProfit in profits) {
      _expandedGroups.putIfAbsent('year_${yearProfit.year}', () => true);
      for (final monthProfit in yearProfit.monthProfits) {
        _expandedGroups.putIfAbsent(
            'month_${yearProfit.year}_${monthProfit.month}', () => true);
        for (final dayProfit in monthProfit.dayProfits) {
          _expandedGroups.putIfAbsent(
              'day_${yearProfit.year}_${monthProfit.month}_${dayProfit.day}',
              () => false);
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: profits.length,
      itemBuilder: (context, index) {
        final yearProfit = profits[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            dense: true,
            key: ValueKey(yearProfit.year),
            initiallyExpanded:
                _expandedGroups['year_${yearProfit.year}'] ?? true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${yearProfit.year}年',
                  style: const TextStyle(fontSize: 14),
                ),
                _buildProfitText(yearProfit.totalProfit),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                child: Column(
                  children: yearProfit.monthProfits.map((monthProfit) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        dense: true,
                        key:
                            ValueKey('${yearProfit.year}_${monthProfit.month}'),
                        initiallyExpanded: _expandedGroups[
                                'month_${yearProfit.year}_${monthProfit.month}'] ??
                            true,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${monthProfit.month}月',
                              style: const TextStyle(fontSize: 14),
                            ),
                            _buildProfitText(monthProfit.totalProfit),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 8, right: 8, bottom: 4),
                            child: Column(
                              children: monthProfit.dayProfits.map((dayProfit) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    dense: true,
                                    key: ValueKey(
                                        '${yearProfit.year}_${monthProfit.month}_${dayProfit.day}'),
                                    initiallyExpanded: _expandedGroups[
                                            'day_${yearProfit.year}_${monthProfit.month}_${dayProfit.day}'] ??
                                        false,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${dayProfit.day}日',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        _buildProfitText(dayProfit.totalProfit),
                                      ],
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8, right: 8, bottom: 4),
                                        child: Column(
                                          children: dayProfit.transactionProfits
                                              .map((txnProfit) {
                                            final sellTransaction = Hive.box<
                                                        GoldTransaction>(
                                                    'transactions')
                                                .get(txnProfit.transactionId);

                                            if (sellTransaction == null ||
                                                sellTransaction.type !=
                                                    TransactionType.sell) {
                                              return const SizedBox.shrink();
                                            }

                                            final relatedBuys =
                                                provider.findRelatedBuys(
                                                    sellTransaction.id,
                                                    ledgerId);

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 24),
                                              child: Column(
                                                children: [
                                                  _buildTransactionCard(
                                                    transaction:
                                                        sellTransaction,
                                                    isBuy: false,
                                                  ),
                                                  ...relatedBuys.map((buy) {
                                                    return _buildTransactionCard(
                                                        transaction: buy,
                                                        isBuy: true);
                                                  }),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 2),
                                                    child: _buildProfitText(
                                                        txnProfit.profit),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        _expandedGroups[
                                                'day_${yearProfit.year}_${monthProfit.month}_${dayProfit.day}'] =
                                            expanded;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _expandedGroups[
                                    'month_${yearProfit.year}_${monthProfit.month}'] =
                                expanded;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            onExpansionChanged: (expanded) {
              setState(() {
                _expandedGroups['year_${yearProfit.year}'] = expanded;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard({
    required GoldTransaction transaction,
    required bool isBuy,
    String? extraInfo,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isBuy ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isBuy ? '买入' : '卖出'} ${NumberFormat("#,##0.0000").format(transaction.weight)}g',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '￥${NumberFormat("#,##0.00").format(transaction.amount)}',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '￥${NumberFormat("#,##0.00").format(transaction.price)}/g',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (transaction.note != null && transaction.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '备注: ${transaction.note}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            if (extraInfo != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  extraInfo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitText(double profit) {
    final isPositive = profit >= 0;
    return Text(
      '${isPositive ? '+' : ''}${NumberFormat("#,##0.00").format(profit)}',
      style: TextStyle(
        color: isPositive ? Colors.green : Colors.red,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
