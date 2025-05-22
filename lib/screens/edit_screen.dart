import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/gold_transaction.dart';
import '../providers/transaction_provider.dart';

class EditScreen extends StatefulWidget {
  final String ledgerId;
  final GoldTransaction? existingTransaction;
  const EditScreen(
      {super.key, required this.ledgerId, this.existingTransaction});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(); // 新增：金额输入
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _dateController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TransactionType _transactionType = TransactionType.buy;

  @override
  void initState() {
    super.initState();
    if (widget.existingTransaction != null) {
      final t = widget.existingTransaction!;
      _weightController.text = t.weight.toString();
      _amountController.text = t.amount.toString(); // 初始化金额
      _priceController.text = t.price.toString();
      _dateController.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(t.date);
      _noteController.text = t.note ?? '';
      _selectedDate = t.date;
      _transactionType = t.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTransaction == null ? '新增交易' : '编辑交易'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTypeDropdown(context),
              const SizedBox(height: 20),
              // 根据交易类型显示不同输入字段
              if (_transactionType == TransactionType.buy)
                _buildAmountField(context),
              if (_transactionType == TransactionType.sell)
                _buildWeightField(context),
              const SizedBox(height: 20),
              _buildPriceField(context),
              const SizedBox(height: 20),
              _buildNoteField(context),
              const SizedBox(height: 20),
              _buildDatePicker(context),
              const SizedBox(height: 30),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown(BuildContext context) {
    return DropdownButtonFormField<TransactionType>(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      value: _transactionType,
      items: TransactionType.values.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type == TransactionType.buy ? '买入' : '卖出'),
        );
      }).toList(),
      onChanged: (value) => setState(() => _transactionType = value!),
      decoration: InputDecoration(
        floatingLabelStyle:
            TextStyle(color: Theme.of(context).colorScheme.onSurface),
        labelText: '交易类型',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildAmountField(BuildContext context) {
    return TextFormField(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      cursorColor: Theme.of(context).colorScheme.onSurface,
      controller: _amountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        floatingLabelStyle:
            TextStyle(color: Theme.of(context).colorScheme.onSurface),
        labelText: '总额 (元)',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入总额';
        final numValue = double.tryParse(value);
        if (numValue == null || numValue <= 0) return '请输入有效总额';
        return null;
      },
    );
  }

  Widget _buildWeightField(BuildContext context) {
    return TextFormField(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      cursorColor: Theme.of(context).colorScheme.onSurface,
      controller: _weightController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        floatingLabelStyle:
            TextStyle(color: Theme.of(context).colorScheme.onSurface),
        labelText: '重量 (g)',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入重量';
        final numValue = double.tryParse(value);
        if (numValue == null || numValue <= 0) return '请输入有效重量';
        return null;
      },
    );
  }

  Widget _buildPriceField(BuildContext context) {
    return TextFormField(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      cursorColor: Theme.of(context).colorScheme.onSurface,
      controller: _priceController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        floatingLabelStyle:
            TextStyle(color: Theme.of(context).colorScheme.onSurface),
        labelText: '价格 (元/g)',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入价格';
        final numValue = double.tryParse(value);
        if (numValue == null || numValue <= 0) return '请输入有效价格';
        return null;
      },
    );
  }

  Widget _buildNoteField(BuildContext context) {
    return TextFormField(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      cursorColor: Theme.of(context).colorScheme.onSurface,
      controller: _noteController,
      decoration: InputDecoration(
        floatingLabelStyle:
            TextStyle(color: Theme.of(context).colorScheme.onSurface),
        labelText: '备注 (可选)',
        border: const OutlineInputBorder(),
      ),
      maxLines: 2,
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            cursorColor: Theme.of(context).colorScheme.onSurface,
            controller: _dateController,
            decoration: InputDecoration(
              floatingLabelStyle:
                  TextStyle(color: Theme.of(context).colorScheme.onSurface),
              labelText: '交易日期',
              hintText:
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
              border: const OutlineInputBorder(),
            ),
            readOnly: true,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _selectDateTime(context),
        ),
      ],
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    // 在异步操作前检查 widget 是否已卸载
    if (!mounted) return;

    // 选择日期
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        // 在构建弹窗时检查 widget 是否已卸载
        if (!mounted) return const SizedBox.shrink(); // 返回一个占位 Widget
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    // 如果 widget 已卸载或用户未选择日期，直接返回
    if (!mounted || pickedDate == null) return;

    // 选择时间
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (context, child) {
        // 同样在构建时间选择器时检查
        if (!mounted) return const SizedBox.shrink();
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    // 如果 widget 已卸载或用户未选择时间，直接返回
    if (!mounted || pickedTime == null) return;

    // 合并日期和时间
    final DateTime fullDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // 更新 UI（仅在 widget 未卸载时调用 setState）
    if (mounted) {
      setState(() {
        _selectedDate = fullDateTime;
        _dateController.text =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
      });
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor:
                Theme.of(context).colorScheme.onSurface, // 表面色作为文字颜色
            backgroundColor:
                Theme.of(context).colorScheme.surface, // 表面上的内容色作为背景
          ),
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.surface, // 表面色作为文字颜色
            backgroundColor:
                Theme.of(context).colorScheme.onSurface, // 表面上的内容色作为背景
          ),
          child: const Text('保存'),
          onPressed: () => _submitForm(context),
        ),
      ],
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState?.validate() != true) return;

    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final id = widget.existingTransaction?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();

    if (_transactionType == TransactionType.buy) {
      // 买入交易：使用金额和价格
      provider.addBuyTransaction(
        id: id,
        date: _selectedDate,
        amount: double.parse(_amountController.text),
        price: double.parse(_priceController.text),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        ledgerId: widget.ledgerId,
      );
    } else {
      // 卖出交易：使用重量和价格
      provider.addSellTransaction(
        id: id,
        date: _selectedDate,
        weight: double.parse(_weightController.text),
        price: double.parse(_priceController.text),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        ledgerId: widget.ledgerId,
      );
    }

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
