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
      padding: const EdgeInsets.all(2),
      itemCount: profits.length,
      itemBuilder: (context, index) {
        final yearProfit = profits[index];
        return _buildYearCard(yearProfit);
      },
    );
  }

  Widget _buildYearCard(YearProfit yearProfit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent, // 关键修改点
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          dense: true,
          key: ValueKey(yearProfit.year),
          initiallyExpanded: _expandedGroups['year_${yearProfit.year}'] ?? true,
          title: Row(
            children: [
              Text(
                '${yearProfit.year}年',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildProfitText(yearProfit.totalProfit, fontSize: 16),
            ],
          ),
          children: [
            ...yearProfit.monthProfits.map((monthProfit) {
              return _buildMonthRow(monthProfit, yearProfit.year);
            })
          ],
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedGroups['year_${yearProfit.year}'] = expanded;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDayRow(DayProfit dayProfit, int year, int month) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent, // 关键修改点
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          dense: true,
          key: ValueKey('${year}_${month}_${dayProfit.day}'),
          title: Row(
            children: [
              Text(
                '${month}月${dayProfit.day}日',
                style: const TextStyle(fontSize: 14),
              ),
              const Spacer(),
              _buildProfitText(dayProfit.totalProfit),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
              child: _buildTransactionsGroup(dayProfit, year, month),
            )
          ],
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedGroups['day_${year}_${month}_${dayProfit.day}'] =
                  expanded;
            });
          },
        ),
      ),
    );
  }

  Widget _buildMonthRow(MonthProfit monthProfit, int year) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent, // 关键修改点
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          dense: true,
          key: ValueKey('${year}_${monthProfit.month}'),
          title: Row(
            children: [
              Text(
                '${monthProfit.month}月',
                style: const TextStyle(fontSize: 14),
              ),
              const Spacer(),
              _buildProfitText(monthProfit.totalProfit),
            ],
          ),
          children: [
            ...monthProfit.dayProfits.map((dayProfit) {
              return _buildDayRow(dayProfit, year, monthProfit.month);
            })
          ],
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedGroups['month_${year}_${monthProfit.month}'] = expanded;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTransactionsGroup(DayProfit dayProfit, int year, int month) {
    final provider = context.watch<ProfitProvider>();
    final ledgerId = Provider.of<String>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: dayProfit.transactionProfits.map((txnProfit) {
        final sellTransaction = Hive.box<GoldTransaction>('transactions')
            .get(txnProfit.transactionId);

        if (sellTransaction == null ||
            sellTransaction.type != TransactionType.sell) {
          return const SizedBox.shrink();
        }

        final relatedBuys =
            provider.findRelatedBuys(sellTransaction.id, ledgerId);

        return Column(
          children: [
            _buildTransactionCard(
              transaction: sellTransaction,
              isBuy: false,
            ),
            ...relatedBuys.map((entry) {
              final buy = entry['buy'] as GoldTransaction;
              return _buildTransactionCard(
                transaction: buy,
                isBuy: true,
              );
            }),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    '单笔利润: ',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  _buildProfitText(txnProfit.profit),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTransactionCard({
    required GoldTransaction transaction,
    required bool isBuy,
  }) {
    final icon = isBuy
        ? Icon(Icons.arrow_upward, color: Colors.green[700], size: 18)
        : Icon(Icons.arrow_downward, color: Colors.red[700], size: 18);

    final label = isBuy ? '买入' : '卖出';
    final formattedWeight =
        NumberFormat("#,##0.0000").format(transaction.weight);
    final formattedAmount = NumberFormat("#,##0.00").format(transaction.amount);
    final formattedPrice = NumberFormat("#,##0.00").format(transaction.price);
    final date = DateFormat('MM-dd HH:mm').format(transaction.date);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    icon,
                    const SizedBox(width: 6),
                    Text(
                      '$label $formattedWeight g',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  '￥$formattedAmount',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '单价 ￥$formattedPrice/g',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (transaction.note != null && transaction.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '备注: ${transaction.note}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitText(double profit, {double fontSize = 14}) {
    final isPositive = profit >= 0;
    return Text(
      '${isPositive ? '+' : ''}${NumberFormat("#,##0.00").format(profit)}',
      style: TextStyle(
        color: isPositive ? Colors.red[700] : Colors.green[700],
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
      ),
    );
  }
}
