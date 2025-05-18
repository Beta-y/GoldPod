import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/gold_transaction.dart';
import '../providers/transaction_provider.dart';

class EditScreen extends StatefulWidget {
  final GoldTransaction? existingTransaction;
  const EditScreen({super.key, this.existingTransaction});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _formKey = GlobalKey<FormState>();
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
      _priceController.text = t.price.toString();
      _dateController.text = DateFormat('yyyy-MM-dd').format(t.date);
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

  Widget _buildWeightField(BuildContext context) {
    return TextFormField(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      cursorColor: Theme.of(context).colorScheme.onSurface,
      controller: _weightController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        floatingLabelStyle:
            TextStyle(color: Theme.of(context).colorScheme.onSurface),
        labelText: '重量 (克)',
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
        labelText: '价格 (元/克)',
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
              hintText: DateFormat('yyyy-MM-dd').format(DateTime.now()),
              border: const OutlineInputBorder(),
            ),
            readOnly: true,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _selectDate(context),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green, // 头部背景色
              onPrimary: Colors.white, // 头部文字颜色
              surface: Colors.grey[100]!, // 日历背景色
              onSurface: Colors.black87, // 日历文字颜色
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87, // "OK/CANCEL" 按钮颜色
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
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

    final transaction = GoldTransaction(
      id: widget.existingTransaction?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      date: _selectedDate,
      type: _transactionType,
      weight: double.parse(_weightController.text),
      price: double.parse(_priceController.text),
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    final provider = Provider.of<TransactionProvider>(context, listen: false);
    if (widget.existingTransaction != null) {
      provider.updateTransaction(transaction);
    } else {
      provider.addTransaction(transaction);
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _priceController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
