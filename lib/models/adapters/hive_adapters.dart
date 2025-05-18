// hive_adapters.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:bill_app/models/ledger.dart';
import 'package:bill_app/models/gold_transaction.dart';

/// Hive适配器集中注册中心
/// 使用说明：
/// 1. 在main.dart中调用 `await HiveAdapters.registerAll()`
/// 2. 确保所有模型文件已添加Hive注解
class HiveAdapters {
  /// 注册所有Hive类型适配器
  static Future<void> registerAll() async {
    try {
      // 注册模型适配器（自动生成的.g.dart中的类）
      _registerCoreAdapters();

      // 可选：注册自定义适配器（如果有）
      _registerCustomAdapters();

      print('✅ Hive适配器注册完成');
    } catch (e) {
      print('❌ Hive适配器注册失败: $e');
      rethrow;
    }
  }

  /// 注册核心模型适配器
  static void _registerCoreAdapters() {
    // 注意：这里的Adapter类来自各模型对应的.g.dart文件
    Hive.registerAdapter(LedgerAdapter()); // 来自ledger.g.dart
    Hive.registerAdapter(GoldTransactionAdapter()); // 来自gold_transaction.g.dart
    Hive.registerAdapter(TransactionTypeAdapter()); // 来自gold_transaction.g.dart

    // 添加更多模型适配器...
  }

  /// 注册自定义适配器（示例）
  static void _registerCustomAdapters() {
    // 示例：如果有自定义的复杂类型适配器
    // Hive.registerAdapter(CustomTypeAdapter());
  }

  /// 检查所有适配器是否已注册
  static void verifyRegisteredAdapters() {
    if (!Hive.isAdapterRegistered(LedgerAdapter().typeId)) {
      throw Exception('LedgerAdapter未注册');
    }
    if (!Hive.isAdapterRegistered(GoldTransactionAdapter().typeId)) {
      throw Exception('GoldTransactionAdapter未注册');
    }
    // 添加其他检查...
  }
}
