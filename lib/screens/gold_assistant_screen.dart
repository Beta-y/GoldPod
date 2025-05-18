import 'package:bill_app/models/gold_transaction.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bill_app/models/ledger.dart';
import 'package:bill_app/widgets/inventory_list.dart';
import 'package:bill_app/widgets/transaction_list.dart';
import 'package:provider/provider.dart';
import 'package:bill_app/providers/theme_provider.dart';

class _SwipeConfiguration {
  static const double fastSwipeVelocityThreshold = 1000.0;
  static const double minSwipeDistance = 4.0;
  static const double maxReboundDistance = 15.0;
  static const double endVelocityThreshold = 800.0;
}

class LedgerManagementScreen extends StatefulWidget {
  const LedgerManagementScreen({super.key});

  @override
  State<LedgerManagementScreen> createState() => _LedgerManagementScreenState();
}

class _LedgerManagementScreenState extends State<LedgerManagementScreen> {
  late Box<Ledger> _ledgerBox;
  final ScrollController _scrollController = ScrollController();
  int? _swipedIndex;

  double _dragDistance = 0.0;
  bool _isSwiping = false;
  DateTime _lastDragTime = DateTime.now();
  Offset _lastDragPosition = Offset.zero;
  double _currentVelocity = 0.0;

  @override
  void initState() {
    super.initState();
    _ledgerBox = Hive.box<Ledger>('ledgers');
    // 如果账本为空，添加一个默认账本
    if (_ledgerBox.isEmpty) {
      final defaultExists =
          _ledgerBox.values.any((ledger) => ledger.name == '默认账本');
      if (!defaultExists) {
        final uniqueKey = DateTime.now().millisecondsSinceEpoch.toString();
        _ledgerBox.put(
          uniqueKey,
          Ledger(
            id: uniqueKey,
            name: '默认账本',
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  void _createNewLedger() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController nameController = TextEditingController();
        return AlertDialog(
          title: const Text('创建新账本'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '账本名称',
              hintText: '请输入账本名称',
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.surface,
                backgroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final uniqueKey =
                      DateTime.now().millisecondsSinceEpoch.toString();
                  _ledgerBox.put(
                    uniqueKey,
                    Ledger(
                      id: uniqueKey,
                      name: nameController.text,
                      createdAt: DateTime.now(),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  void _editLedger(Ledger ledger) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController nameController =
            TextEditingController(text: ledger.name);
        return AlertDialog(
          title: const Text('编辑账本'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '账本名称',
              hintText: '请输入新的账本名称',
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.surface,
                backgroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  ledger.name = nameController.text;
                  ledger.save();
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _deleteLedger(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('将同时删除该账本下的所有账目'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.surface,
              backgroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () async {
              debugPrint('Deleting ledger with id: $id'); // 添加日志
              await _deleteLedgerWithTransactions(id); // 使用新方法
              debugPrint(
                  'After deletion, box contains: ${_ledgerBox.keys.toList()}'); // 验证
              _swipedIndex = null;
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLedgerWithTransactions(String ledgerId) async {
    // 1. 获取关联的账目Box
    final transactionsBox = await Hive.openBox<GoldTransaction>('transactions');

    // 2. 找出所有关联账目
    final relatedTransactions =
        transactionsBox.values.where((t) => t.ledgerId == ledgerId).toList();

    // 3. 级联删除账目
    await transactionsBox.deleteAll(relatedTransactions.map((t) => t.id));

    // 4. 最后删除账本本身
    await _ledgerBox.delete(ledgerId);

    // 5. 关闭Box（可选）
    await transactionsBox.close();
  }

  void _togglePin(Ledger ledger) {
    setState(() {
      ledger.isPinned = !ledger.isPinned;
      _swipedIndex = null;
    });
    ledger.save(); // 使用 HiveObject 自带的 save()
  }

  void _handleSwipe(int index) {
    setState(() {
      if (_swipedIndex == index) {
        _swipedIndex = null;
      } else {
        _swipedIndex = index;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryColor =
        isDarkMode ? const Color(0xFFFFD700) : const Color(0xFFD4AF37);
    const errorColor = Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易管理'),
        backgroundColor: Colors.black,
        foregroundColor: primaryColor,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: _createNewLedger,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: ValueListenableBuilder<Box<Ledger>>(
        valueListenable: _ledgerBox.listenable(),
        builder: (context, box, _) {
          final ledgers = box.values.toList();
          ledgers.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });

          return ledgers.isEmpty
              ? Center(
                  child: Text(
                    '暂无账本，点击右下角+号创建',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: ledgers.length,
                  itemExtent: 80,
                  itemBuilder: (context, index) {
                    final ledger = ledgers[index];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (details) {
                        _isSwiping = true;
                        _dragDistance = 0.0;
                        _lastDragTime = DateTime.now();
                        _lastDragPosition = details.globalPosition;
                      },
                      onHorizontalDragUpdate: (details) {
                        final now = DateTime.now();
                        final elapsed =
                            now.difference(_lastDragTime).inMilliseconds;

                        if (elapsed > 0) {
                          final distance =
                              (details.globalPosition - _lastDragPosition)
                                  .distance;
                          _currentVelocity = distance / elapsed * 1000;
                          _lastDragTime = now;
                          _lastDragPosition = details.globalPosition;
                        }

                        _dragDistance += details.delta.dx.abs();

                        final isFastSwipe = _currentVelocity >
                            _SwipeConfiguration.fastSwipeVelocityThreshold;
                        final threshold = isFastSwipe
                            ? _SwipeConfiguration.minSwipeDistance / 2
                            : _SwipeConfiguration.minSwipeDistance;

                        if (_dragDistance > threshold) {
                          if (details.delta.dx < -threshold) {
                            _handleSwipe(index);
                          } else if (details.delta.dx > threshold &&
                              _swipedIndex == index) {
                            _handleSwipe(index);
                          }
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        final endVelocity =
                            details.velocity.pixelsPerSecond.dx.abs();
                        _isSwiping = false;

                        final shouldRebound = endVelocity <
                                _SwipeConfiguration.endVelocityThreshold &&
                            _dragDistance <
                                _SwipeConfiguration.maxReboundDistance &&
                            _swipedIndex == index;

                        if (shouldRebound) {
                          _handleSwipe(index);
                        }
                      },
                      onTap: () {
                        if (!_isSwiping && _swipedIndex == index) {
                          _handleSwipe(index);
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 0),
                              child: Card(
                                color: isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.white,
                                child: ListTile(
                                  leading: Icon(Icons.account_balance_wallet,
                                      color: primaryColor),
                                  title: Text(ledger.name),
                                  subtitle: Text(
                                    '创建于: ${ledger.createdAt.toString().split(' ')[0]}',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  trailing: _swipedIndex == index
                                      ? null
                                      : (ledger.isPinned
                                          ? Transform.translate(
                                              offset:
                                                  const Offset(0, 0), // X/Y轴微调
                                              child: Icon(
                                                Icons.push_pin,
                                                color: primaryColor,
                                                size: 24, // 缩小图标
                                              ),
                                            )
                                          : null),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GoldAssistantScreen(
                                          ledgerId: ledger.id,
                                          ledgerName: ledger.name),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 16,
                            top: 8,
                            bottom: 8,
                            child: IgnorePointer(
                              ignoring: _swipedIndex != index,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _swipedIndex == index ? 1.0 : 0.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: null,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildActionButton(
                                        icon: Icons.push_pin,
                                        color: primaryColor,
                                        onTap: () => _togglePin(ledger),
                                        isActive: ledger.isPinned,
                                        size: 40,
                                      ),
                                      const SizedBox(width: 5),
                                      _buildActionButton(
                                        icon: Icons.edit,
                                        color: primaryColor,
                                        onTap: () {
                                          _handleSwipe(index);
                                          _editLedger(ledger);
                                        },
                                        size: 40,
                                      ),
                                      const SizedBox(width: 5),
                                      _buildActionButton(
                                        icon: Icons.delete,
                                        color: errorColor,
                                        onTap: () {
                                          _handleSwipe(index);
                                          _deleteLedger(ledger.id);
                                        },
                                        size: 40,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
    double size = 40,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Icon(
          icon,
          color: isActive ? color : color.withValues(alpha: 0.7),
          size: 24,
        ),
      ),
    );
  }
}

class GoldAssistantScreen extends StatelessWidget {
  final String ledgerId;
  final String ledgerName; // 新增参数

  const GoldAssistantScreen({
    super.key,
    required this.ledgerId,
    required this.ledgerName, // 必传参数
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryColor =
        isDarkMode ? const Color(0xFFFFD700) : const Color(0xFFD4AF37);
    return Provider.value(
      value: ledgerId,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(ledgerName),
            backgroundColor: Colors.black,
            foregroundColor: primaryColor,
            bottom: TabBar(
              tabs: const [
                Tab(
                  child: Text(
                    '账目',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
                Tab(
                  child: Text(
                    '仓位',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              indicatorColor: Theme.of(context).colorScheme.secondary,
              labelColor: Theme.of(context).textTheme.bodyLarge?.color,
              unselectedLabelColor:
                  Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          body: const TabBarView(
            children: [TransactionListScreen(), InventoryScreen()],
          ),
        ),
      ),
    );
  }
}
