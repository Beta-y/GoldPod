import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/profit_provider.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledgerId = Provider.of<String>(context);
    return Scaffold(
      appBar: null,
      body: _buildInventoryContent(context, ledgerId),
    );
  }

  Widget _buildInventoryContent(BuildContext context, String ledgerId) {
    final provider = context.watch<TransactionProvider>();
    final provider_profit = context.watch<ProfitProvider>();
    final inventory = provider.calculateInventory(ledgerId);
    final profits = provider.calculateSellProfits(ledgerId);

    return Column(
      children: [
        _buildStrategySelector(context, provider, provider_profit),
        const SizedBox(height: 8),
        _buildSummaryCard(context, inventory, profits),
        const SizedBox(height: 8),
        Expanded(
          child:
              _buildInventoryList(context, inventory, provider.currentStrategy),
        ),
      ],
    );
  }

  // 策略选择器（带视觉反馈）
  Widget _buildStrategySelector(BuildContext context,
      TransactionProvider provider, ProfitProvider provider_profit) {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text('仓位策略:', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<InventoryStrategy>(
                value: provider.currentStrategy,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: InventoryStrategy.values.map((strategy) {
                  return DropdownMenuItem(
                    value: strategy,
                    child: Text(
                      _getStrategyName(strategy),
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    provider.setStrategy(value);
                    provider_profit.setStrategy(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 统计卡片（关键数据突出显示）
  Widget _buildSummaryCard(
    BuildContext context,
    List<InventoryItem> inventory,
    Map<String, double> profits,
  ) {
    final (totalWeight, avgPrice, totalValue) =
        _calculateInventoryTotals(inventory);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('持仓总重量', '${totalWeight.toStringAsFixed(4)}g'),
            const Divider(height: 15),
            _buildSummaryRow('平均成本价', '￥${avgPrice.toStringAsFixed(2)}/g'),
            const Divider(height: 15),
            _buildSummaryRow('持仓总成本', '¥${totalValue.toStringAsFixed(2)}'),
            const Divider(height: 15),
            // 修改后的利润显示部分
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('最新累计利润', style: TextStyle(fontSize: 14)),
                      Text(
                        '前次累计利润',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${profits['latestProfit']!.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: profits['latestProfit']! >
                                  profits['previousProfit']!
                              ? Colors.red[700] // 上涨显示红色
                              : Colors.green[700], // 下跌显示绿色
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '¥${profits['previousProfit']!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 计算总重量、均价和总价值
  (double, double, double) _calculateInventoryTotals(
      List<InventoryItem> inventory) {
    if (inventory.isEmpty) return (0.0, 0.0, 0.0);

    final totalWeight =
        inventory.fold<double>(0.0, (sum, item) => sum + item.remainingWeight);
    final totalValue = inventory.fold<double>(0.0,
        (sum, item) => sum + (item.remainingWeight * item.transaction.price));
    final avgPrice = totalWeight > 0 ? totalValue / totalWeight : 0.0;
    return (totalWeight, avgPrice, totalValue);
  }

  // 库存列表（支持空状态）
  Widget _buildInventoryList(BuildContext context,
      List<InventoryItem> inventory, InventoryStrategy strategy) {
    if (inventory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无持仓记录',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: inventory.length,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (ctx, index) {
        final item = inventory[index];
        return _buildInventoryItem(context, item, strategy);
      },
    );
  }

  // 单个库存项（支持交互）
  Widget _buildInventoryItem(
      BuildContext context, InventoryItem item, InventoryStrategy strategy) {
    final theme = Theme.of(context);
    final isReduced = item.remainingWeight < item.transaction.weight;

    // 辅助函数：格式化数字，添加前导空格
    String formatNumber(double value, int maxIntegerDigits) {
      final integerDigits = value.toStringAsFixed(0).length;
      final leadingSpaces = ' ' * (maxIntegerDigits - integerDigits);
      return '$leadingSpaces${value.toStringAsFixed(4)}';
    }

    // 计算需要对齐的数字的最大整数位数
    final numbersToAlign = [
      item.transaction.weight,
      if (isReduced) item.transaction.weight - item.remainingWeight
    ];
    final maxIntegerDigits = numbersToAlign.fold<int>(0, (max, number) {
      final integerDigits = number.toStringAsFixed(0).length;
      return integerDigits > max ? integerDigits : max;
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2), width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Stack(
          // 使用Stack实现浮动效果
          children: [
            // 主内容列
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 当前重量（单独一行）
                Text(
                  '${item.remainingWeight.toStringAsFixed(4)}g',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 22),

                // 单价和日期行
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '单价: ￥${item.transaction.price.toStringAsFixed(2)}/g',
                      style: theme.textTheme.bodySmall?.copyWith(
                          // color: theme.hintColor,
                          ),
                    ),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss')
                          .format(item.transaction.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        // color: theme.hintColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                // 备注（如有）
                if (item.transaction.note != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '备注：${item.transaction.note}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),

            // 浮动在左上角的原/卖信息
            Positioned(
              right: 0,
              top: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.45,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '原始: '),
                          TextSpan(
                            text:
                                '${formatNumber(item.transaction.weight, maxIntegerDigits)}g',
                          ),
                        ],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        // color: theme.hintColor,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isReduced) ...[
                      const SizedBox(height: 4),
                      if ((item.transaction.weight - item.remainingWeight) >=
                          0.00005)
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: '卖出: '),
                              TextSpan(
                                text:
                                    '${formatNumber(item.transaction.weight - item.remainingWeight, maxIntegerDigits)}g',
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color.fromARGB(255, 255, 0, 0),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 统计行组件
  Widget _buildSummaryRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: valueStyle ?? const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 策略名称映射
  String _getStrategyName(InventoryStrategy strategy) {
    return const {
      InventoryStrategy.fifo: '先进先出 (FIFO)',
      InventoryStrategy.lifo: '后进先出 (LIFO)',
      InventoryStrategy.lowest: '低价先出 (CIFO)',
      InventoryStrategy.highest: '高价先出 (EIFO)',
      InventoryStrategy.average: '均摊卖出 (AO)',
    }[strategy]!;
  }
}
