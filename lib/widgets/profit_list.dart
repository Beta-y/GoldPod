import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../providers/profit_provider.dart';
import '../models/gold_transaction.dart';

class ProfitScreen extends StatefulWidget {
  const ProfitScreen({super.key});

  @override
  State<ProfitScreen> createState() => _ProfitListState();
}

class _ProfitListState extends State<ProfitScreen> {
  final Map<String, bool> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    // 初始化时设置所有层级为展开状态
    _expandedGroups['all_expanded'] = true;
  }

  @override
  Widget build(BuildContext context) {
    final ledgerId = Provider.of<String>(context);
    final provider = context.watch<ProfitProvider>();
    final profits = provider.calculateGroupedProfits(ledgerId);

    if (profits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_money, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无利润数据',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // 确保所有分组键都存在且值为true（展开）
    for (final yearProfit in profits) {
      _expandedGroups.putIfAbsent('year_${yearProfit.year}', () => true);
      for (final monthProfit in yearProfit.monthProfits) {
        _expandedGroups.putIfAbsent(
            'month_${yearProfit.year}_${monthProfit.month}', () => true);
        for (final dayProfit in monthProfit.dayProfits) {
          _expandedGroups.putIfAbsent(
              'day_${yearProfit.year}_${monthProfit.month}_${dayProfit.day}',
              () => true);
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4), // 减少外层padding
      itemCount: profits.length,
      itemBuilder: (context, index) {
        final yearProfit = profits[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2), // 减少卡片间距
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 8), // 调整标题内边距
            dense: true, // 启用紧凑模式
            key: ValueKey(yearProfit.year),
            initiallyExpanded: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${yearProfit.year}年',
                  style: const TextStyle(fontSize: 14), // 减小字体
                ),
                _buildProfitText(yearProfit.totalProfit),
              ],
            ),
            children: [
              Padding(
                // 添加Padding包裹children内容
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                child: Column(
                  children: [
                    ...yearProfit.monthProfits.map((monthProfit) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8), // 减少缩进
                        child: ExpansionTile(
                          tilePadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          dense: true,
                          key: ValueKey(
                              '${yearProfit.year}_${monthProfit.month}'),
                          initiallyExpanded: true,
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
                              // 添加Padding包裹children内容
                              padding: const EdgeInsets.only(
                                  left: 8, right: 8, bottom: 4),
                              child: Column(
                                children: [
                                  ...monthProfit.dayProfits.map((dayProfit) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16), // 减少缩进
                                      child: ExpansionTile(
                                        tilePadding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        dense: true,
                                        key: ValueKey(
                                            '${yearProfit.year}_${monthProfit.month}_${dayProfit.day}'),
                                        initiallyExpanded: false,
                                        title: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${dayProfit.day}日',
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                            _buildProfitText(
                                                dayProfit.totalProfit),
                                          ],
                                        ),
                                        children: [
                                          Padding(
                                            // 添加Padding包裹children内容
                                            padding: const EdgeInsets.only(
                                                left: 8, right: 8, bottom: 4),
                                            child: Column(
                                              children: [
                                                ...dayProfit.transactionProfits
                                                    .map((txnProfit) {
                                                  final sellTransaction =
                                                      Hive.box<GoldTransaction>(
                                                              'transactions')
                                                          .get(txnProfit
                                                              .transactionId);

                                                  if (sellTransaction == null ||
                                                      sellTransaction.type !=
                                                          TransactionType
                                                              .sell) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }

                                                  final provider = Provider.of<
                                                          ProfitProvider>(
                                                      context,
                                                      listen: false);
                                                  final relatedBuys =
                                                      provider.findRelatedBuys(
                                                          sellTransaction.id,
                                                          ledgerId);

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 24), // 减少缩进
                                                    child: Column(
                                                      children: [
                                                        // 卖出卡片
                                                        _buildTransactionCard(
                                                          transaction:
                                                              sellTransaction,
                                                          isBuy: false,
                                                        ),

                                                        // 关联买入卡片列表
                                                        ...relatedBuys
                                                            .map((buy) {
                                                          return _buildTransactionCard(
                                                              transaction: buy,
                                                              isBuy: true);
                                                        }).toList(),

                                                        // 利润显示
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top:
                                                                      2), // 减少间距
                                                          child:
                                                              _buildProfitText(
                                                                  txnProfit
                                                                      .profit),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
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
