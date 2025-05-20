import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/gold_transaction.dart';
import '../providers/transaction_provider.dart';
import '../screens/edit_screen.dart';
import 'package:bill_app/providers/theme_provider.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionProvider>().transactions;
    final transactionProvider = context.read<TransactionProvider>();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryColor =
        isDarkMode ? const Color(0xFFFFD700) : const Color(0xFFD4AF37);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () {
          final ledgerId = Provider.of<String>(context, listen: false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditScreen(ledgerId: ledgerId),
            ),
          );
        },
      ),
      body: transactions.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '暂无交易记录',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (ctx, index) {
                final t = transactions[index];
                return Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("确认删除"),
                          content: const Text("您确定要删除这条交易记录吗？"),
                          actions: [
                            TextButton(
                              child: const Text("取消"),
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                            TextButton(
                              child: const Text("删除",
                                  style: TextStyle(color: Colors.red)),
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) {
                    transactionProvider.deleteTransaction(t.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '已删除${t.type == TransactionType.buy ? '买入' : '卖出'}记录'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: Icon(
                      t.type == TransactionType.buy
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: t.type == TransactionType.buy
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${t.type == TransactionType.buy ? '买入' : '卖出'} ${NumberFormat("#,##0.0000").format(t.weight)}g',
                              style: TextStyle(
                                fontSize: 16, // 最大字体
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '￥${NumberFormat("#,##0.00").format(t.amount)}',
                              style: TextStyle(
                                fontSize: 14, // 中等字体
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '￥${NumberFormat("#,##0.00").format(t.price)}/g',
                              style: TextStyle(
                                fontSize: 12, // 最小字体
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm:ss').format(t.date),
                              style: TextStyle(
                                fontSize: 12, // 最小字体
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        if (t.note != null)
                          Text(
                            '备注: ${t.note}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditScreen(
                            ledgerId: t.ledgerId, existingTransaction: t),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
