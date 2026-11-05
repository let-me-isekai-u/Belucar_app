// Đặt vé Xe limousine / Xe khách của nhà xe đối tác: tìm theo 2 địa chỉ + ngày → chọn chuyến, điểm đón/trả,
// số người (không chọn ghế) → chuyển khoản VietQR mã NXO → vé xác nhận tự động → theo dõi xe trên bản đồ.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'carrier_api.dart';

const _navy = Color(0xFF041565); // chỉ dùng cho marker xe trên nền bản đồ sáng
const _muted = Colors.grey; // đọc được trên cả nền sáng và nền xanh đậm của app
final _money = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
String _vnd(dynamic v) => v == null ? '—' : _money.format(v as num);
String _time(dynamic iso) => iso == null ? '—' : DateFormat('HH:mm').format(DateTime.parse('$iso').toLocal());
String _dayTime(dynamic iso) => iso == null ? '—' : DateFormat('HH:mm dd/MM').format(DateTime.parse('$iso').toLocal());
String _km(dynamic m) => m == null ? '—' : (m as num) < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
const categoryLabel = {'LIMOUSINE': 'Xe limousine', 'COACH': 'Xe khách'};
const _bookingStatus = {
  'PENDING_PAYMENT': 'Chờ thanh toán',
  'CONFIRMED': 'Đã xác nhận',
  'BOARDED': 'Đã lên xe',
  'COMPLETED': 'Hoàn thành',
  'NO_SHOW': 'Vắng mặt',
  'CANCELLED': 'Đã hủy',
  'EXPIRED': 'Hết hạn thanh toán',
  'PAYMENT_REVIEW': 'Đang đối soát',
  'REFUND_PENDING': 'Chờ hoàn tiền',
  'REFUNDED': 'Đã hoàn tiền',
};

void _toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

AppBar _bar(String title, {List<Widget>? actions}) =>
    AppBar(title: Text(title), actions: actions);

/// Ô chọn địa chỉ: gõ → gợi ý TrackAsia → chọn (chỉ địa chỉ chọn từ gợi ý mới hợp lệ).
class _PlaceField extends StatefulWidget {
  const _PlaceField({required this.label, required this.icon, required this.onChanged});
  final String label;
  final IconData icon;
  final ValueChanged<Map<String, String>?> onChanged;
  @override
  State<_PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<_PlaceField> {
  final _text = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _items = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onType(String v) {
    widget.onChanged(null);
    _debounce?.cancel();
    if (v.trim().length < 2) return setState(() => _items = []);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final items = await CarrierApi.places(v.trim());
      if (mounted) setState(() => _items = items);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: _text,
        onChanged: _onType,
        decoration: InputDecoration(labelText: widget.label, prefixIcon: Icon(widget.icon), border: const OutlineInputBorder()),
      ),
      ..._items.map((p) {
        final label = '${p['display'] ?? p['name'] ?? p['address'] ?? ''}';
        return ListTile(
          dense: true,
          leading: const Icon(Icons.place_outlined),
          title: Text(label),
          onTap: () {
            _text.text = label;
            setState(() => _items = []);
            widget.onChanged({'placeId': '${p['placeId']}', 'label': label});
            FocusScope.of(context).unfocus();
          },
        );
      }),
    ]);
  }
}

// ------------------------------------------------------------------------- search
class CarrierSearchScreen extends StatefulWidget {
  const CarrierSearchScreen({super.key, required this.category});
  final String category;
  @override
  State<CarrierSearchScreen> createState() => _CarrierSearchScreenState();
}

class _CarrierSearchScreenState extends State<CarrierSearchScreen> {
  late String _category = widget.category;
  Map<String, String>? _from, _to;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  int _pax = 1;
  String _sort = 'nearest';
  bool _loading = false;
  Map<String, dynamic>? _result;

  Future<void> _search() async {
    if (_from == null || _to == null) return _toast(context, 'Chọn điểm đi và điểm đến từ danh sách gợi ý.');
    setState(() => _loading = true);
    try {
      final r = await CarrierApi.search(
        fromPlaceId: _from!['placeId']!,
        toPlaceId: _to!['placeId']!,
        travelDate: DateFormat('yyyy-MM-dd').format(_date),
        category: _category,
        passengers: _pax,
        sort: _sort,
      );
      if (mounted) setState(() => _result = r);
    } on CarrierApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ((_result?['items'] as List?) ?? []).cast<Map>();
    return Scaffold(
      appBar: _bar('Đặt vé ${categoryLabel[_category]!.toLowerCase()}', actions: [
        IconButton(
          tooltip: 'Vé của tôi',
          icon: const Icon(Icons.confirmation_number_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCarrierTicketsScreen())),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'LIMOUSINE', label: Text('Xe limousine')), ButtonSegment(value: 'COACH', label: Text('Xe khách'))],
          selected: {_category},
          onSelectionChanged: (s) => setState(() { _category = s.first; _result = null; }),
        ),
        const SizedBox(height: 12),
        _PlaceField(label: 'Điểm đi', icon: Icons.trip_origin, onChanged: (v) => _from = v),
        const SizedBox(height: 12),
        _PlaceField(label: 'Điểm đến', icon: Icons.place, onChanged: (v) => _to = v),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat('dd/MM/yyyy').format(_date)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateUtils.dateOnly(DateTime.now()), lastDate: DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 45)));
                if (d != null) setState(() => _date = d);
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton(onPressed: _pax > 1 ? () => setState(() => _pax--) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$_pax người', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(onPressed: _pax < 10 ? () => setState(() => _pax++) : null, icon: const Icon(Icons.add_circle_outline)),
        ]),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _loading ? null : _search,
          icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
          label: const Text('Tìm chuyến'),
        ),
        const SizedBox(height: 8),
        const Text('Không cần chọn ghế — nhà xe đối tác đảm bảo chỗ theo hợp đồng.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12)),
        if (_result != null) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('${items.length} chuyến · bán kính ${_result!['radiusKm']} km')),
            DropdownButton<String>(
              value: _sort,
              items: const [
                DropdownMenuItem(value: 'nearest', child: Text('Gần nhất')),
                DropdownMenuItem(value: 'earliest', child: Text('Sớm nhất')),
                DropdownMenuItem(value: 'cheapest', child: Text('Rẻ nhất')),
              ],
              onChanged: (v) { setState(() => _sort = v!); _search(); },
            ),
          ]),
          if (_result!['distanceQuality'] != 'ROAD' && items.isNotEmpty)
            const Text('Một số khoảng cách ước tính theo đường chim bay.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
          if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Chưa có chuyến phù hợp. Thử ngày khác hoặc loại xe khác.'))),
          ...items.map((it) => _ResultCard(item: Map<String, dynamic>.from(it), pax: _pax)),
        ],
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.pax});
  final Map<String, dynamic> item;
  final int pax;
  @override
  Widget build(BuildContext context) {
    final p = item['pickup'] as Map, d = item['dropoff'] as Map;
    String dist(Map s) => s['roadDistanceMeters'] != null ? _km(s['roadDistanceMeters']) : '~${_km(s['distanceMeters'])}';
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => CarrierCheckoutScreen(runId: item['runId'] as int, pickup: p['runStopId'] as int, dropoff: d['runStopId'] as int, pax: pax),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${item['carrierName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Text(_vnd(item['totalPrice']), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, fontSize: 16)),
            ]),
            Text('${categoryLabel[item['vehicleCategory']]} · ${item['routeName']}', style: const TextStyle(color: _muted)),
            const Divider(),
            Text('${_time(p['pickupAt'])}  ${p['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Cách bạn ${dist(p)} · ${p['address']}', style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 6),
            Text('${_time(d['arriveAt'])}  ${d['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Cách điểm đến ${dist(d)} · ${d['address']}', style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 6),
            Text('${_vnd(item['unitPrice'])}/người · ${item['availabilityLabel']}', style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------- checkout
class CarrierCheckoutScreen extends StatefulWidget {
  const CarrierCheckoutScreen({super.key, required this.runId, required this.pickup, required this.dropoff, required this.pax});
  final int runId, pickup, dropoff, pax;
  @override
  State<CarrierCheckoutScreen> createState() => _CarrierCheckoutScreenState();
}

class _CarrierCheckoutScreenState extends State<CarrierCheckoutScreen> {
  Map<String, dynamic>? _run, _quote;
  late int _pickup = widget.pickup, _dropoff = widget.dropoff, _pax = widget.pax;
  final _name = TextEditingController(), _phone = TextEditingController(), _note = TextEditingController();
  String? _error;
  bool _busy = false;
  String _key = CarrierApi.newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    CarrierApi.run(widget.runId).then((r) {
      if (mounted) setState(() => _run = r);
      _requote();
    }).catchError((Object e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  List<Map> get _stops => ((_run?['stops'] as List?) ?? []).cast<Map>();

  Future<void> _requote() async {
    if (!mounted) return;
    // Đổi điểm/số người = lệnh đặt khác → khóa chống trùng mới.
    setState(() { _quote = null; _error = null; _key = CarrierApi.newIdempotencyKey(); });
    try {
      final q = await CarrierApi.quote(widget.runId, _pickup, _dropoff, _pax);
      if (mounted) setState(() => _quote = q);
    } on CarrierApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _book() async {
    setState(() => _busy = true);
    try {
      final b = await CarrierApi.book({
        'runId': widget.runId,
        'pickupRunStopId': _pickup,
        'dropoffRunStopId': _dropoff,
        'passengerCount': _pax,
        if (_name.text.trim().isNotEmpty) 'contactName': _name.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'contactPhone': _phone.text.trim(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        'expectedTotalAmount': _quote?['totalAmount'],
      }, _key);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CarrierTicketScreen(code: '${b['code']}')));
    } on CarrierApiException catch (e) {
      // 4xx khác 409 = server đã từ chối dứt điểm (không tạo vé) → lần bấm sau là ý định mới, dùng key mới.
      // Lỗi mạng/5xx/409 có thể đã được tiếp nhận → giữ key để retry không tạo vé trùng.
      if (e.status >= 400 && e.status < 500 && e.status != 409) _key = CarrierApi.newIdempotencyKey();
      if (mounted) _toast(context, e.needsLogin ? 'Vui lòng đăng nhập tài khoản khách để đặt vé.' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_run == null) return Scaffold(appBar: _bar('Chọn chuyến'), body: Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator()));
    final pickupSeq = _stops.firstWhere((s) => s['runStopId'] == _pickup, orElse: () => {'sequence': 0})['sequence'] as int;
    final pickups = _stops.where((s) => s['canPickup'] == true).toList();
    final dropoffs = _stops.where((s) => s['canDropoff'] == true && (s['sequence'] as int) > pickupSeq).toList();
    return Scaffold(
      appBar: _bar('${_run!['carrierName']}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${categoryLabel[_run!['vehicleCategory']]} · ${_run!['routeName']} · xuất bến ${_dayTime(_run!['plannedDepartureAt'])}'),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: pickups.any((s) => s['runStopId'] == _pickup) ? _pickup : null,
          decoration: const InputDecoration(labelText: 'Điểm đón', border: OutlineInputBorder()),
          items: pickups.map((s) => DropdownMenuItem(value: s['runStopId'] as int, child: Text('${_time(s['plannedDepartureAt'])} · ${s['name']}'))).toList(),
          onChanged: (v) {
            final seq = _stops.firstWhere((s) => s['runStopId'] == v)['sequence'] as int;
            final current = _stops.firstWhere((s) => s['runStopId'] == _dropoff, orElse: () => {'sequence': 0});
            setState(() {
              _pickup = v!;
              if ((current['sequence'] as int) <= seq) _dropoff = (_stops.lastWhere((s) => s['canDropoff'] == true)['runStopId']) as int;
            });
            _requote();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey('dropoff-$_pickup'),
          initialValue: dropoffs.any((s) => s['runStopId'] == _dropoff) ? _dropoff : null,
          decoration: const InputDecoration(labelText: 'Điểm trả', border: OutlineInputBorder()),
          items: dropoffs.map((s) => DropdownMenuItem(value: s['runStopId'] as int, child: Text('${_time(s['plannedArrivalAt'])} · ${s['name']}'))).toList(),
          onChanged: (v) { setState(() => _dropoff = v!); _requote(); },
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Số hành khách'),
          const Spacer(),
          IconButton(onPressed: _pax > 1 ? () { setState(() => _pax--); _requote(); } : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$_pax', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(onPressed: _pax < 10 ? () { setState(() => _pax++); _requote(); } : null, icon: const Icon(Icons.add_circle_outline)),
        ]),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên người liên hệ (để trống: theo tài khoản)')),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại (để trống: theo tài khoản)')),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Ghi chú cho nhà xe')),
        const SizedBox(height: 16),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_quote != null)
          Card(
            child: ListTile(
              title: Text('Tổng: ${_vnd(_quote!['totalAmount'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${_vnd(_quote!['unitPrice'])} × ${_quote!['passengerCount']} người · ${_quote!['availabilityLabel']}'),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _quote == null || _busy ? null : _book,
          child: Text(_busy ? 'Đang đặt...' : 'Đặt vé & thanh toán'),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------------- ticket
class CarrierTicketScreen extends StatefulWidget {
  const CarrierTicketScreen({super.key, required this.code});
  final String code;
  @override
  State<CarrierTicketScreen> createState() => _CarrierTicketScreenState();
}

class _CarrierTicketScreenState extends State<CarrierTicketScreen> {
  Map<String, dynamic>? _b, _track;
  String? _error;
  Timer? _timer;
  bool _fast = true;

  @override
  void initState() {
    super.initState();
    _load();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    // Chờ thanh toán / đang theo dõi xe: 6 giây/lần; còn lại 30 giây/lần.
    _timer = Timer.periodic(Duration(seconds: _fast ? 6 : 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await CarrierApi.booking(widget.code);
      Map<String, dynamic>? track;
      if (b['trackingAvailable'] == true) {
        try {
          track = await CarrierApi.tracking((b['run'] as Map)['id'] as int);
        } on CarrierApiException catch (_) {}
      }
      if (!mounted) return;
      setState(() { _b = b; _track = track; _error = null; });
      final fast = b['status'] == 'PENDING_PAYMENT' || b['status'] == 'PAYMENT_REVIEW' || track != null;
      if (fast != _fast) {
        _fast = fast;
        _schedule();
      }
    } on CarrierApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hủy đơn chưa thanh toán?'),
        content: const Text('Đừng chuyển khoản sau khi hủy.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Không')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hủy đơn'))],
      ),
    );
    if (ok != true) return;
    try {
      await CarrierApi.cancel(widget.code);
      await _load();
    } on CarrierApiException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  Widget _copyRow(String label, String value, {String? raw}) => ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(color: _muted)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        trailing: raw == null ? null : IconButton(icon: const Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: raw)); _toast(context, 'Đã sao chép.'); }),
      );

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null) return Scaffold(appBar: _bar('Vé ${widget.code}'), body: Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator()));
    final run = b['run'] as Map, pickup = b['pickup'] as Map, dropoff = b['dropoff'] as Map;
    final pay = b['status'] == 'PENDING_PAYMENT' ? b['payment'] as Map? : null;
    return Scaffold(
      appBar: _bar('Vé ${b['code']}'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Align(alignment: Alignment.centerLeft, child: Chip(label: Text(_bookingStatus[b['status']] ?? '${b['status']}'))),
          if (pay != null) ...[
            const Text('Chuyển khoản để xác nhận vé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Hạn thanh toán: ${_dayTime(pay['expiresAt'])}', style: const TextStyle(color: Colors.orange)),
            if (pay['qrImageUrl'] != null) Center(child: Image.network('${pay['qrImageUrl']}', width: 240, height: 240)),
            _copyRow('Số tiền', _vnd(pay['amount']), raw: '${pay['amount']}'),
            _copyRow('Nội dung chuyển khoản', '${pay['transferContent'] ?? pay['paymentCode']}', raw: '${pay['transferContent'] ?? pay['paymentCode']}'),
            _copyRow('Số tài khoản', '${pay['accountNumber']} (${pay['bankCode']})', raw: '${pay['accountNumber']}'),
            _copyRow('Chủ tài khoản', '${pay['accountName']}'),
            const Text('Chuyển đúng số tiền và nội dung. Vé tự xác nhận khi ngân hàng báo có.', style: TextStyle(fontSize: 12, color: _muted)),
            TextButton(onPressed: _cancel, child: const Text('Hủy đơn', style: TextStyle(color: Colors.red))),
          ],
          if (b['status'] == 'PAYMENT_REVIEW') const Text('Đã nhận giao dịch nhưng cần đối soát; bộ phận hỗ trợ sẽ liên hệ xác nhận hoặc hoàn tiền.', style: TextStyle(color: Colors.orange)),
          const Divider(),
          Text('${run['carrierName']} · ${categoryLabel[run['vehicleCategory']]}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${run['routeName']}'),
          const SizedBox(height: 8),
          Text('Đón: ${_dayTime(pickup['pickupAt'])} · ${pickup['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${pickup['address']}', style: const TextStyle(fontSize: 12, color: _muted)),
          Text('Trả: ${_dayTime(dropoff['arriveAt'])} · ${dropoff['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${b['passengerCount']} người · ${_vnd(b['totalAmount'])}'),
          if (run['vehiclePlate'] != null) Text('Biển số xe: ${run['vehiclePlate']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (run['carrierPhone'] != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.secondary),
                onPressed: () => launchUrl(Uri.parse('tel:${run['carrierPhone']}')),
                icon: const Icon(Icons.phone),
                label: Text('Gọi nhà xe ${run['carrierPhone']}'),
              ),
            ),
          if (_track != null) _TrackingView(track: _track!, pickupId: pickup['id'] as int, dropoffId: dropoff['id'] as int),
          if (_track == null && (b['status'] == 'CONFIRMED' || b['status'] == 'BOARDED'))
            const Padding(padding: EdgeInsets.only(top: 12), child: Text('Theo dõi vị trí xe mở 60 phút trước giờ đón.', style: TextStyle(color: _muted))),
        ]),
      ),
    );
  }
}

class _TrackingView extends StatelessWidget {
  const _TrackingView({required this.track, required this.pickupId, required this.dropoffId});
  final Map<String, dynamic> track;
  final int pickupId, dropoffId;

  @override
  Widget build(BuildContext context) {
    final stops = ((track['stops'] as List?) ?? []).cast<Map>();
    if (stops.isEmpty) return const SizedBox.shrink();
    final loc = track['location'] as Map?;
    final signal = '${track['signal']}';
    final pickup = stops.firstWhere((s) => s['id'] == pickupId, orElse: () => stops.first);
    LatLng at(Map m) => LatLng((m['latitude'] as num).toDouble(), (m['longitude'] as num).toDouble());
    final vehicle = loc != null ? at(loc) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(),
      Row(children: [
        const Text('Theo dõi xe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        Chip(
          backgroundColor: signal == 'LIVE' ? Colors.green.shade100 : Colors.orange.shade100,
          label: Text(signal == 'LIVE' ? 'Trực tuyến' : signal == 'STALE' ? 'Mất tín hiệu' : 'Chưa có tín hiệu', style: const TextStyle(color: Colors.black87)),
        ),
      ]),
      if (loc != null) Text('Cập nhật ${loc['ageSeconds']} giây trước', style: const TextStyle(fontSize: 12, color: _muted)),
      if (((track['delayMinutes'] as num?) ?? 0) > 0) Text('Xe trễ khoảng ${track['delayMinutes']} phút so với lịch.', style: const TextStyle(color: Colors.orange)),
      const SizedBox(height: 8),
      SizedBox(
        height: 260,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlutterMap(
            options: MapOptions(initialCenter: vehicle ?? at(pickup), initialZoom: 13),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.belucar.app'),
              MarkerLayer(markers: [
                ...stops.map((s) => Marker(
                      point: at(s),
                      width: 30,
                      height: 30,
                      child: Icon(Icons.location_on, color: s['id'] == pickupId ? Colors.green : s['id'] == dropoffId ? Colors.blue : Colors.grey),
                    )),
                if (vehicle != null) Marker(point: vehicle, width: 40, height: 40, child: const Icon(Icons.directions_bus, color: _navy, size: 34)),
              ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      ...stops.map((s) => ListTile(
            dense: true,
            leading: Icon(s['actualArrivalAt'] != null ? Icons.check_circle : Icons.radio_button_unchecked,
                color: s['actualArrivalAt'] != null ? Colors.green : Colors.grey),
            title: Text('${s['name']}${s['id'] == pickupId ? ' (điểm đón của bạn)' : s['id'] == dropoffId ? ' (điểm trả)' : ''}'),
            subtitle: Text(s['actualArrivalAt'] != null
                ? 'Đã đến ${_time(s['actualArrivalAt'])}'
                : 'Dự kiến ${_time(s['estimatedArrivalAt'] ?? s['plannedArrivalAt'])} (lịch ${_time(s['plannedArrivalAt'])})'),
          )),
      const Text('Giờ dự kiến theo lịch chạy và độ trễ thực tế, chưa tính giao thông.', style: TextStyle(fontSize: 11, color: _muted)),
    ]);
  }
}

// ------------------------------------------------------------------------- my tickets
class MyCarrierTicketsScreen extends StatefulWidget {
  const MyCarrierTicketsScreen({super.key});
  @override
  State<MyCarrierTicketsScreen> createState() => _MyCarrierTicketsScreenState();
}

class _MyCarrierTicketsScreenState extends State<MyCarrierTicketsScreen> {
  List<Map>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await CarrierApi.myBookings(1);
      if (mounted) setState(() => _items = ((r['items'] as List?) ?? []).cast<Map>());
    } on CarrierApiException catch (e) {
      if (mounted) setState(() => _error = e.needsLogin ? 'Vui lòng đăng nhập để xem vé.' : e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: _bar('Vé nhà xe của tôi'),
        body: _items == null
            ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(children: [
                  if (_items!.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Chưa có vé nào.'))),
                  ..._items!.map((b) => ListTile(
                        title: Text('${_dayTime((b['pickup'] as Map)['pickupAt'])} · ${(b['pickup'] as Map)['name']} → ${(b['dropoff'] as Map)['name']}'),
                        subtitle: Text('${(b['run'] as Map)['carrierName']} · ${b['passengerCount']} người · ${_vnd(b['totalAmount'])}'),
                        trailing: Text(_bookingStatus[b['status']] ?? '${b['status']}', style: const TextStyle(fontSize: 12)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CarrierTicketScreen(code: '${b['code']}'))).then((_) => _load()),
                      )),
                ]),
              ),
      );
}
