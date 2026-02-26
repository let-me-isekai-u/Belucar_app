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

  /// SỐ LƯỢNG (NEW)
  final int quantity;

  /// GIÁ
  final double price; // base price (giữ cho UI cũ)
  final double finalPrice; // giá thanh toán
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
    required this.quantity, // NEW
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
    // quantity có thể BE chưa trả về ở một số case => default 1 để khỏi crash
    final int parsedQuantity = (json['quantity'] as num?)?.toInt() ?? 1;

    return TripDetailModel(
      id: (json['id'] as num).toInt(),
      code: (json['code'] ?? '').toString(),
      type: (json['type'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt']),

      fromProvince: (json['fromProvince'] ?? '').toString(),
      fromDistrict: (json['fromDistrict'] ?? '').toString(),
      fromAddress: (json['fromAddress'] ?? '').toString(),
      toProvince: (json['toProvince'] ?? '').toString(),
      toDistrict: (json['toDistrict'] ?? '').toString(),
      toAddress: (json['toAddress'] ?? '').toString(),

      quantity: parsedQuantity, // NEW

      price: (json['price'] as num).toDouble(),
      finalPrice: (json['finnalPrice'] as num).toDouble(), // backend sai chính tả
      discount: (json['discount'] as num).toDouble(),
      surcharge: (json['surcharge'] as num).toDouble(),

      status: (json['status'] as num).toInt(),
      note: json['note']?.toString(),
      pickupTime: DateTime.parse(json['pickupTime']),

      driverName: json['driverName']?.toString(),
      avatar: json['avatar']?.toString(),
      licenseNumber: json['licenseNumber']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
    );
  }
}