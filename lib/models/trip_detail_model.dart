/// Dùng cho:
/// API 16: Chi tiết chuyến đi

class TripDetailModel {
  final int id;
  final String code;
  final int type;
  final DateTime createdAt;

  final String fromProvince;
  final String fromAddress;

  final String toProvince;
  final String toAddress;

  final double price;
  final int status;

  final String? note;
  final DateTime pickupTime;

  final String? driverName;
  final String? avatar;
  final String? licenseNumber;
  final String? phoneNumber;
  final String paymentMethod;

  TripDetailModel({
    required this.id,
    required this.code,
    required this.type,
    required this.createdAt,
    required this.fromProvince,
    required this.fromAddress,
    required this.toProvince,
    required this.toAddress,
    required this.price,
    required this.status,
    this.note,
    required this.pickupTime,
    this.driverName,
    this.avatar,
    this.licenseNumber,
    this.phoneNumber,
    required this.paymentMethod,
  });

  factory TripDetailModel.fromJson(Map<String, dynamic> json) {
    return TripDetailModel(
      id: json['id'],
      code: json['code'],
      type: json['type'],
      createdAt: DateTime.parse(json['createdAt']),

      paymentMethod: json['paymentMethod'] as String,

      fromProvince: json['fromProvince'],
      fromAddress: json['fromAddress'],

      toProvince: json['toProvince'],
      toAddress: json['toAddress'],

      price: (json['price'] as num).toDouble(),
      status: json['status'],

      note: json['note'],
      pickupTime: DateTime.parse(json['pickupTime']),

      driverName: json['driverName'],
      avatar: json['avatar'],
      licenseNumber: json['licenseNumber'],
      phoneNumber: json['phoneNumber'],

    );
  }
}