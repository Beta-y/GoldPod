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
      padding: const EdgeInsets.all(8),
      itemCount: profits.length,
      itemBuilder: (context, index) {
        final yearProfit = profits[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ExpansionTile(
            key: ValueKey(yearProfit.year),
            initiallyExpanded: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${yearProfit.year}年'),
                _buildProfitText(yearProfit.totalProfit),
              ],
            ),
            children: [
              ...yearProfit.monthProfits.map((monthProfit) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: ExpansionTile(
                    key: ValueKey('${yearProfit.year}_${monthProfit.month}'),
                    initiallyExpanded: true,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${monthProfit.month}月'),
                        _buildProfitText(monthProfit.totalProfit),
                      ],
                    ),
                    children: [
                      ...monthProfit.dayProfits.map((dayProfit) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: ExpansionTile(
                            key: ValueKey(
                                '${yearProfit.year}_${monthProfit.month}_${dayProfit.day}'),
                            initiallyExpanded: true,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${dayProfit.day}日'),
                                _buildProfitText(dayProfit.totalProfit),
                              ],
                            ),
                            children: [
                              ...dayProfit.transactionProfits.map((txnProfit) {
                                final sellTransaction =
                                    Hive.box<GoldTransaction>('transactions')
                                        .get(txnProfit.transactionId);
                                if (sellTransaction == null ||
                                    sellTransaction.type !=
                                        TransactionType.sell) {
                                  return const SizedBox
                                      .shrink(); // 返回空Widget或错误提示
                                }

                                final relatedBuys =
                                    Provider.of<ProfitProvider>(context)
                                        .findRelatedBuys(
                                            sellTransaction.id, ledgerId);

                                return Padding(
                                  padding: const EdgeInsets.only(left: 48),
                                  child: Column(
                                    children: [
                                      // 卖出卡片
                                      Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.arrow_downward,
                                                        color: Colors.red,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '卖出 ${NumberFormat("#,##0.0000").format(sellTransaction?.weight ?? 0)}g',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '￥${NumberFormat("#,##0.00").format(sellTransaction?.amount ?? 0)}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '￥${NumberFormat("#,##0.00").format(sellTransaction?.price ?? 0)}/g',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat(
                                                            'yyyy-MM-dd HH:mm:ss')
                                                        .format(sellTransaction
                                                                ?.date ??
                                                            DateTime.now()),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (sellTransaction?.note != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 6),
                                                  child: Text(
                                                    '备注: ${sellTransaction?.note}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // 关联买入卡片列表
                                      ...relatedBuys
                                          .map((buy) => Card(
                                                margin: const EdgeInsets.only(
                                                    bottom: 8),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .arrow_upward,
                                                                color: Colors
                                                                    .green,
                                                                size: 20,
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Text(
                                                                '买入 ${NumberFormat("#,##0.0000").format(buy.weight)}g',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          Text(
                                                            '￥${NumberFormat("#,##0.00").format(buy.amount)}',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            '￥${NumberFormat("#,##0.00").format(buy.price)}/g',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                          Text(
                                                            DateFormat(
                                                                    'yyyy-MM-dd HH:mm:ss')
                                                                .format(
                                                                    buy.date),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (buy.note != null)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 6),
                                                          child: Text(
                                                            '备注: ${buy.note}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ))
                                          .toList(),

                                      // 利润显示
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              top: 8, right: 8),
                                          child: _buildProfitText(
                                              txnProfit.profit),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
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
