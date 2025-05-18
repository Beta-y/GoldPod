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
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run

adb uninstall com.example.bill_app
*/

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive
  await Hive.initFlutter();

  // 初始化安全存储和加密
  const secureStorage = FlutterSecureStorage();
  final (encryptionKey, encrypter) = await _initializeEncryption(secureStorage);

  // 注册适配器
  await HiveAdapters.registerAll();

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
          create: (_) =>
              TransactionProvider(encrypter: encrypter), // 使用正确的encrypter
        ),
      ],
      child: const GoldTradingApp(),
    ),
  );
}

// 新增的加密初始化方法
Future<(String, encrypt.Encrypter)> _initializeEncryption(
    FlutterSecureStorage secureStorage) async {
  var encryptionKey = await secureStorage.read(key: 'encryption_key');
  if (encryptionKey == null) {
    final key = encrypt.Key.fromSecureRandom(32);
    encryptionKey = key.base64;
    await secureStorage.write(key: 'encryption_key', value: encryptionKey);
  }
  final key = encrypt.Key.fromBase64(encryptionKey!);
  return (encryptionKey, encrypt.Encrypter(encrypt.AES(key)));
}

// 新增的打开加密Box方法
Future<void> _openEncryptedBoxes(String encryptionKey) async {
  final key = encrypt.Key.fromBase64(encryptionKey);
  await Hive.openBox<Ledger>('ledgers',
      encryptionCipher: HiveAesCipher(key.bytes));
  final box = await Hive.openBox<GoldTransaction>('transactions',
      encryptionCipher: HiveAesCipher(key.bytes));
  debugPrint('当前记录数: ${box.length}');
  debugPrint('当前记录数: ${box.length}');
  debugPrint('所有键: ${box.keys}');
}

class GoldTradingApp extends StatelessWidget {
  const GoldTradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: '黄金交易助手',
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
