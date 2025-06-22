import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bill_app/providers/theme_provider.dart';
import 'package:bill_app/providers/transaction_provider.dart';
import 'package:bill_app/screens/home_screen.dart';
import 'package:bill_app/screens/gold_assistant_screen.dart';
import 'package:bill_app/screens/edit_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:bill_app/models/adapters/hive_adapters.dart';

// 添加Hive适配器导入
import 'package:bill_app/models/ledger.dart';
import 'package:bill_app/models/gold_transaction.dart';

/*
生成适配器:
dart run build_runner build

生成图标:
dart run flutter_launcher_icons:main

构建:
cd android
./gradlew clean
flutter clean
flutter pub get
cd ..
flutter run

模拟器:
emulator -list-avds
emulator -avd Pixel_4_API_36

真机:
adb devices
flutter run -d UMXDU20A20007337, 4CBDU17610005480

卸载:
adb uninstall com.example.bill_app

发布:
cd android
./gradlew clean
flutter clean
flutter pub get
cd ..
flutter build apk --release
*/

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive
  await Hive.initFlutter();

  // 注册适配器
  await HiveAdapters.registerAll();

  // 初始化安全存储和加密
  final (encryptionKey, encrypter) = await _initializeEncryption();

  // 打开加密的Hive盒子
  await _openEncryptedBoxes(encryptionKey);

  // 初始化SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..initialize(isDarkMode),
        ),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(encrypter: encrypter),
        ),
      ],
      child: const GoldTradingApp(),
    ),
  );
}

// 新增的加密初始化方法
Future<(String, encrypt.Encrypter)> _initializeEncryption() async {
  const secureStorage = FlutterSecureStorage();

  // 只需要处理加密密钥
  var encryptionKey = await secureStorage.read(key: 'encryption_key');
  if (encryptionKey == null) {
    final key = encrypt.Key.fromSecureRandom(32);
    encryptionKey = key.base64;
    await secureStorage.write(key: 'encryption_key', value: encryptionKey);
  }

  return (
    encryptionKey!,
    encrypt.Encrypter(encrypt.AES(encrypt.Key.fromBase64(encryptionKey)))
  );
}

// 安全的盒子打开方式
Future<void> _openEncryptedBoxes(String encryptionKey) async {
  final key = encrypt.Key.fromBase64(encryptionKey);

  // HiveAesCipher 不需要也不支持自定义 IV
  final cipher = HiveAesCipher(key.bytes);

  // 并行打开盒子
  await Future.wait([
    Hive.openBox<Ledger>('ledgers', encryptionCipher: cipher),
    Hive.openBox<GoldTransaction>('transactions', encryptionCipher: cipher)
  ]);

  // 安全迁移
  await _safeMigration();
}

// 安全的数据迁移
Future<void> _safeMigration() async {
  final box = Hive.box<GoldTransaction>('transactions');

  // 打印当前box的所有内容
  debugPrint('════════════════ 当前Box内容 ════════════════');
  debugPrint('总记录数: ${box.length}');
  debugPrint('所有键: ${box.keys.join(', ')}');

  for (final key in box.keys) {
    final transaction = box.get(key);
    debugPrint('──────────────────────────────────────');
    debugPrint('键: $key');
    debugPrint('ID: ${transaction?.id}');
    debugPrint('类型: ${transaction?.type == TransactionType.buy ? '买入' : '卖出'}');
    debugPrint('日期: ${transaction?.date}');
    debugPrint('重量: ${transaction?.weight}g');
    debugPrint('价格: ￥${transaction?.price}/g');
    debugPrint('金额: ￥${transaction?.amount}');
    debugPrint('账本ID: ${transaction?.ledgerId}');
    debugPrint('备注: ${transaction?.note ?? '无'}');
  }
  debugPrint('═════════════════════════════════════════');

  // 备份原始数据
  final backup = box.values.toList();

  try {
    if (box.isNotEmpty && box.values.first.amount == 0) {
      debugPrint('开始安全迁移...');

      // 创建临时盒子存放迁移数据
      final tempBox = await Hive.openBox<GoldTransaction>('temp_migration');

      for (final transaction in backup) {
        await tempBox.put(
            transaction.id,
            transaction.copyWith(
                amount: transaction.weight * transaction.price));
      }

      // 清空原盒子
      await box.clear();

      // 将数据移回
      for (final key in tempBox.keys) {
        final transaction = tempBox.get(key);
        if (transaction != null) {
          // 添加空值检查
          await box.put(key, transaction);
        } else {
          debugPrint('警告: 键 $key 对应的交易记录为null');
        }
      }

      await tempBox.close();
      await Hive.deleteBoxFromDisk('temp_migration');
    }
  } catch (e) {
    debugPrint('迁移失败，恢复备份: $e');
    await box.clear();
    for (final transaction in backup) {
      await box.put(transaction.id, transaction);
    }
  }
}

class GoldTradingApp extends StatefulWidget {
  const GoldTradingApp({super.key});

  @override
  State<GoldTradingApp> createState() => _GoldTradingAppState();
}

class _GoldTradingAppState extends State<GoldTradingApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 确保所有盒子关闭
    Hive.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 应用进入后台时强制写入
      Hive.box('transactions').flush();
      Hive.box('ledgers').flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: '金豆夹',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeProvider.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/assistant': (context) =>
            const GoldAssistantScreen(ledgerName: '默认账本', ledgerId: 'default'),
        '/edit': (context) => const EditScreen(ledgerId: 'default'),
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: Colors.black,
        secondary: const Color(0xFFD4AF37),
        surface: const Color(0xFFF5F5F5),
        background: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: Colors.black,
        secondary: const Color(0xFFFFD700),
        surface: const Color(0xFF121212),
        background: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
        color: const Color(0xFF1E1E1E),
      ),
    );
  }
}
