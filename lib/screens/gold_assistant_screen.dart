import 'package:bill_app/models/gold_transaction.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bill_app/models/ledger.dart';
import 'package:bill_app/widgets/inventory_list.dart';
import 'package:bill_app/widgets/transaction_list.dart';
import 'package:provider/provider.dart';
import 'package:bill_app/providers/theme_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:bill_app/providers/transaction_provider.dart';
import 'dart:convert'; // 添加json编码支持
import 'dart:io'; // 添加File支持
import 'package:path_provider/path_provider.dart'; // 添加路径支持
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform, Process;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert' show utf8, jsonEncode;

class _SwipeConfiguration {
  static const double fastSwipeVelocityThreshold = 700.0;
  static const double minSwipeDistance = 2.0;
  static const double maxReboundDistance = 10.0;
  static const double endVelocityThreshold = 300.0;
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

  // 新增导出方法
  Future<void> _exportAllData(BuildContext context) async {
    try {
      final ledgerBox = Hive.box<Ledger>('ledgers');
      final transactionBox = Hive.box<GoldTransaction>('transactions');

      // 准备导出数据
      final exportData = {
        'ledgers': ledgerBox.values
            .map((ledger) => {
                  'ledger': ledger.toJson(),
                  'transactions': transactionBox.values
                      .where((t) => t.ledgerId == ledger.id)
                      .map((t) => t.toJson())
                      .toList(),
                })
            .toList(),
        'exportedAt': DateTime.now().toIso8601String(),
      };

      // 转换为字节数据
      final String jsonStr = jsonEncode(exportData);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));
      String savedPath = ''; // 明确定义路径变量

      // 平台特定处理
      if (Platform.isAndroid || Platform.isIOS) {
        final String? result = await FilePicker.platform.saveFile(
          dialogTitle: '保存导出文件',
          fileName: 'goldpod_${DateTime.now().millisecondsSinceEpoch}.json',
          bytes: bytes,
          allowedExtensions: ['json'],
        );
        if (result == null) {
          if (mounted)
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('导出已取消')));
          return;
        }
        savedPath = result;
      } else {
        final String? selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: '选择导出位置',
          fileName: 'gold_export_${DateTime.now().millisecondsSinceEpoch}.json',
          allowedExtensions: ['json'],
        );
        if (selectedPath == null) {
          if (mounted)
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('导出已取消')));
          return;
        }
        await File(selectedPath).writeAsBytes(bytes);
        savedPath = selectedPath;
      }

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('导出成功'),
          action: SnackBarAction(
            label: '打开目录',
            onPressed: () => _openFileDirectory(savedPath), // 使用明确定义的路径
          ),
        ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败: ${e.toString()}')));
    }
  }

// 打开文件所在目录（跨平台实现）
  void _openFileDirectory(String path) async {
    final String parentDir = path.replaceAll(RegExp(r'[^/]+$'), '');

    try {
      // 方法1：使用 url_launcher（适用于所有平台）
      final uri = Uri.directory(parentDir);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }

      // 方法2：平台特定实现（备用方案）
      if (Platform.isAndroid || Platform.isIOS) {
        // 移动端使用文件选择器（需要用户交互）
        final String? selectedDir = await FilePicker.platform.getDirectoryPath(
          initialDirectory: parentDir,
        );
        if (selectedDir != null) {
          print("用户选择的目录: $selectedDir");
        }
      } else if (Platform.isWindows) {
        await Process.run('explorer', [parentDir.replaceAll('/', '\\')]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [parentDir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [parentDir]);
      }
    } catch (e) {
      print('打开目录失败: $e');
      // 可以在这里添加错误处理，比如显示SnackBar
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
    try {
      // 1. 获取关联的账目Box
      final transactionsBox = Hive.box<GoldTransaction>('transactions');

      // 2. 找出所有关联账目
      final relatedTransactions =
          transactionsBox.values.where((t) => t.ledgerId == ledgerId).toList();

      // 3. 级联删除账目
      await transactionsBox.deleteAll(relatedTransactions.map((t) => t.id));

      // 4. 最后删除账本本身
      await _ledgerBox.delete(ledgerId);

      // 5. 确保Box仍然打开（不要关闭它）
      if (!transactionsBox.isOpen) {
        await Hive.openBox<GoldTransaction>('transactions');
      }
    } catch (e) {
      debugPrint('Error deleting ledger: $e');
      // 如果出错，尝试重新打开Box
      await Hive.openBox<GoldTransaction>('transactions');
      await Hive.openBox<Ledger>('ledgers');
    }
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
        actions: [
          IconButton(
            icon: Icon(Icons.import_export, color: primaryColor),
            onPressed: () => _showExportMenu(context),
          ),
        ],
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

  void _showExportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.save_alt, color: Theme.of(context).primaryColor),
              title: const Text('导出所有账本数据'),
              onTap: () {
                Navigator.pop(context);
                _exportAllData(context);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.cancel, color: Theme.of(context).primaryColor),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        );
      },
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
