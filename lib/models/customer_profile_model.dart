class CustomerProfileModel {
  const CustomerProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.wallet,
    this.avatarUrl,
    this.referralCode,
  });

  final int id;
  final String fullName;
  final String email;
  final String phone;
  final double wallet;
  final String? avatarUrl;
  final String? referralCode;

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawWallet = json['wallet'];
    return CustomerProfileModel(
      id: rawId is int ? rawId : int.tryParse('$rawId') ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      wallet: rawWallet is num
          ? rawWallet.toDouble()
          : double.tryParse('$rawWallet') ?? 0,
      avatarUrl: json['avatarUrl']?.toString(),
      referralCode: json['referralCode']?.toString(),
    );
  }
}
