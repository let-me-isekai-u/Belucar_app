class TripDetailModel {
  final int id;
  final String code;
  final int type;
  final DateTime createdAt;

  final String fromProvince;
  final String fromDistrict;
  final String fromAddress;

  final String toProvince;
  final String toDistrict;
  final String toAddress;

  /// GIÁ
  final double price;        // base price (giữ cho UI cũ)
  final double finalPrice;   // giá thanh toán
  final double discount;
  final double surcharge;

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
    required this.fromDistrict,
    required this.fromAddress,
    required this.toProvince,
    required this.toDistrict,
    required this.toAddress,
    required this.price,
    required this.finalPrice,
    required this.discount,
    required this.surcharge,
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

      fromProvince: json['fromProvince'],
      fromDistrict: json['fromDistrict'],
      fromAddress: json['fromAddress'],
      toProvince: json['toProvince'],
      toDistrict: json['toDistrict'],
      toAddress: json['toAddress'],

      price: (json['price'] as num).toDouble(),
      finalPrice: (json['finnalPrice'] as num).toDouble(), // backend sai chính tả
      discount: (json['discount'] as num).toDouble(),
      surcharge: (json['surcharge'] as num).toDouble(),

      status: json['status'],
      note: json['note'],
      pickupTime: DateTime.parse(json['pickupTime']),

      driverName: json['driverName'],
      avatar: json['avatar'],
      licenseNumber: json['licenseNumber'],
      phoneNumber: json['phoneNumber'],
      paymentMethod: json['paymentMethod'],
    );
  }
}
