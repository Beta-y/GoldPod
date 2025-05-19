import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: _buildInventoryContent(context),
    );
  }

  Widget _buildInventoryContent(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final inventory = provider.calculateInventory(); // 自动响应策略变化

    return Column(
      children: [
        // 策略选择器（吸顶效果）
        _buildStrategySelector(context, provider),
        const SizedBox(height: 8),

        // 统计卡片
        _buildSummaryCard(context, inventory),
        const SizedBox(height: 8),

        // 仓位列表（自适应高度）
        Expanded(
          child:
              _buildInventoryList(context, inventory, provider.currentStrategy),
        ),
      ],
    );
  }

  // 策略选择器（带视觉反馈）
  Widget _buildStrategySelector(
      BuildContext context, TransactionProvider provider) {
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
      BuildContext context, List<InventoryItem> inventory) {
    final (totalWeight, avgPrice, totalValue) =
        _calculateInventoryTotals(inventory);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('总持仓重量', '${totalWeight.toStringAsFixed(4)}g'),
            const Divider(height: 20),
            _buildSummaryRow('平均成本价', '${avgPrice.toStringAsFixed(2)}元/g'),
            const Divider(height: 20),
            _buildSummaryRow(
              '当前总价值',
              '¥${totalValue.toStringAsFixed(2)}',
              valueStyle: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 18,
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

    final totalWeight = inventory.fold<double>(
      0.0,
      (sum, item) => sum + item.remainingWeight,
    );

    final totalValue = inventory.fold<double>(
      0.0,
      (sum, item) => sum + (item.remainingWeight * item.transaction.price),
    );

    final avgPrice = totalWeight > 0 ? totalValue / totalWeight : 0.0;
    return (totalWeight, avgPrice, totalValue); // 明确所有值为double
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 重量行 - 主信息区
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end, // 修改为底部对齐
              children: [
                // 当前重量
                Text(
                  '${item.remainingWeight.toStringAsFixed(4)}g',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // 右上角组合信息（固定高度容器）
                SizedBox(
                  height: 40, // 固定高度确保布局稳定
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 原始重量
                      Text(
                        '原始 ${item.transaction.weight.toStringAsFixed(4)}g',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      if (isReduced) ...[
                        const SizedBox(height: 4),
                        Text(
                          '卖出 ${(item.transaction.weight - item.remainingWeight).toStringAsFixed(4)}g',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red[400],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 辅助信息行（固定位置）
            Row(
              children: [
                _buildDetailChip(
                  context,
                  '单价',
                  '${item.transaction.price.toStringAsFixed(2)}元',
                ),
                const SizedBox(width: 8),
                _buildDetailChip(
                  context,
                  '日期',
                  DateFormat('yyyy-MM-dd HH:mm:ss')
                      .format(item.transaction.date),
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
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 详情标签组件
  Widget _buildDetailChip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
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
