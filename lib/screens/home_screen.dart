import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bill_app/providers/theme_provider.dart';
import 'package:bill_app/screens/gold_assistant_screen.dart';
import 'package:package_info_plus/package_info_plus.dart'; // 新增包
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  // 改为StatefulWidget
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _version = ''; // 版本号

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v${packageInfo.version}'; // 格式化为v1.0.0
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '金豆夹',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: isDarkMode ? const Color(0xFFFFD700) : Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: isDarkMode ? const Color(0xFFFFD700) : Colors.white,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icon/gold_pod.svg',
              width: 72, // 直接指定尺寸
              height: 72,
              colorFilter: ColorFilter.mode(
                isDarkMode ? const Color(0xFFFFD700) : const Color(0xFFD4AF37),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '金豆夹',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LedgerManagementScreen()),
              ),
              child: const Text(
                '进入交易管理',
                style: TextStyle(fontSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                '极简黄金交易账目管理工具',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 60,
        padding: EdgeInsets.zero, // 清除默认padding
        color: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _version.isNotEmpty ? _version : '加载版本中...',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '© 2025 金豆夹 by Beta-y',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
