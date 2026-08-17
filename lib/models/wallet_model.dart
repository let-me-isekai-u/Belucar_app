class WalletTransactionModel {
  const WalletTransactionModel({
    required this.type,
    required this.amount,
    required this.createdDate,
  });

  final String type;
  final num amount;
  final String? createdDate;

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    return WalletTransactionModel(
      type: json['type']?.toString() ?? 'Giao dịch',
      amount: rawAmount is num ? rawAmount : num.tryParse('$rawAmount') ?? 0,
      createdDate: json['createdDate']?.toString(),
    );
  }
}

class WalletOverviewModel {
  const WalletOverviewModel({
    required this.currentBalance,
    required this.transactions,
  });

  final num currentBalance;
  final List<WalletTransactionModel> transactions;
}
