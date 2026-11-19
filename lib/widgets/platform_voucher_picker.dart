import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class PlatformVoucherPicker extends StatefulWidget {
  const PlatformVoucherPicker({
    super.key,
    required this.preview,
    required this.onChange,
    required this.onBusy,
    this.disabled = false,
  });

  final Future<Map<String, dynamic>> Function(String code, int? replacementId)
  preview;
  final ValueChanged<Map<String, dynamic>?> onChange;
  final ValueChanged<bool> onBusy;
  final bool disabled;

  @override
  State<PlatformVoucherPicker> createState() => _PlatformVoucherPickerState();
}

class _PlatformVoucherPickerState extends State<PlatformVoucherPicker> {
  final _code = TextEditingController();
  Map<String, dynamic>? _quote;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply(String code, [int? replacementId]) async {
    if (_busy || widget.disabled || code.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusy(true);
    try {
      final quote = await widget.preview(code.trim(), replacementId);
      if (!mounted) return;
      setState(() => _quote = quote);
      widget.onChange(quote);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusy(false);
      }
    }
  }

  Future<void> _openCatalog() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('accessToken');
    if (!mounted || token == null) return;
    final selected =
        await showModalBottomSheet<({String code, int? replacementId})>(
          context: context,
          isScrollControlled: true,
          builder: (context) => _VoucherCatalog(token: token),
        );
    if (mounted && selected != null)
      await _apply(selected.code, selected.replacementId);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _code,
              enabled: !_busy && !widget.disabled,
              decoration: const InputDecoration(
                labelText: 'Mã ưu đãi Đông Dương',
              ),
            ),
          ),
          TextButton(
            onPressed: _busy || widget.disabled
                ? null
                : () => _apply(_code.text),
            child: const Text('Áp dụng'),
          ),
        ],
      ),
      TextButton(
        onPressed: _busy || widget.disabled ? null : _openCatalog,
        child: const Text('Kho ưu đãi'),
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_quote case final quote?)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${quote['code']} · ${quote['title']}'),
          trailing: TextButton(
            onPressed: _busy || widget.disabled
                ? null
                : () {
                    setState(() => _quote = null);
                    widget.onChange(null);
                  },
            child: const Text('Bỏ mã'),
          ),
        ),
    ],
  );
}

class _VoucherCatalog extends StatefulWidget {
  const _VoucherCatalog({required this.token});
  final String token;

  @override
  State<_VoucherCatalog> createState() => _VoucherCatalogState();
}

class _VoucherCatalogState extends State<_VoucherCatalog> {
  late Future<List<Map<String, dynamic>>> _items = _load();
  int? _claiming;
  String? _error;

  Future<List<Map<String, dynamic>>> _load() async {
    final responses = await Future.wait([
      ApiService.voucherData(widget.token, 'voucher-catalog'),
      ApiService.voucherData(widget.token, 'replacement-vouchers'),
    ]);
    return [
      for (final item in (responses[0]['items'] as List? ?? []))
        {...(item as Map).cast<String, dynamic>(), 'replacement': false},
      for (final item in (responses[1]['items'] as List? ?? []))
        {...(item as Map).cast<String, dynamic>(), 'replacement': true},
    ];
  }

  Future<void> _claim(int id) async {
    setState(() {
      _claiming = id;
      _error = null;
    });
    try {
      await ApiService.voucherData(
        widget.token,
        'voucher-catalog/$id/claim',
        post: true,
      );
      if (!mounted) return;
      final items = _load();
      setState(() {
        _items = items;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .55,
      child: FutureBuilder(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty)
            return const Center(child: Text('Chưa có ưu đãi khả dụng.'));
          return ListView(
            children: [
              if (_error != null) ListTile(title: Text(_error!)),
              for (final item in snapshot.data!)
                ListTile(
                  title: Text('${item['code']} · ${item['title']}'),
                  trailing:
                      item['requireClaim'] == true && item['saved'] != true
                      ? TextButton(
                          onPressed: _claiming == null
                              ? () => _claim(item['id'] as int)
                              : null,
                          child: const Text('Lưu mã'),
                        )
                      : TextButton(
                          onPressed: () => Navigator.pop(context, (
                            code: item['code'] as String,
                            replacementId: item['replacement'] == true
                                ? item['id'] as int
                                : null,
                          )),
                          child: const Text('Dùng mã'),
                        ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
