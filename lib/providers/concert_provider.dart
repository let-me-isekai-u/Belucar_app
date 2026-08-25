import 'package:flutter/foundation.dart';

import '../models/concert_models.dart';
import '../services/concert_api_service.dart';
import '../services/guest_concert_order_storage.dart';
import '../services/login_credential_storage.dart';
import 'account_provider.dart';
import 'auth_provider.dart';

typedef ConcertLoginCredentialSaver =
    Future<void> Function({required String phone, required String password});

class ConcertProvider extends ChangeNotifier {
  ConcertProvider({
    required AuthProvider authProvider,
    required AccountProvider accountProvider,
    required ConcertApiService apiService,
    required GuestConcertOrderStorage guestStorage,
    required this.guestMode,
    ConcertLoginCredentialSaver? loginCredentialSaver,
  }) : _authProvider = authProvider,
       _accountProvider = accountProvider,
       _apiService = apiService,
       _guestStorage = guestStorage,
       _loginCredentialSaver =
           loginCredentialSaver ?? LoginCredentialStorage.save;

  final AuthProvider _authProvider;
  final AccountProvider _accountProvider;
  final ConcertApiService _apiService;
  final GuestConcertOrderStorage _guestStorage;
  final ConcertLoginCredentialSaver _loginCredentialSaver;
  final bool guestMode;

  ConcertCatalog? _catalog;
  ConcertQuote? _quote;
  ConcertOrder? _currentOrder;
  List<ConcertOrder> _orders = const <ConcertOrder>[];
  List<ConcertTicket> _tickets = const <ConcertTicket>[];
  int? _routeId;
  int? _stopId;
  int? _vehicleTypeId;
  bool _isCharter = false;
  final Map<int, int> _quantities = <int, int>{};
  bool _loadingCatalog = false;
  bool _submitting = false;
  bool _loadingLibrary = false;
  bool _refreshingOrder = false;
  String? _errorMessage;

  ConcertCatalog? get catalog => _catalog;
  ConcertQuote? get quote => _quote;
  ConcertOrder? get currentOrder => _currentOrder;
  List<ConcertOrder> get orders => _orders;
  List<ConcertTicket> get tickets => _tickets;
  int? get routeId => _routeId;
  int? get stopId => _stopId;
  int? get vehicleTypeId => _vehicleTypeId;
  bool get isCharter => _isCharter;
  bool get loadingCatalog => _loadingCatalog;
  bool get submitting => _submitting;
  bool get loadingLibrary => _loadingLibrary;
  bool get refreshingOrder => _refreshingOrder;
  String? get errorMessage => _errorMessage;

  ConcertRoute? get selectedRoute {
    for (final route in _catalog?.routes ?? const <ConcertRoute>[]) {
      if (route.id == _routeId) return route;
    }
    return null;
  }

  ConcertRouteStop? get selectedStop {
    for (final stop in selectedRoute?.stops ?? const <ConcertRouteStop>[]) {
      if (stop.id == _stopId) return stop;
    }
    return null;
  }

  ConcertVehicleType? get selectedVehicleType {
    for (final item in _catalog?.vehicleTypes ?? const <ConcertVehicleType>[]) {
      if (item.id == _vehicleTypeId) return item;
    }
    return null;
  }

  List<ConcertService> get services =>
      _catalog?.openServices ?? const <ConcertService>[];

  int quantityFor(int serviceId) => _quantities[serviceId] ?? 0;

  ConcertFare? fareFor(ConcertService service) {
    final stopId = _stopId;
    final vehicleId = _vehicleTypeId;
    if (stopId == null || vehicleId == null) return null;
    return _catalog?.fareFor(
      serviceId: service.id,
      routeStopId: stopId,
      vehicleTypeId: vehicleId,
    );
  }

  List<ConcertCartItem> get cartItems {
    final stopId = _stopId;
    final vehicleId = _vehicleTypeId;
    if (stopId == null || vehicleId == null) return const <ConcertCartItem>[];
    return <ConcertCartItem>[
      for (final service in services)
        if (quantityFor(service.id) > 0 && fareFor(service) != null)
          ConcertCartItem(
            serviceId: service.id,
            routeStopId: stopId,
            vehicleTypeId: vehicleId,
            quantity: quantityFor(service.id),
            isCharter: _isCharter,
          ),
    ];
  }

  int get totalQuantity =>
      cartItems.fold<int>(0, (total, item) => total + item.quantity);

  num get estimatedTotal {
    num total = 0;
    for (final service in services) {
      final fare = fareFor(service);
      if (fare != null) total += fare.price * quantityFor(service.id);
    }
    return total;
  }

  bool get canCreateOrder =>
      _catalog?.canBook == true && cartItems.isNotEmpty && !_submitting;

  Future<void> loadCatalog() async {
    if (_loadingCatalog) return;
    _loadingCatalog = true;
    _errorMessage = null;
    notifyListeners();
    final response = await _apiService.getCatalog();
    if (response.isSuccess) {
      _catalog = response.data;
      _initializeSelection();
    } else {
      _errorMessage = response.message;
    }
    _loadingCatalog = false;
    notifyListeners();
  }

  void selectRoute(int routeId) {
    if (_routeId == routeId) return;
    _routeId = routeId;
    final stops = selectedRoute?.selectableStops ?? const <ConcertRouteStop>[];
    _stopId = stops.isEmpty ? null : stops.first.id;
    _selectionChanged();
  }

  void selectStop(int stopId) {
    if (_stopId == stopId) return;
    _stopId = stopId;
    _selectionChanged();
  }

  void selectVehicleType(int vehicleTypeId) {
    if (_vehicleTypeId == vehicleTypeId) return;
    _vehicleTypeId = vehicleTypeId;
    _isCharter = false;
    _selectionChanged();
  }

  void setCharter(bool value) {
    if (_isCharter == value) return;
    _isCharter = value;
    _quote = null;
    _errorMessage = null;
    notifyListeners();
  }

  void setQuantity(int serviceId, int quantity) {
    final service = services.where((item) => item.id == serviceId).firstOrNull;
    if (service == null || fareFor(service) == null) return;
    final oldQuantity = quantityFor(serviceId);
    final allowedByOrderLimit = 100 - (totalQuantity - oldQuantity);
    final normalized = quantity.clamp(0, allowedByOrderLimit.clamp(0, 50));
    _quantities[serviceId] = normalized;
    _quote = null;
    _errorMessage = null;
    notifyListeners();
  }

  void setServiceQuantities(Map<int, int> quantities) {
    var total = 0;
    for (final service in services) {
      final requested = quantities[service.id] ?? 0;
      final normalized = fareFor(service) == null
          ? 0
          : requested.clamp(0, (100 - total).clamp(0, 50));
      _quantities[service.id] = normalized;
      total += normalized;
    }
    _quote = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<ConcertQuote?> quoteSelection() async {
    final items = cartItems;
    if (items.isEmpty) {
      _errorMessage = 'Vui lòng chọn ít nhất một vé.';
      notifyListeners();
      return null;
    }
    final response = await _apiService.quote(items);
    if (!response.isSuccess) {
      _errorMessage = response.message;
      notifyListeners();
      return null;
    }
    _quote = response.data;
    _errorMessage = null;
    notifyListeners();
    return _quote;
  }

  Future<ConcertOrder?> createOrder({
    required String contactFullName,
    required String contactPhone,
    required String contactEmail,
  }) async {
    if (_submitting) return null;
    _submitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final contact = await _resolveOrderContact(
        contactFullName: contactFullName,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
      );
      if (contact == null) return null;

      final validationError = validateContact(
        contact.contactFullName,
        contact.contactPhone,
        contact.contactEmail,
      );
      if (validationError != null) {
        _errorMessage = validationError;
        return null;
      }

      if (await quoteSelection() == null) return null;
      final items = cartItems;
      late ConcertApiResponse<ConcertOrder> response;
      if (guestMode) {
        response = await _apiService.createOrder(
          contactFullName: contact.contactFullName,
          contactPhone: contact.contactPhone,
          contactEmail: contact.contactEmail,
          items: items,
        );
      } else {
        response = await _authorized(
          (token) => _apiService.createOrder(
            contactFullName: contact.contactFullName,
            contactPhone: contact.contactPhone,
            contactEmail: contact.contactEmail,
            items: items,
            accessToken: token,
          ),
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[ConcertOrder] create response: status=${response.statusCode}, '
          'success=${response.isSuccess}, message=${response.message ?? '-'}',
        );
      }
      if (!response.isSuccess) {
        _errorMessage = response.message;
        return null;
      }

      _currentOrder = response.data;
      await _persistGuestAccountCredentials(_currentOrder, contact);
      final guestToken = _currentOrder?.guestAccessToken;
      if (guestToken != null && guestToken.isNotEmpty) {
        await _guestStorage.save(
          GuestConcertOrderCredential(
            orderCode: _currentOrder!.orderCode,
            guestAccessToken: guestToken,
            createdAt: DateTime.now(),
          ),
        );
      }
      return _currentOrder;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<ConcertOrderContact?> _resolveOrderContact({
    required String contactFullName,
    required String contactPhone,
    required String contactEmail,
  }) async {
    if (guestMode) {
      return ConcertOrderContact(
        contactFullName: contactFullName.trim(),
        contactPhone: contactPhone.trim(),
        contactEmail: contactEmail.trim(),
      );
    }

    var profile = _accountProvider.profile;
    if (profile == null) {
      final result = await _accountProvider.loadProfile(notify: false);
      if (!result.isSuccess || result.data == null) {
        _errorMessage = result.message ?? 'Không thể tải thông tin tài khoản.';
        return null;
      }
      profile = result.data;
    }
    return ConcertOrderContact.fromProfile(profile!);
  }

  Future<void> _persistGuestAccountCredentials(
    ConcertOrder? order,
    ConcertOrderContact contact,
  ) async {
    if (!guestMode || order == null) return;
    final password = order.generatedPassword?.trim() ?? '';
    if (password.isEmpty) return;
    final phone = order.contactPhone.trim().isNotEmpty
        ? order.contactPhone.trim()
        : contact.contactPhone;
    if (phone.isEmpty) return;
    try {
      await _loginCredentialSaver(phone: phone, password: password);
    } catch (_) {
      // Autofill credentials are optional; ticket creation already succeeded.
    }
  }

  Future<bool> refreshOrder(
    String orderCode, {
    GuestConcertOrderCredential? credential,
  }) async {
    if (_refreshingOrder) return false;
    _refreshingOrder = true;
    notifyListeners();
    try {
      late ConcertApiResponse<ConcertOrder> response;
      if (guestMode) {
        final saved = credential ?? await _guestStorage.find(orderCode);
        if (saved == null) {
          _errorMessage = 'Không tìm thấy quyền truy cập đơn guest này.';
          return false;
        }
        response = await _apiService.getOrder(
          orderCode: orderCode,
          guestAccessToken: saved.guestAccessToken,
        );
      } else {
        response = await _authorized(
          (token) =>
              _apiService.getOrder(orderCode: orderCode, accessToken: token),
        );
      }
      if (!response.isSuccess) {
        _errorMessage = response.message;
        return false;
      }
      _currentOrder = response.data;
      _errorMessage = null;
      return true;
    } finally {
      _refreshingOrder = false;
      notifyListeners();
    }
  }

  Future<void> loadLibrary() async {
    if (_loadingLibrary) return;
    _loadingLibrary = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (guestMode) {
        final credentials = await _guestStorage.readAll();
        final results = await Future.wait(
          credentials.map(
            (credential) => _apiService.getOrder(
              orderCode: credential.orderCode,
              guestAccessToken: credential.guestAccessToken,
            ),
          ),
        );
        _orders =
            results
                .where((result) => result.isSuccess)
                .map((result) => result.data!)
                .toList()
              ..sort(_newestOrderFirst);
        _tickets = <ConcertTicket>[
          for (final order in _orders) ...order.tickets,
        ];
      } else {
        final orderFuture = _authorized(
          (token) => _apiService.getMyOrders(accessToken: token),
        );
        final ticketFuture = _authorized(
          (token) => _apiService.getMyTickets(accessToken: token),
        );
        final orderResponse = await orderFuture;
        final ticketResponse = await ticketFuture;
        if (!orderResponse.isSuccess) {
          _errorMessage = orderResponse.message;
        } else {
          _orders = orderResponse.data!..sort(_newestOrderFirst);
        }
        if (ticketResponse.isSuccess) _tickets = ticketResponse.data!;
      }
    } finally {
      _loadingLibrary = false;
      notifyListeners();
    }
  }

  Future<ConcertTicket?> loadTicket(String ticketCode) async {
    if (guestMode) {
      for (final order in _orders) {
        for (final ticket in order.tickets) {
          if (ticket.ticketCode == ticketCode) return ticket;
        }
      }
      return null;
    }
    final response = await _authorized(
      (token) =>
          _apiService.getTicket(ticketCode: ticketCode, accessToken: token),
    );
    if (!response.isSuccess) {
      _errorMessage = response.message;
      notifyListeners();
      return null;
    }
    return response.data;
  }

  Future<String?> resendEmail(String orderCode) async {
    late ConcertApiResponse<bool> response;
    if (guestMode) {
      final credential = await _guestStorage.find(orderCode);
      if (credential == null) return 'Không tìm thấy quyền truy cập đơn guest.';
      response = await _apiService.resendEmail(
        orderCode: orderCode,
        guestAccessToken: credential.guestAccessToken,
      );
    } else {
      response = await _authorized(
        (token) =>
            _apiService.resendEmail(orderCode: orderCode, accessToken: token),
      );
    }
    return response.isSuccess ? null : response.message;
  }

  Future<ConcertApiResponse<T>> _authorized<T>(
    Future<ConcertApiResponse<T>> Function(String token) request,
  ) async {
    try {
      final response = await _authProvider.authorizedRequest(
        request,
        isUnauthorized: (result) => result.isUnauthorized,
      );
      if (response.isUnauthorized) await _authProvider.clearSession();
      return response;
    } catch (_) {
      return ConcertApiResponse<T>(
        statusCode: 401,
        message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
  }

  void _initializeSelection() {
    final catalog = _catalog;
    if (catalog == null) return;
    final routes = catalog.routes
        .where((route) => route.selectableStops.isNotEmpty)
        .toList();
    _routeId = routes.isEmpty ? null : routes.first.id;
    _stopId = routes.isEmpty ? null : routes.first.selectableStops.first.id;
    _vehicleTypeId = catalog.vehicleTypes.isEmpty
        ? null
        : catalog.vehicleTypes.first.id;
    _quantities.clear();
    _ensureOneSelectedService();
  }

  void _selectionChanged() {
    _quote = null;
    _errorMessage = null;
    for (final service in services) {
      if (fareFor(service) == null) _quantities[service.id] = 0;
    }
    _ensureOneSelectedService();
    notifyListeners();
  }

  void _ensureOneSelectedService() {
    if (cartItems.isNotEmpty) return;
    for (final service in services) {
      if (fareFor(service) != null) {
        _quantities[service.id] = 1;
        return;
      }
    }
  }

  String? validateContact(String fullName, String phone, String email) {
    if (fullName.trim().isEmpty) return 'Vui lòng nhập họ tên liên hệ.';
    if (fullName.trim().length > 100) return 'Họ tên tối đa 100 ký tự.';
    final normalizedPhone = phone
        .replaceAll(RegExp(r'[\s.-]'), '')
        .replaceFirst(RegExp(r'^\+?84'), '0');
    if (!RegExp(r'^0[35789]\d{8}$').hasMatch(normalizedPhone)) {
      return 'Vui lòng nhập số di động Việt Nam hợp lệ.';
    }
    final normalizedEmail = email.trim();
    if (normalizedEmail.length > 255 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail)) {
      return 'Vui lòng nhập email hợp lệ.';
    }
    return null;
  }

  static int _newestOrderFirst(ConcertOrder a, ConcertOrder b) {
    final first = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final second = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return second.compareTo(first);
  }
}
