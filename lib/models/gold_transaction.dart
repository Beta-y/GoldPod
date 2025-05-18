import 'package:flutter/foundation.dart';

@immutable
class GoldTransaction {
  final String id;
  final DateTime date;
  final TransactionType type;
  final double weight;
  final double price;
  final String? note;

  const GoldTransaction({
    required this.id,
    required this.date,
    required this.type,
    required this.weight,
    required this.price,
    this.note,
  });

  GoldTransaction copyWith({
    String? id,
    DateTime? date,
    TransactionType? type,
    double? weight,
    double? price,
    String? note,
  }) {
    return GoldTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      weight: weight ?? this.weight,
      price: price ?? this.price,
      note: note ?? this.note,
    );
  }
}

enum TransactionType { buy, sell }
