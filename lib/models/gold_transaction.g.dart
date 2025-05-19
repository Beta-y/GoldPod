// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gold_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoldTransactionAdapter extends TypeAdapter<GoldTransaction> {
  @override
  final int typeId = 1;

  @override
  GoldTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoldTransaction(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      type: fields[2] as TransactionType,
      weight: fields[3] as double,
      price: fields[4] as double,
      amount: fields[7] as double,
      note: fields[5] as String?,
      ledgerId: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GoldTransaction obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.weight)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.ledgerId)
      ..writeByte(7)
      ..write(obj.amount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoldTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 2;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.buy;
      case 1:
        return TransactionType.sell;
      default:
        return TransactionType.buy;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.buy:
        writer.writeByte(0);
        break;
      case TransactionType.sell:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
