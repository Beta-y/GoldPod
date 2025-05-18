import 'package:flutter/material.dart';
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

class Ledger {
  String id;
  String name;
  DateTime createdAt;
  bool isPinned;

  Ledger({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isPinned = false,
  });
}

class LedgerManagementScreen extends StatefulWidget {
  const LedgerManagementScreen({super.key});

  @override
  State<LedgerManagementScreen> createState() => _LedgerManagementScreenState();
}

class _LedgerManagementScreenState extends State<LedgerManagementScreen> {
  final List<Ledger> _ledgers = [
    Ledger(id: '1', name: '默认账本', createdAt: DateTime.now()),
  ];
  final ScrollController _scrollController = ScrollController();
  int? _swipedIndex;

  double _dragDistance = 0.0;
  bool _isSwiping = false;
  DateTime _lastDragTime = DateTime.now();
  Offset _lastDragPosition = Offset.zero;
  double _currentVelocity = 0.0;

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
                foregroundColor:
                    Theme.of(context).colorScheme.onSurface, // 表面色作为文字颜色
                backgroundColor:
                    Theme.of(context).colorScheme.surface, // 表面上的内容色作为背景
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.surface, // 表面色作为文字颜色
                backgroundColor:
                    Theme.of(context).colorScheme.onSurface, // 表面上的内容色作为背景
              ),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    _ledgers.add(
                      Ledger(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        createdAt: DateTime.now(),
                      ),
                    );
                  });
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
                foregroundColor:
                    Theme.of(context).colorScheme.onSurface, // 表面色作为文字颜色
                backgroundColor:
                    Theme.of(context).colorScheme.surface, // 表面上的内容色作为背景
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.surface, // 表面色作为文字颜色
                backgroundColor:
                    Theme.of(context).colorScheme.onSurface, // 表面上的内容色作为背景
              ),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    ledger.name = nameController.text;
                  });
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
        content: const Text('确定要删除这个账本吗？'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.onSurface, // 表面色作为文字颜色
              backgroundColor:
                  Theme.of(context).colorScheme.surface, // 表面上的内容色作为背景
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.surface, // 表面色作为文字颜色
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface, // 表面上的内容色作为背景
            ),
            onPressed: () {
              setState(() {
                _ledgers.removeWhere((ledger) => ledger.id == id);
                _swipedIndex = null;
              });
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _togglePin(Ledger ledger) {
    setState(() {
      ledger.isPinned = !ledger.isPinned;
      // 将置顶的账本移动到列表顶部
      _ledgers.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        if (a.isPinned && b.isPinned) return 1;
        return 0;
      });
      _swipedIndex = null;
    });
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
      body: _ledgers.isEmpty
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
              itemCount: _ledgers.length,
              itemExtent: 80,
              itemBuilder: (context, index) {
                final ledger = _ledgers[index];
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
                          (details.globalPosition - _lastDragPosition).distance;
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
                      // 主卡片内容
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: Card(
                            color: isDarkMode ? Colors.grey[800] : Colors.white,
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
                              trailing: _swipedIndex == index // 关键修改：滑动时隐藏
                                  ? null
                                  : (ledger.isPinned
                                      ? Icon(Icons.push_pin,
                                          color: primaryColor)
                                      : null),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GoldAssistantScreen(
                                      ledgerName: ledger.name),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 右侧操作按钮（完全隐藏）
                      Positioned(
                        right: 16,
                        top: 8,
                        bottom: 8,
                        child: IgnorePointer(
                          // 新增：禁用按钮交互
                          ignoring: _swipedIndex != index, // 只有展开时才启用点击
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _swipedIndex == index ? 1.0 : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildActionButton(
                                    icon: Icons.push_pin,
                                    color: primaryColor,
                                    onTap: () => _togglePin(ledger),
                                    isActive: ledger.isPinned,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: Icons.edit,
                                    color: primaryColor,
                                    onTap: () {
                                      _handleSwipe(index);
                                      _editLedger(ledger);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: Icons.delete,
                                    color: errorColor,
                                    onTap: () {
                                      _handleSwipe(index);
                                      _deleteLedger(ledger.id);
                                    },
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
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(
          icon,
          color: isActive ? color : color.withOpacity(0.7),
          size: 24,
        ),
      ),
    );
  }
}

class GoldAssistantScreen extends StatelessWidget {
  final String ledgerName; // 新增参数

  const GoldAssistantScreen({
    super.key,
    required this.ledgerName, // 必传参数
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryColor =
        isDarkMode ? const Color(0xFFFFD700) : const Color(0xFFD4AF37);
    return DefaultTabController(
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
            unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        body: const TabBarView(
          children: [TransactionListScreen(), InventoryScreen()],
        ),
      ),
    );
  }
}
