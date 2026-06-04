class ChatRideMetaModel {
  final int rideId;
  final String code;
  final int status;
  final int type;
  final int? tripId;
  final int? fromDistrictId;
  final String? fromDistrictName;
  final int? toDistrictId;
  final String? toDistrictName;
  final String fromAddress;
  final String toAddress;
  final String customerPhone;
  final DateTime? pickupTime;
  final double basePrice;
  final double surcharge;
  final double discount;
  final double finalPrice;
  final int paymentMethod;
  final String paymentMethodText;
  final int quantity;
  final String? note;

  ChatRideMetaModel({
    required this.rideId,
    required this.code,
    required this.status,
    required this.type,
    required this.tripId,
    required this.fromDistrictId,
    required this.fromDistrictName,
    required this.toDistrictId,
    required this.toDistrictName,
    required this.fromAddress,
    required this.toAddress,
    required this.customerPhone,
    required this.pickupTime,
    required this.basePrice,
    required this.surcharge,
    required this.discount,
    required this.finalPrice,
    required this.paymentMethod,
    required this.paymentMethodText,
    required this.quantity,
    required this.note,
  });

  factory ChatRideMetaModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    return ChatRideMetaModel(
      rideId: parseNullableInt(json['rideId']) ?? 0,
      code: json['code']?.toString() ?? '',
      status: parseNullableInt(json['status']) ?? 0,
      type: parseNullableInt(json['type']) ?? 0,
      tripId: parseNullableInt(json['tripId']),
      fromDistrictId: parseNullableInt(json['fromDistrictId']),
      fromDistrictName: json['fromDistrictName']?.toString(),
      toDistrictId: parseNullableInt(json['toDistrictId']),
      toDistrictName: json['toDistrictName']?.toString(),
      fromAddress: json['fromAddress']?.toString() ?? '',
      toAddress: json['toAddress']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      pickupTime: json['pickupTime'] == null
          ? null
          : DateTime.tryParse(json['pickupTime'].toString()),
      basePrice: parseDouble(json['basePrice']),
      surcharge: parseDouble(json['surcharge']),
      discount: parseDouble(json['discount']),
      finalPrice: parseDouble(json['finalPrice']),
      paymentMethod: parseNullableInt(json['paymentMethod']) ?? 0,
      paymentMethodText: json['paymentMethodText']?.toString() ?? '',
      quantity: parseNullableInt(json['quantity']) ?? 0,
      note: json['note']?.toString(),
    );
  }
}