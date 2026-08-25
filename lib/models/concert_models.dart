import 'customer_profile_model.dart';

class ConcertCatalog {
  const ConcertCatalog({
    required this.eventId,
    required this.eventCode,
    required this.eventName,
    required this.venueName,
    required this.eventStartDate,
    required this.eventEndDate,
    required this.status,
    required this.routes,
    required this.vehicleTypes,
    required this.services,
    required this.fares,
  });

  factory ConcertCatalog.fromJson(Map<String, dynamic> json) {
    final routes = _objectList(json['routes'], ConcertRoute.fromJson)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final route in routes) {
      route.stops.sort((a, b) => a.sequence.compareTo(b.sequence));
    }
    return ConcertCatalog(
      eventId: _asInt(json['eventId']),
      eventCode: _asString(json['eventCode']),
      eventName: _asString(json['eventName']),
      venueName: _asString(json['venueName']),
      eventStartDate: _asDate(json['eventStartDate']),
      eventEndDate: _asDate(json['eventEndDate']),
      status: _asString(json['status']),
      routes: routes,
      vehicleTypes: _objectList(
        json['vehicleTypes'],
        ConcertVehicleType.fromJson,
      ),
      services: _objectList(json['services'], ConcertService.fromJson),
      fares: _objectList(json['fares'], ConcertFare.fromJson),
    );
  }

  final int eventId;
  final String eventCode;
  final String eventName;
  final String venueName;
  final DateTime? eventStartDate;
  final DateTime? eventEndDate;
  final String status;
  final List<ConcertRoute> routes;
  final List<ConcertVehicleType> vehicleTypes;
  final List<ConcertService> services;
  final List<ConcertFare> fares;

  bool get canBook => status == 'OPEN';

  List<ConcertService> get openServices {
    final result = services.where((item) => item.saleStatus == 'OPEN').toList();
    result.sort((a, b) {
      final dateComparison = _compareDates(a.serviceDate, b.serviceDate);
      if (dateComparison != 0) return dateComparison;
      return a.direction == b.direction
          ? a.name.compareTo(b.name)
          : a.direction == 'OUTBOUND'
          ? -1
          : 1;
    });
    return result;
  }

  ConcertFare? fareFor({
    required int serviceId,
    required int routeStopId,
    required int vehicleTypeId,
  }) {
    for (final fare in fares) {
      if (fare.serviceId == serviceId &&
          fare.routeStopId == routeStopId &&
          fare.vehicleTypeId == vehicleTypeId) {
        return fare;
      }
    }
    return null;
  }
}

class ConcertRoute {
  const ConcertRoute({
    required this.id,
    required this.code,
    required this.name,
    required this.sequence,
    required this.stops,
  });

  factory ConcertRoute.fromJson(Map<String, dynamic> json) => ConcertRoute(
    id: _asInt(json['id']),
    code: _asString(json['code']),
    name: _asString(json['name']),
    sequence: _asInt(json['sequence']),
    stops: _objectList(json['stops'], ConcertRouteStop.fromJson),
  );

  final int id;
  final String code;
  final String name;
  final int sequence;
  final List<ConcertRouteStop> stops;

  List<ConcertRouteStop> get selectableStops =>
      stops.where((stop) => stop.isSelectable).toList();
}

class ConcertRouteStop {
  const ConcertRouteStop({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.sequence,
    required this.isTerminal,
    required this.isSelectable,
  });

  factory ConcertRouteStop.fromJson(Map<String, dynamic> json) =>
      ConcertRouteStop(
        id: _asInt(json['id']),
        code: _asString(json['code']),
        name: _asString(json['name']),
        address: _asNullableString(json['address']),
        sequence: _asInt(json['sequence']),
        isTerminal: json['isTerminal'] == true,
        isSelectable: json['isSelectable'] == true,
      );

  final int id;
  final String code;
  final String name;
  final String? address;
  final int sequence;
  final bool isTerminal;
  final bool isSelectable;
}

class ConcertVehicleType {
  const ConcertVehicleType({
    required this.id,
    required this.code,
    required this.name,
    required this.seatCount,
  });

  factory ConcertVehicleType.fromJson(Map<String, dynamic> json) =>
      ConcertVehicleType(
        id: _asInt(json['id']),
        code: _asString(json['code']),
        name: _asString(json['name']),
        seatCount: _asInt(json['seatCount']),
      );

  final int id;
  final String code;
  final String name;
  final int seatCount;
}

class ConcertService {
  const ConcertService({
    required this.id,
    required this.code,
    required this.name,
    required this.serviceDate,
    required this.direction,
    required this.departureAt,
    required this.meetingTimeNote,
    required this.saleStatus,
  });

  factory ConcertService.fromJson(Map<String, dynamic> json) => ConcertService(
    id: _asInt(json['id']),
    code: _asString(json['code']),
    name: _asString(json['name']),
    serviceDate: _asDate(json['serviceDate']),
    direction: _asString(json['direction']),
    departureAt: _asDate(json['departureAt']),
    meetingTimeNote: _asNullableString(json['meetingTimeNote']),
    saleStatus: _asString(json['saleStatus']),
  );

  final int id;
  final String code;
  final String name;
  final DateTime? serviceDate;
  final String direction;
  final DateTime? departureAt;
  final String? meetingTimeNote;
  final String saleStatus;
}

class ConcertFare {
  const ConcertFare({
    required this.id,
    required this.serviceId,
    required this.routeStopId,
    required this.vehicleTypeId,
    required this.price,
  });

  factory ConcertFare.fromJson(Map<String, dynamic> json) => ConcertFare(
    id: _asInt(json['id']),
    serviceId: _asInt(json['serviceId']),
    routeStopId: _asInt(json['routeStopId']),
    vehicleTypeId: _asInt(json['vehicleTypeId']),
    price: _asNum(json['price']),
  );

  final int id;
  final int serviceId;
  final int routeStopId;
  final int vehicleTypeId;
  final num price;
}

class ConcertCartItem {
  const ConcertCartItem({
    required this.serviceId,
    required this.routeStopId,
    required this.vehicleTypeId,
    required this.quantity,
    this.isCharter = false,
  });

  final int serviceId;
  final int routeStopId;
  final int vehicleTypeId;
  final int quantity;
  final bool isCharter;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'serviceId': serviceId,
    'routeStopId': routeStopId,
    'vehicleTypeId': vehicleTypeId,
    'quantity': quantity,
    'isCharter': isCharter,
  };
}

class ConcertQuote {
  const ConcertQuote({
    required this.eventCode,
    required this.totalQuantity,
    required this.subtotal,
    required this.totalAmount,
    required this.items,
  });

  factory ConcertQuote.fromJson(Map<String, dynamic> json) => ConcertQuote(
    eventCode: _asString(json['eventCode']),
    totalQuantity: _asInt(json['totalQuantity']),
    subtotal: _asNum(json['subtotal']),
    totalAmount: _asNum(json['totalAmount']),
    items: _objectList(json['items'], ConcertOrderLine.fromJson),
  );

  final String eventCode;
  final int totalQuantity;
  final num subtotal;
  final num totalAmount;
  final List<ConcertOrderLine> items;
}

class ConcertPayment {
  const ConcertPayment({
    required this.paymentCode,
    required this.amount,
    required this.gateway,
    required this.bankCode,
    required this.accountNumber,
    required this.accountName,
    required this.qrImageUrl,
    required this.status,
  });

  factory ConcertPayment.fromJson(Map<String, dynamic> json) => ConcertPayment(
    paymentCode: _asString(json['paymentCode']),
    amount: _asNum(json['amount']),
    gateway: _asString(json['gateway']),
    bankCode: _asString(json['bankCode']),
    accountNumber: _asString(json['accountNumber']),
    accountName: _asString(json['accountName']),
    qrImageUrl: _asNullableString(json['qrImageUrl']),
    status: _asString(json['status']),
  );

  final String paymentCode;
  final num amount;
  final String gateway;
  final String bankCode;
  final String accountNumber;
  final String accountName;
  final String? qrImageUrl;
  final String status;
}

class ConcertOrderLine {
  const ConcertOrderLine({
    required this.id,
    required this.serviceId,
    required this.routeStopId,
    required this.vehicleTypeId,
    required this.serviceName,
    required this.serviceDate,
    required this.direction,
    required this.routeName,
    required this.stopName,
    required this.vehicleTypeName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.tickets,
  });

  factory ConcertOrderLine.fromJson(Map<String, dynamic> json) =>
      ConcertOrderLine(
        id: _asInt(json['id']),
        serviceId: _asInt(json['serviceId']),
        routeStopId: _asInt(json['routeStopId']),
        vehicleTypeId: _asInt(json['vehicleTypeId']),
        serviceName: _asString(json['serviceName']),
        serviceDate: _asDate(json['serviceDate']),
        direction: _asString(json['direction']),
        routeName: _asString(json['routeName']),
        stopName: _asString(json['stopName']),
        vehicleTypeName: _asString(json['vehicleTypeName']),
        unitPrice: _asNum(json['unitPrice']),
        quantity: _asInt(json['quantity']),
        lineTotal: _asNum(json['lineTotal']),
        tickets: _objectList(json['tickets'], ConcertTicket.fromJson),
      );

  final int id;
  final int serviceId;
  final int routeStopId;
  final int vehicleTypeId;
  final String serviceName;
  final DateTime? serviceDate;
  final String direction;
  final String routeName;
  final String stopName;
  final String vehicleTypeName;
  final num unitPrice;
  final int quantity;
  final num lineTotal;
  final List<ConcertTicket> tickets;
}

class ConcertTicket {
  const ConcertTicket({
    required this.ticketCode,
    required this.status,
    required this.serviceName,
    required this.serviceDate,
    required this.direction,
    required this.routeName,
    required this.stopName,
    required this.vehicleTypeName,
    required this.issuedAt,
    required this.usedAt,
    required this.qrPayload,
    required this.qrImageBase64,
  });

  factory ConcertTicket.fromJson(Map<String, dynamic> json) => ConcertTicket(
    ticketCode: _asString(json['ticketCode']),
    status: _asString(json['status']),
    serviceName: _asString(json['serviceName']),
    serviceDate: _asDate(json['serviceDate']),
    direction: _asString(json['direction']),
    routeName: _asString(json['routeName']),
    stopName: _asString(json['stopName']),
    vehicleTypeName: _asString(json['vehicleTypeName']),
    issuedAt: _asDate(json['issuedAt']),
    usedAt: _asDate(json['usedAt']),
    qrPayload: _asNullableString(json['qrPayload']),
    qrImageBase64: _asNullableString(json['qrImageBase64']),
  );

  final String ticketCode;
  final String status;
  final String serviceName;
  final DateTime? serviceDate;
  final String direction;
  final String routeName;
  final String stopName;
  final String vehicleTypeName;
  final DateTime? issuedAt;
  final DateTime? usedAt;
  final String? qrPayload;
  final String? qrImageBase64;
}

class ConcertOrder {
  const ConcertOrder({
    required this.orderCode,
    required this.eventName,
    required this.contactFullName,
    required this.contactPhone,
    required this.contactEmail,
    required this.generatedPassword,
    required this.status,
    required this.guestAccessToken,
    required this.totalQuantity,
    required this.totalAmount,
    required this.expiresAt,
    required this.paidAt,
    required this.createdAt,
    required this.payment,
    required this.items,
  });

  factory ConcertOrder.fromJson(Map<String, dynamic> json) => ConcertOrder(
    orderCode: _asString(json['orderCode']),
    eventName: _asString(json['eventName']),
    contactFullName: _asString(json['contactFullName']),
    contactPhone: _asString(json['contactPhone']),
    contactEmail: _asString(json['contactEmail']),
    generatedPassword: _asNullableString(json['password']),
    status: _asString(json['status']),
    guestAccessToken: _asNullableString(json['guestAccessToken']),
    totalQuantity: _asInt(json['totalQuantity']),
    totalAmount: _asNum(json['totalAmount']),
    expiresAt: _asDate(json['expiresAt']),
    paidAt: _asDate(json['paidAt']),
    createdAt: _asDate(json['createdAt']),
    payment: json['payment'] is Map
        ? ConcertPayment.fromJson(_asMap(json['payment']))
        : null,
    items: _objectList(json['items'], ConcertOrderLine.fromJson),
  );

  final String orderCode;
  final String eventName;
  final String contactFullName;
  final String contactPhone;
  final String contactEmail;
  final String? generatedPassword;
  final String status;
  final String? guestAccessToken;
  final int totalQuantity;
  final num totalAmount;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final ConcertPayment? payment;
  final List<ConcertOrderLine> items;

  List<ConcertTicket> get tickets => <ConcertTicket>[
    for (final item in items) ...item.tickets,
  ];

  bool get shouldPoll => status == 'PENDING_PAYMENT';
}

class ConcertOrderContact {
  const ConcertOrderContact({
    required this.contactFullName,
    required this.contactPhone,
    required this.contactEmail,
  });

  factory ConcertOrderContact.fromProfile(CustomerProfileModel profile) =>
      ConcertOrderContact(
        contactFullName: profile.fullName.trim(),
        contactPhone: profile.phone.trim(),
        contactEmail: profile.email.trim(),
      );

  final String contactFullName;
  final String contactPhone;
  final String contactEmail;
}

class GuestConcertOrderCredential {
  const GuestConcertOrderCredential({
    required this.orderCode,
    required this.guestAccessToken,
    required this.createdAt,
  });

  factory GuestConcertOrderCredential.fromJson(Map<String, dynamic> json) =>
      GuestConcertOrderCredential(
        orderCode: _asString(json['orderCode']),
        guestAccessToken: _asString(json['guestAccessToken']),
        createdAt: _asDate(json['createdAt']) ?? DateTime.now(),
      );

  final String orderCode;
  final String guestAccessToken;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'orderCode': orderCode,
    'guestAccessToken': guestAccessToken,
    'createdAt': createdAt.toIso8601String(),
  };
}

String concertDirectionLabel(String direction) => switch (direction) {
  'OUTBOUND' => 'Chiều đi',
  'RETURN' => 'Chiều về',
  _ => direction,
};

String concertOrderStatusLabel(String status) => switch (status) {
  'PENDING_PAYMENT' => 'Chờ thanh toán',
  'PAID' => 'Đã thanh toán',
  'PAYMENT_REVIEW' => 'Cần đối soát',
  'EXPIRED' => 'Hết hạn',
  _ => status,
};

String concertTicketStatusLabel(String status) => switch (status) {
  'ISSUED' => 'Còn hiệu lực',
  'USED' => 'Đã sử dụng',
  'CANCELLED' => 'Không còn hiệu lực',
  _ => status,
};

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<T> _objectList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) convert,
) {
  if (value is! List) return <T>[];
  return value.whereType<Map>().map((item) => convert(_asMap(item))).toList();
}

String _asString(dynamic value) => value?.toString() ?? '';

String? _asNullableString(dynamic value) {
  final result = value?.toString().trim();
  return result == null || result.isEmpty ? null : result;
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

num _asNum(dynamic value) =>
    value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;

DateTime? _asDate(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : DateTime.tryParse(text);
}

int _compareDates(DateTime? first, DateTime? second) {
  if (first == null && second == null) return 0;
  if (first == null) return 1;
  if (second == null) return -1;
  return first.compareTo(second);
}
