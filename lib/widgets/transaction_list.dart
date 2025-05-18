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
    final transactions =
        context.watch<TransactionProvider>().ledgerTransactions;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryColor =
        isDarkMode ? const Color(0xFFFFD700) : const Color(0xFFD4AF37);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditScreen()),
        ),
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
                return ListTile(
                  leading: Icon(
                    t.type == TransactionType.buy
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: t.type == TransactionType.buy
                        ? Colors.green
                        : Colors.red,
                  ),
                  title: Text(
                    '${t.type == TransactionType.buy ? '买入' : '卖出'} ${t.weight}g',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('价格: ${t.price}元/克'),
                      if (t.note != null) Text('备注: ${t.note}'),
                    ],
                  ),
                  trailing: Text(DateFormat('MM-dd').format(t.date)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditScreen(existingTransaction: t),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
