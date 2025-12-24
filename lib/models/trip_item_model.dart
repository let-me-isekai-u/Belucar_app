/// Dùng cho:
///API 14: Chuyến đang diễn ra
///API 15: Lịch sử chuyến đi

class TripItemModel {
  final int rideId;
  final String code;
  final DateTime createdAt;
  final String fromProvince;
  final String fromAddress;
  final String toProvince;
  final String toAddress;
  final double price;
  final int status;

  TripItemModel({
    required this.rideId,
    required this.code,
    required this.createdAt,
    required this.fromProvince,
    required this.fromAddress,
    required this.toProvince,
    required this.toAddress,
    required this.price,
    required this.status,
  });

  factory TripItemModel.fromJson(Map<String, dynamic> json) {
    return TripItemModel(
      rideId: json['rideId'],
      code: json['code'],
      createdAt: DateTime.parse(json['createdAt']),
      fromProvince: json['fromProvince'],
      fromAddress: json['fromAddress'],
      toProvince: json['toProvince'],
      toAddress: json['toAddress'],
      price: (json['price'] as num).toDouble(),
      status: json['status'],
    );
  }
}
