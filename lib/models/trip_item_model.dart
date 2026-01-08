/// Dùng cho:
///API 14: Chuyến đang diễn ra
///API 15: Lịch sử chuyến đi

class TripItemModel {
  final int rideId;
  final String code;
  final DateTime createdAt;
  final String fromProvince;
  final String fromDistrict;
  final String fromAddress;
  final String toProvince;
  final String toDistrict;
  final String toAddress;
  final double price;
  final int status;

  TripItemModel({
    required this.rideId,
    required this.code,
    required this.createdAt,
    required this.fromProvince,
    required this.fromDistrict,
    required this.fromAddress,
    required this.toProvince,
    required this.toDistrict,
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
      fromDistrict: json['fromDistrict'],
      fromAddress: json['fromAddress'],
      toProvince: json['toProvince'],
      toDistrict: json['toDistrict'],
      toAddress: json['toAddress'],
      price: (json['price'] as num).toDouble(),
      status: json['status'],
    );
  }
}
