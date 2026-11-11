// Đặt vé Xe limousine / Xe khách của nhà xe đối tác: tìm theo 2 địa chỉ + ngày → chọn chuyến, điểm đón/trả,
// số người (không chọn ghế) → trả bằng ví hoặc chuyển khoản VietQR mã NXO → vé xác nhận tự động → theo dõi xe.
// Giao diện theo bộ thiết kế navy dùng chung (lib/ui).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/map_config.dart';
import '../../ui/ui.dart';
import 'carrier_api.dart';

final _money = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
String _vnd(dynamic v) => v == null ? '—' : _money.format(v as num);
DateTime? _dt(dynamic iso) => iso == null ? null : DateTime.parse('$iso').toLocal();
String _time(dynamic iso) => iso == null ? '—' : DateFormat('HH:mm').format(_dt(iso)!);
String _dayTime(dynamic iso) => iso == null ? '—' : DateFormat('HH:mm dd/MM').format(_dt(iso)!);
String _pct(dynamic v) {
  final n = (v as num?) ?? 0;
  return n == n.roundToDouble() ? '${n.round()}%' : '$n%';
}

String _km(dynamic m) => m == null
    ? '—'
    : (m as num) < 1000
    ? '${m.round()} m'
    : '${(m / 1000).toStringAsFixed(1)} km';
String _duration(dynamic a, dynamic b) {
  final x = _dt(a), y = _dt(b);
  if (x == null || y == null || !y.isAfter(x)) return '';
  final d = y.difference(x);
  return d.inHours > 0 ? '${d.inHours}g ${(d.inMinutes % 60).toString().padLeft(2, '0')}' : '${d.inMinutes} phút';
}

String _initials(String s) {
  final w = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (w.isEmpty) return '?';
  return (w.length == 1 ? w.first.substring(0, w.first.length.clamp(1, 2)) : '${w[0][0]}${w[1][0]}').toUpperCase();
}

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
Tone _statusTone(dynamic s) => switch ('$s') {
  'PENDING_PAYMENT' || 'PAYMENT_REVIEW' || 'REFUND_PENDING' => Tone.warning,
  'CONFIRMED' || 'COMPLETED' => Tone.success,
  'BOARDED' || 'REFUNDED' => Tone.info,
  'CANCELLED' || 'NO_SHOW' => Tone.danger,
  _ => Tone.neutral,
};
StatusChip _statusChip(dynamic s, {bool dense = false}) => StatusChip(_bookingStatus['$s'] ?? '$s', tone: _statusTone(s), dense: dense);

void _toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

/// "từ 24 giờ: hoàn 100% · 5–24 giờ: hoàn 90% · ..." (chính sách hoàn vé dùng chung).
String refundPolicyText(List<Map<String, dynamic>> tiers) {
  final t = [...tiers]..sort((a, b) => (b['minHoursBeforePickup'] as num).compareTo(a['minHoursBeforePickup'] as num));
  String h(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
  return [
    for (var i = 0; i < t.length; i++)
      '${(t[i]['minHoursBeforePickup'] as num) == 0
          ? 'dưới ${h(t[i - 1]['minHoursBeforePickup'] as num)} giờ'
          : i == 0
          ? 'từ ${h(t[i]['minHoursBeforePickup'] as num)} giờ'
          : '${h(t[i]['minHoursBeforePickup'] as num)}–${h(t[i - 1]['minHoursBeforePickup'] as num)} giờ'}: hoàn ${h(t[i]['refundPercent'] as num)}%',
  ].join(' · ');
}

/// Ô vuông chữ viết tắt tên nhà xe.
class _CarrierBadge extends StatelessWidget {
  const _CarrierBadge(this.name, {this.highlight = false, this.size = 34});
  final String name;
  final bool highlight;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: highlight ? Brand.navy : Brand.b100, borderRadius: BorderRadius.circular(size * 0.3)),
    child: Text(
      _initials(name),
      style: TextStyle(color: highlight ? Colors.white : Brand.navy, fontWeight: FontWeight.w800, fontSize: size * 0.38),
    ),
  );
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
  final _fromText = TextEditingController(), _toText = TextEditingController();
  final _fromFocus = FocusNode(), _toFocus = FocusNode();
  bool _editingFrom = true;
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  int _pax = 1;
  String _sort = 'nearest';
  bool _loading = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _debounce?.cancel();
    _fromText.dispose();
    _toText.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _onType(bool from, String v) {
    setState(() {
      _editingFrom = from;
      if (from) {
        _from = null;
      } else {
        _to = null;
      }
    });
    _debounce?.cancel();
    if (v.trim().length < 2) return setState(() => _suggestions = []);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final items = await CarrierApi.places(v.trim());
      if (mounted) setState(() => _suggestions = items);
    });
  }

  void _pick(Map<String, dynamic> p) {
    final label = '${p['display'] ?? p['name'] ?? p['address'] ?? ''}';
    final value = {'placeId': '${p['placeId']}', 'label': label};
    setState(() {
      if (_editingFrom) {
        _from = value;
        _fromText.text = label;
      } else {
        _to = value;
        _toText.text = label;
      }
      _suggestions = [];
    });
    if (_editingFrom && _to == null) {
      _toFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _swap() {
    setState(() {
      final f = _from, t = _fromText.text;
      _from = _to;
      _fromText.text = _toText.text;
      _to = f;
      _toText.text = t;
      _suggestions = [];
      _result = null;
    });
  }

  Future<void> _search() async {
    if (_from == null || _to == null) return _toast(context, 'Chọn điểm đi và điểm đến từ danh sách gợi ý.');
    FocusScope.of(context).unfocus();
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

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: today, lastDate: today.add(const Duration(days: 45)));
    if (d != null) setState(() => _date = d);
  }

  Widget _placeInput({required bool from}) {
    final c = from ? _fromText : _toText;
    return TextField(
      controller: c,
      focusNode: from ? _fromFocus : _toFocus,
      onTap: () => setState(() => _editingFrom = from),
      onChanged: (v) => _onType(from, v),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(0, 4, 52, 4),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        labelText: from ? 'Điểm đi' : 'Điểm đến',
        hintText: from ? 'Nhập nơi bạn ở / điểm xuất phát' : 'Nhập nơi muốn đến',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ((_result?['items'] as List?) ?? []).cast<Map>();
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    String weekday(DateTime d) => const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][d.weekday - 1];
    Widget dateBtn(DateTime d, String top) {
      final sel = DateUtils.isSameDay(d, _date);
      return Expanded(
        child: SelectTile(
          selected: sel,
          padding: const EdgeInsets.symmetric(vertical: 9),
          onTap: () => setState(() => _date = d),
          child: Column(
            children: [
              Text(
                top,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Brand.navy : Brand.inkMuted),
              ),
              Text(
                '${weekday(d)}, ${DateFormat('dd/MM').format(d)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sel ? Brand.navy : Brand.ink),
              ),
            ],
          ),
        ),
      );
    }

    final custom = !DateUtils.isSameDay(_date, today) && !DateUtils.isSameDay(_date, tomorrow);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Brand.canvas,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    Container(
                      height: 250 + MediaQuery.of(context).padding.top,
                      color: Brand.navy,
                      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Quay lại',
                                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.12)),
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Đặt vé đường dài',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Vé của tôi',
                                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.12)),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCarrierTicketsScreen())),
                                icon: const Icon(Icons.confirmation_number_outlined, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              children: [
                                for (final (value, label) in const [('LIMOUSINE', 'Xe limousine'), ('COACH', 'Xe khách')])
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        _category = value;
                                        _result = null;
                                      }),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _category == value ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            color: _category == value ? Brand.navy : Brand.b100,
                                            fontWeight: _category == value ? FontWeight.w700 : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 136, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [BoxShadow(color: Color(0x29041565), blurRadius: 40, offset: Offset(0, 12))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Brand.line, width: 1.5),
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                                        child: Row(
                                          children: [
                                            const PickupDot(size: 11, hollow: true),
                                            const SizedBox(width: 12),
                                            Expanded(child: _placeInput(from: true)),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1.5, thickness: 1.5, color: Brand.line),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                                        child: Row(
                                          children: [
                                            const DropoffDot(size: 11),
                                            const SizedBox(width: 12),
                                            Expanded(child: _placeInput(from: false)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 12,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Material(
                                      color: Colors.white,
                                      shape: const CircleBorder(side: BorderSide(color: Brand.line, width: 1.5)),
                                      child: IconButton(
                                        tooltip: 'Đảo chiều điểm đi và điểm đến',
                                        onPressed: _swap,
                                        icon: const Icon(Icons.swap_vert_rounded, color: Brand.navy),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_suggestions.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(14)),
                                child: Column(
                                  children: [
                                    for (final p in _suggestions.take(6))
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.place_outlined, color: Brand.navy),
                                        title: Text(
                                          '${p['display'] ?? p['name'] ?? p['address'] ?? ''}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        onTap: () => _pick(p),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                dateBtn(today, 'Hôm nay'),
                                const SizedBox(width: 8),
                                dateBtn(tomorrow, 'Ngày mai'),
                                const SizedBox(width: 8),
                                SelectTile(
                                  selected: custom,
                                  padding: EdgeInsets.symmetric(horizontal: custom ? 10 : 14, vertical: custom ? 9 : 14),
                                  onTap: _pickDate,
                                  child: custom
                                      ? Column(
                                          children: [
                                            const Text(
                                              'Ngày đi',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Brand.navy),
                                            ),
                                            Text(
                                              DateFormat('dd/MM').format(_date),
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Brand.navy),
                                            ),
                                          ],
                                        )
                                      : const Icon(Icons.calendar_month_rounded, color: Brand.navy, semanticLabel: 'Chọn ngày khác'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                              decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const FieldLabel('Số khách'),
                                        Text('$_pax người', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                  QtyStepper(value: _pax, onChanged: (v) => setState(() => _pax = v)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            PrimaryCta(label: 'Tìm chuyến', icon: Icons.search_rounded, loading: _loading, onPressed: _search),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                sliver: SliverList.list(
                  children: [
                    if (_result == null) ...[
                      const InfoBanner(
                        'Không cần chọn ghế — nhà xe giữ chỗ theo số khách.',
                        tone: Tone.brand,
                        icon: Icons.event_seat_outlined,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${items.length} chuyến · bán kính ${_result!['radiusKm']} km',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final (v, l) in const [('nearest', 'Điểm đón gần'), ('earliest', 'Sớm nhất'), ('cheapest', 'Giá thấp')])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(l),
                                  selected: _sort == v,
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    setState(() => _sort = v);
                                    _search();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_result!['distanceQuality'] != 'ROAD' && items.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Một số khoảng cách ước tính theo đường chim bay.',
                            style: TextStyle(color: Brand.inkMuted, fontSize: 12),
                          ),
                        ),
                      if (items.isEmpty)
                        const EmptyState(
                          icon: Icons.directions_bus_outlined,
                          title: 'Chưa có chuyến phù hợp',
                          message: 'Thử ngày khác, loại xe khác hoặc điểm đi gần bến hơn.',
                        ),
                      for (var i = 0; i < items.length; i++)
                        _ResultCard(item: Map<String, dynamic>.from(items[i]), pax: _pax, best: i == 0 && _sort == 'nearest'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.pax, this.best = false});
  final Map<String, dynamic> item;
  final int pax;
  final bool best;
  @override
  Widget build(BuildContext context) {
    final p = item['pickup'] as Map, d = item['dropoff'] as Map;
    String dist(Map s) => s['roadDistanceMeters'] != null ? _km(s['roadDistanceMeters']) : '~${_km(s['distanceMeters'])}';
    final name = '${item['carrierName']}';
    return BrandCard(
      margin: const EdgeInsets.only(top: 12),
      highlight: best ? Brand.lane : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CarrierCheckoutScreen(runId: item['runId'] as int, pickup: p['runStopId'] as int, dropoff: d['runStopId'] as int, pax: pax),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CarrierBadge(name, highlight: best),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${categoryLabel[item['vehicleCategory']] ?? ''} · ${item['routeName']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Brand.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (best)
                const StatusChip('Gần bạn nhất', tone: Tone.lane, dense: true)
              else if (item['availabilityLabel'] != null)
                StatusChip('${item['availabilityLabel']}', tone: Tone.success, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          TripTimeline(
            departTime: _time(p['pickupAt']),
            departPlace: '${p['name']}',
            arriveTime: _time(d['arriveAt']),
            arrivePlace: '${d['name']}',
            duration: _duration(p['pickupAt'], d['arriveAt']).isEmpty ? null : _duration(p['pickupAt'], d['arriveAt']),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            height: 1,
            child: DashedLine(axis: Axis.horizontal, color: Brand.b100, dash: 5, gap: 4, thickness: 1),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.place_outlined, size: 16, color: Brand.navy),
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Đón: ${p['name']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.ink),
                      ),
                      TextSpan(text: ' · cách ${dist(p)}'),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Brand.inkMuted),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _vnd(item['totalPrice']),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.navy),
                  ),
                  Text('${_vnd(item['unitPrice'])}/người', style: const TextStyle(fontSize: 11, color: Brand.inkMuted)),
                ],
              ),
            ],
          ),
        ],
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
  String? _policy;

  @override
  void initState() {
    super.initState();
    _prefillContact();
    CarrierApi.refundPolicy()
        .then((t) {
          if (mounted && t.isNotEmpty) setState(() => _policy = refundPolicyText(t));
        })
        .catchError((Object _) {});
    CarrierApi.run(widget.runId)
        .then((r) {
          if (mounted) setState(() => _run = r);
          _requote();
        })
        .catchError((Object e) {
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

  /// Điền sẵn tên/SĐT của tài khoản đang đăng nhập; khách vẫn sửa được nếu đặt hộ.
  Future<void> _prefillContact() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final name = prefs.getString('fullName') ?? '';
    final phone = prefs.getString('phone') ?? '';
    if (_name.text.isEmpty && name.isNotEmpty) _name.text = name;
    if (_phone.text.isEmpty && phone.isNotEmpty) _phone.text = phone;
  }

  Future<void> _requote() async {
    if (!mounted) return;
    // Đổi điểm/số người = lệnh đặt khác → khóa chống trùng mới.
    setState(() {
      _quote = null;
      _error = null;
      _key = CarrierApi.newIdempotencyKey();
    });
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

  Widget _stopPicker({required String label, required bool pickup, required List<Map> options, required int? value}) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$_pickup'),
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded, color: Brand.navy),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(padding: const EdgeInsets.all(16), child: pickup ? const PickupDot(size: 12) : const DropoffDot(size: 12)),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
      ),
      items: options
          .map(
            (s) => DropdownMenuItem(
              value: s['runStopId'] as int,
              child: Text(
                '${_time(pickup ? s['plannedDepartureAt'] : s['plannedArrivalAt'])} · ${s['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        if (pickup) {
          final seq = _stops.firstWhere((s) => s['runStopId'] == v)['sequence'] as int;
          final current = _stops.firstWhere((s) => s['runStopId'] == _dropoff, orElse: () => {'sequence': 0});
          setState(() {
            _pickup = v;
            if ((current['sequence'] as int) <= seq) _dropoff = (_stops.lastWhere((s) => s['canDropoff'] == true)['runStopId']) as int;
          });
        } else {
          setState(() => _dropoff = v);
        }
        _requote();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_run == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chọn chuyến')),
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: InfoBanner(_error!, tone: Tone.danger),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final pickupSeq = _stops.firstWhere((s) => s['runStopId'] == _pickup, orElse: () => {'sequence': 0})['sequence'] as int;
    final pickups = _stops.where((s) => s['canPickup'] == true).toList();
    final dropoffs = _stops.where((s) => s['canDropoff'] == true && (s['sequence'] as int) > pickupSeq).toList();
    final name = '${_run!['carrierName']}';
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đặt vé')),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x14041565), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_quote != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_vnd(_quote!['unitPrice'])} × ${_quote!['passengerCount']} người',
                            style: const TextStyle(color: Brand.inkMuted, fontSize: 13),
                          ),
                        ),
                        if (_quote!['availabilityLabel'] != null)
                          StatusChip('${_quote!['availabilityLabel']}', tone: Tone.success, dense: true),
                      ],
                    ),
                  ),
                PrimaryCta(
                  label: _busy ? 'Đang đặt...' : 'Đặt vé & thanh toán',
                  trailing: _quote == null ? null : _vnd(_quote!['totalAmount']),
                  loading: _busy,
                  onPressed: _quote == null ? null : _book,
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrandCard(
            child: Row(
              children: [
                _CarrierBadge(name, highlight: true, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        '${categoryLabel[_run!['vehicleCategory']] ?? ''} · ${_run!['routeName']}',
                        style: const TextStyle(color: Brand.inkMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Xuất bến ${_dayTime(_run!['plannedDepartureAt'])}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Điểm đón & trả'),
          _stopPicker(
            label: 'Điểm đón',
            pickup: true,
            options: pickups,
            value: pickups.any((s) => s['runStopId'] == _pickup) ? _pickup : null,
          ),
          const SizedBox(height: 10),
          _stopPicker(
            label: 'Điểm trả',
            pickup: false,
            options: dropoffs,
            value: dropoffs.any((s) => s['runStopId'] == _dropoff) ? _dropoff : null,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Brand.line),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Số hành khách', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                QtyStepper(
                  value: _pax,
                  onChanged: (v) {
                    setState(() => _pax = v);
                    _requote();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Thông tin liên hệ'),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Tên người liên hệ',
              hintText: 'Để trống: theo tài khoản',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              hintText: 'Để trống: theo tài khoản',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Ghi chú cho nhà xe', prefixIcon: Icon(Icons.edit_note_rounded)),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InfoBanner(_error!, tone: Tone.danger, icon: Icons.error_outline_rounded),
            ),
          if (_policy != null)
            InfoBanner('Hủy vé trước giờ đón — $_policy. Tiền hoàn vào ví Beluga.', tone: Tone.warning, icon: Icons.policy_outlined),
          const SizedBox(height: 8),
        ],
      ),
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
      setState(() {
        _b = b;
        _track = track;
        _error = null;
      });
      final fast = b['status'] == 'PENDING_PAYMENT' || b['status'] == 'PAYMENT_REVIEW' || track != null;
      if (fast != _fast) {
        _fast = fast;
        _schedule();
      }
    } on CarrierApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<bool> _confirm(String title, String body, String action, {bool danger = false}) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Brand.inkMuted),
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Không'),
            ),
            ElevatedButton(
              style: danger
                  ? ElevatedButton.styleFrom(backgroundColor: Brand.danger, minimumSize: const Size(64, 44))
                  : ElevatedButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _cancel() async {
    final b = _b!;
    final refund = b['cancelRefund'] as Map?;
    final ok = b['status'] == 'CONFIRMED' && refund != null
        ? await _confirm(
            'Hủy vé đã thanh toán?',
            'Còn khoảng ${(refund['hoursBeforePickup'] as num).floor()} giờ đến giờ đón: bạn được hoàn ${_vnd(refund['refundAmount'])} (${_pct(refund['refundPercent'])}) vào ví Beluga ngay. Không thể hoàn tác.',
            'Hủy vé',
            danger: true,
          )
        : await _confirm('Hủy đơn chưa thanh toán?', 'Đừng chuyển khoản sau khi hủy.', 'Hủy đơn', danger: true);
    if (!ok) return;
    try {
      await CarrierApi.cancel(widget.code);
      await _load();
      if (mounted) _toast(context, b['status'] == 'CONFIRMED' ? 'Đã hủy vé. Tiền hoàn (nếu có) đã vào ví Beluga.' : 'Đã hủy đơn.');
    } on CarrierApiException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  Future<void> _payWallet() async {
    final b = _b!;
    if (!await _confirm(
      'Thanh toán bằng ví Beluga?',
      'Trừ ${_vnd(b['totalAmount'])} từ ví (số dư ${_vnd(b['walletBalance'])}). Vé được xác nhận ngay; đừng chuyển khoản thêm.',
      'Thanh toán',
    )) {
      return;
    }
    try {
      await CarrierApi.payWallet(widget.code);
      await _load();
      if (mounted) _toast(context, 'Đã thanh toán bằng ví. Vé đã được xác nhận.');
    } on CarrierApiException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  Widget _copyTile(String label, String value, {String? raw}) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: raw == null
        ? null
        : () {
            Clipboard.setData(ClipboardData(text: raw));
            _toast(context, 'Đã sao chép $label.');
          },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FieldLabel(label),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
          if (raw != null) const Icon(Icons.copy_rounded, size: 18, color: Brand.b500),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Vé ${widget.code}')),
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: InfoBanner(_error!, tone: Tone.danger),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final run = b['run'] as Map, pickup = b['pickup'] as Map, dropoff = b['dropoff'] as Map;
    final pay = b['status'] == 'PENDING_PAYMENT' ? b['payment'] as Map? : null;
    final status = '${b['status']}';
    final track = _track;

    final ticket = BrandCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Mã vé'),
                          Text('${b['code']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ],
                      ),
                    ),
                    _statusChip(status),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      _CarrierBadge('${run['carrierName']}', highlight: true, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${run['carrierName']} · ${categoryLabel[run['vehicleCategory']] ?? ''}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              run['vehiclePlate'] != null ? 'Biển số ${run['vehiclePlate']} · ${run['routeName']}' : '${run['routeName']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Brand.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                RouteStops(
                  background: Colors.white,
                  padding: EdgeInsets.zero,
                  from: RouteStop(
                    label: 'Đón · ${_dayTime(pickup['pickupAt'])}',
                    title: '${pickup['name']}',
                    subtitle: '${pickup['address'] ?? ''}',
                  ),
                  to: RouteStop(label: 'Trả · ${_dayTime(dropoff['arriveAt'])}', title: '${dropoff['name']}'),
                ),
              ],
            ),
          ),
          const _TearLine(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${b['passengerCount']} khách${b['paymentMethod'] == 'WALLET' ? ' · Ví Beluga' : ''}',
                    style: const TextStyle(color: Brand.inkMuted, fontSize: 13),
                  ),
                ),
                Text(
                  _vnd(b['totalAmount']),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.navy),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(title: Text(track != null ? 'Theo dõi xe' : 'Vé của tôi')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (track != null) ...[
              _TrackingView(track: track, pickupId: pickup['id'] as int, dropoffId: dropoff['id'] as int),
              const SizedBox(height: 12),
            ],
            ticket,
            const SizedBox(height: 12),
            if (pay != null && b['walletBalance'] != null) ...[
              BrandCard(
                child: Row(
                  children: [
                    const IconTile(Icons.account_balance_wallet_outlined, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Số dư ví: ${_vnd(b['walletBalance'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          if ((b['walletBalance'] as num) < (b['totalAmount'] as num))
                            const Text(
                              'Chưa đủ để trả vé — vui lòng chuyển khoản bên dưới.',
                              style: TextStyle(fontSize: 12, color: Brand.inkMuted),
                            ),
                        ],
                      ),
                    ),
                    if ((b['walletBalance'] as num) >= (b['totalAmount'] as num))
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(64, 44)),
                        onPressed: _payWallet,
                        child: const Text('Trả bằng ví'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (pay != null)
              BrandCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hoặc chuyển khoản để xác nhận vé', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    InfoBanner('Hạn thanh toán: ${_dayTime(pay['expiresAt'])}', tone: Tone.warning, icon: Icons.timer_outlined),
                    if (pay['qrImageUrl'] != null)
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 14),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Brand.line, width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network('${pay['qrImageUrl']}', width: 220, height: 220),
                          ),
                        ),
                      ),
                    _copyTile('Số tiền', _vnd(pay['amount']), raw: '${pay['amount']}'),
                    _copyTile(
                      'Nội dung chuyển khoản',
                      '${pay['transferContent'] ?? pay['paymentCode']}',
                      raw: '${pay['transferContent'] ?? pay['paymentCode']}',
                    ),
                    _copyTile('Số tài khoản', '${pay['accountNumber']} (${pay['bankCode']})', raw: '${pay['accountNumber']}'),
                    _copyTile('Chủ tài khoản', '${pay['accountName']}'),
                    const SizedBox(height: 6),
                    const Text(
                      'Chuyển đúng số tiền và nội dung. Vé tự xác nhận khi ngân hàng báo có.',
                      style: TextStyle(fontSize: 12, color: Brand.inkMuted),
                    ),
                  ],
                ),
              ),
            if (status == 'PAYMENT_REVIEW')
              const InfoBanner(
                'Giao dịch đang được đối soát, hỗ trợ sẽ liên hệ bạn.',
                tone: Tone.warning,
              ),
            if (b['refundAmount'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InfoBanner(
                  (b['refundAmount'] as num) > 0
                      ? 'Đã hoàn ${_vnd(b['refundAmount'])} (${_pct(b['refundPercent'])}) vào ví Beluga.'
                      : 'Vé hủy sát giờ đón nên không được hoàn tiền theo chính sách.',
                  tone: Tone.info,
                  icon: Icons.undo_rounded,
                ),
              ),
            if (track == null && (status == 'CONFIRMED' || status == 'BOARDED'))
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: InfoBanner('Theo dõi vị trí xe mở 60 phút trước giờ đón.', tone: Tone.brand, icon: Icons.map_outlined),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (run['carrierPhone'] != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:${run['carrierPhone']}')),
                      icon: const Icon(Icons.phone_rounded, size: 20),
                      label: const Text('Gọi nhà xe'),
                    ),
                  ),
                if (run['carrierPhone'] != null && (pay != null || (status == 'CONFIRMED' && b['cancelRefund'] != null)))
                  const SizedBox(width: 10),
                if (pay != null || (status == 'CONFIRMED' && b['cancelRefund'] != null))
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Brand.danger,
                        side: const BorderSide(color: Color(0xFFF3C2C2), width: 1.5),
                        minimumSize: const Size(64, 52),
                      ),
                      onPressed: _cancel,
                      child: Text(pay != null ? 'Hủy đơn' : 'Hủy vé'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Đường xé vé: nét đứt + hai khuyết tròn hai bên.
class _TearLine extends StatelessWidget {
  const _TearLine();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 2,
            child: DashedLine(axis: Axis.horizontal, color: Brand.b100, dash: 6, gap: 5),
          ),
        ),
        Positioned(
          left: -10,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: Brand.canvas, shape: BoxShape.circle),
          ),
        ),
        Positioned(
          right: -10,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: Brand.canvas, shape: BoxShape.circle),
          ),
        ),
      ],
    ),
  );
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
    final delay = (track['delayMinutes'] as num?) ?? 0;
    final pickupEta = pickup['actualArrivalAt'] == null ? _dt(pickup['estimatedArrivalAt'] ?? pickup['plannedArrivalAt']) : null;
    final minutes = pickupEta?.difference(DateTime.now()).inMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 300,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: vehicle ?? at(pickup),
                    initialZoom: 13,
                    backgroundColor: Brand.mapLand,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    trackAsiaTileLayer(),
                    PolylineLayer(
                      polylines: [Polyline(points: stops.map(at).toList(), strokeWidth: 4, color: Brand.navy.withValues(alpha: 0.55))],
                    ),
                    MarkerLayer(
                      markers: [
                        ...stops
                            .where((s) => s['id'] == pickupId || s['id'] == dropoffId)
                            .map(
                              (s) => Marker(
                                point: at(s),
                                width: 24,
                                height: 24,
                                child: s['id'] == dropoffId ? const PlaceMarker.dropoff() : const PlaceMarker.pickup(),
                              ),
                            ),
                        ...stops
                            .where((s) => s['id'] != pickupId && s['id'] != dropoffId)
                            .map(
                              (s) => Marker(
                                point: at(s),
                                width: 12,
                                height: 12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Brand.b400, width: 3),
                                  ),
                                ),
                              ),
                            ),
                        if (vehicle != null) Marker(point: vehicle, width: 38, height: 38, child: const VehicleMarker(size: 36)),
                      ],
                    ),
                    trackAsiaAttribution(),
                  ],
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 10,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(999), boxShadow: Brand.ctaShadow),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: signal == 'LIVE' ? const Color(0xFF4ADE80) : Brand.lane, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (minutes != null && minutes > 0) ...[
                                  const TextSpan(text: 'Xe tới điểm đón sau '),
                                  TextSpan(
                                    text: '$minutes phút',
                                    style: const TextStyle(color: Brand.lane),
                                  ),
                                ] else if (pickup['actualArrivalAt'] != null)
                                  const TextSpan(text: 'Xe đã qua điểm đón của bạn')
                                else
                                  const TextSpan(text: 'Xe sắp tới điểm đón'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        Text(
                          signal == 'LIVE'
                              ? (loc != null ? '${loc['ageSeconds']}s' : '')
                              : signal == 'STALE'
                              ? 'Mất tín hiệu'
                              : 'Chưa có GPS',
                          style: const TextStyle(color: Brand.b200, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (delay > 0) ...[
          const SizedBox(height: 10),
          InfoBanner('Xe trễ khoảng $delay phút so với lịch.', tone: Tone.warning, icon: Icons.schedule_rounded),
        ],
        const SizedBox(height: 12),
        BrandCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lộ trình xe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              for (var i = 0; i < stops.length; i++)
                _StopRow(
                  stop: stops[i],
                  last: i == stops.length - 1,
                  mine: stops[i]['id'] == pickupId
                      ? 'Điểm đón của bạn'
                      : stops[i]['id'] == dropoffId
                      ? 'Điểm trả của bạn'
                      : null,
                ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Giờ dự kiến chưa tính kẹt xe.',
                  style: TextStyle(fontSize: 11, color: Brand.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.last, this.mine});
  final Map stop;
  final bool last;
  final String? mine;
  @override
  Widget build(BuildContext context) {
    final done = stop['actualArrivalAt'] != null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: done ? Brand.success : Colors.white,
                  shape: BoxShape.circle,
                  border: done ? null : Border.all(color: mine != null ? Brand.navy : Brand.b200, width: 3),
                ),
                child: done ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
              if (!last) Expanded(child: Container(width: 2, color: done ? Brand.success : Brand.b100)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${stop['name']}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: done || mine != null ? Brand.ink : Brand.inkMuted),
                        ),
                      ),
                      if (mine != null) ...[const SizedBox(width: 6), StatusChip(mine!, tone: Tone.brand, dense: true)],
                    ],
                  ),
                  Text(
                    done
                        ? 'Đã đến ${_time(stop['actualArrivalAt'])}'
                        : 'Dự kiến ${_time(stop['estimatedArrivalAt'] ?? stop['plannedArrivalAt'])} (lịch ${_time(stop['plannedArrivalAt'])})',
                    style: const TextStyle(fontSize: 12, color: Brand.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    appBar: AppBar(title: const Text('Vé của tôi')),
    body: _items == null
        ? Center(
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: InfoBanner(_error!, tone: Tone.danger),
                  )
                : const CircularProgressIndicator(),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_items!.isEmpty)
                  const EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Chưa có vé nào',
                    message: 'Vé limousine và xe khách bạn đặt sẽ hiện ở đây.',
                  ),
                ..._items!.map((b) {
                  final p = b['pickup'] as Map, d = b['dropoff'] as Map, run = b['run'] as Map;
                  return BrandCard(
                    margin: const EdgeInsets.only(top: 12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CarrierTicketScreen(code: '${b['code']}')),
                    ).then((_) => _load()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _CarrierBadge('${run['carrierName']}'),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${run['carrierName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '${b['code']} · ${b['passengerCount']} khách',
                                    style: const TextStyle(fontSize: 12, color: Brand.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            _statusChip(b['status'], dense: true),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TripTimeline(
                          departTime: _time(p['pickupAt']),
                          departPlace: '${p['name']}',
                          arriveTime: _time(d['arriveAt']),
                          arrivePlace: '${d['name']}',
                          duration: DateFormat('dd/MM').format(_dt(p['pickupAt']) ?? DateTime.now()),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _vnd(b['totalAmount']),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.navy),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
  );
}
