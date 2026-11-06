import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../features/carrier/carrier_screens.dart';
import '../../models/booking_model.dart';
import '../../models/location_models.dart';
import 'booking2_screen.dart';
import 'booking_address_map_picker_screen.dart';
import 'booking_ui.dart';
import '../../ui/ui.dart';

class Booking1Screen extends StatefulWidget {
  final Function(int) onRideBooked;

  const Booking1Screen({super.key, required this.onRideBooked});

  @override
  State<Booking1Screen> createState() => _Booking1ScreenState();
}

class _Booking1ScreenState extends State<Booking1Screen> {
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropFocusNode = FocusNode();
  bool _isPickupActive = true;
  bool _isNavigatingNext = false;

  @override
  void initState() {
    super.initState();
    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus && !_isPickupActive) {
        setState(() => _isPickupActive = true);
      }
    });
    _dropFocusNode.addListener(() {
      if (_dropFocusNode.hasFocus && _isPickupActive) {
        setState(() => _isPickupActive = false);
      }
    });
  }

  @override
  void dispose() {
    _pickupFocusNode.dispose();
    _dropFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _addressFieldDecoration({
    required BuildContext context,
    required String hint,
    required IconData icon,
    required Color iconColor,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Brand.inkSubtle),
      prefixIcon: Icon(icon, color: iconColor, size: 20),
      suffixIcon: suffixIcon,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Brand.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Brand.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Brand.navy,
          width: 1.6,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Future<void> _pickPointOnMap(
    BuildContext context,
    BookingModel model, {
    required bool isPickup,
  }) async {
    dismissBookingKeyboard();
    model.closeAutocompleteSuggestions();

    final initialPoint = isPickup
        ? model.selectedPickupPoint
        : model.selectedDropPoint;

    final resolved = await Navigator.push<AddressResolvedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingAddressMapPickerScreen(
          title: isPickup
              ? 'Chọn điểm đón trên bản đồ'
              : 'Chọn điểm đến trên bản đồ',
          initialPoint: initialPoint,
        ),
      ),
    );

    if (resolved == null) return;

    if (isPickup) {
      model.selectPickupMapLocation(resolved);
      setState(() => _isPickupActive = true);
    } else {
      model.selectDropMapLocation(resolved);
      setState(() => _isPickupActive = false);
    }

    await _maybeAutoAdvance(model);
  }

  bool _canAutoAdvance(BookingModel model) {
    return model.hasPickupSelection &&
        model.hasDropSelection &&
        model.validateRouteSelection() == null;
  }

  Future<void> _maybeAutoAdvance(BookingModel model) async {
    if (!_canAutoAdvance(model) || _isNavigatingNext || !mounted) return;
    await _goNext(model);
  }

  Widget _buildAddressField({
    required BuildContext context,
    required BookingModel model,
    required bool isPickup,
    required FocusNode focusNode,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required bool isLoading,
    required VoidCallback onClearSelection,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onTap: () => setState(() => _isPickupActive = isPickup),
      onChanged: (value) {
        setState(() => _isPickupActive = isPickup);
        model.onAddressTextChanged(isPickup: isPickup, query: value);
      },
      onTapOutside: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      style: const TextStyle(
        color: Brand.navy,
        fontWeight: FontWeight.w600,
        fontSize: 15.5,
      ),
      cursorColor: Brand.navy,
      decoration: _addressFieldDecoration(
        context: context,
        hint: hint,
        icon: icon,
        iconColor: iconColor,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (controller.text.trim().isNotEmpty)
              IconButton(
                tooltip: 'Xóa',
                onPressed: onClearSelection,
                icon: const Icon(Icons.close_rounded, color: Brand.inkMuted, size: 20),
              ),
            if ((isPickup ? model.hasPickupSelection : model.hasDropSelection))
              IconButton(
                tooltip: 'Lưu yêu thích',
                onPressed: () => model.toggleFavoriteForSelection(isPickup: isPickup),
                icon: Icon(
                  model.isCurrentSelectionFavorite(isPickup: isPickup) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: Brand.navy,
                  size: 20,
                ),
              )
            else
              IconButton(
                tooltip: 'Chọn trên bản đồ',
                onPressed: () => _pickPointOnMap(context, model, isPickup: isPickup),
                icon: const Icon(Icons.map_outlined, color: Brand.navy, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionList(BuildContext context, BookingModel model) {
    final suggestions = _isPickupActive
        ? model.pickupSuggestions
        : model.dropSuggestions;

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Brand.line),
      ),
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        primary: false,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Brand.lineSoft),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ListTile(
            dense: true,
            onTap: () {
              if (_isPickupActive) {
                model.selectPickupSuggestion(suggestion);
                _pickupFocusNode.unfocus();
              } else {
                model.selectDropSuggestion(suggestion);
                _dropFocusNode.unfocus();
              }
              _maybeAutoAdvance(model);
            },
            leading: Icon(
              Icons.location_on_outlined,
              color: Brand.navy,
            ),
            title: Text(
              suggestion.primaryText,
              style: const TextStyle(
                color: Brand.navy,
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
              ),
            ),
            subtitle: suggestion.secondaryText.isEmpty
                ? null
                : Text(
                    suggestion.secondaryText,
                    style: const TextStyle(
                      color: Brand.inkMuted,
                      fontSize: 12.5,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSavedCollectionHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Brand.navy),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Brand.navy,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(
    BuildContext context,
    BookingSavedRoute route,
    BookingModel model,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          dismissBookingKeyboard();
          model.closeAutocompleteSuggestions();
          model.applySavedRoute(route);
          _pickupFocusNode.unfocus();
          _dropFocusNode.unfocus();
          setState(() => _isPickupActive = false);
          _maybeAutoAdvance(model);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Brand.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Brand.navy.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.route_rounded,
                      size: 18,
                      color: Brand.navy,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: Brand.navy,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildRoutePointLine(
                icon: Icons.trip_origin_rounded,
                color: Brand.navy,
                text: route.pickup.title,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 1.5,
                  height: 14,
                  color: const Color(0x1A041565),
                ),
              ),
              const SizedBox(height: 8),
              _buildRoutePointLine(
                icon: Icons.location_on_rounded,
                color: Brand.success,
                text: route.drop.title,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutePointLine({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Brand.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedPlaceCard(
    BuildContext context,
    BookingSavedPlace place,
    BookingModel model, {
    required bool isFavorite,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          dismissBookingKeyboard();
          model.closeAutocompleteSuggestions();
          model.applySavedPlace(place, isPickup: _isPickupActive);
          if (_isPickupActive) {
            _pickupFocusNode.unfocus();
          } else {
            _dropFocusNode.unfocus();
          }
          _maybeAutoAdvance(model);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Brand.line),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Brand.navy.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.history_rounded,
                  color: Brand.navy,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Brand.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (place.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Brand.inkMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => model.toggleFavoritePlace(place),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  model.favoritePlaces.any(
                        (item) => item.identityKey == place.identityKey,
                      )
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: Brand.navy,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedCollections(BuildContext context, BookingModel model) {
    final activeText =
        (_isPickupActive
                ? model.pickupAddressController.text
                : model.dropAddressController.text)
            .trim();
    final activeSuggestions = _isPickupActive
        ? model.pickupSuggestions
        : model.dropSuggestions;
    final hasActiveSelection = _isPickupActive
        ? model.hasPickupSelection
        : model.hasDropSelection;

    if (activeSuggestions.isNotEmpty) {
      return const SizedBox.shrink();
    }

    if (activeText.isNotEmpty && !hasActiveSelection) {
      return const SizedBox.shrink();
    }

    if (model.recentRoutes.isEmpty &&
        model.favoritePlaces.isEmpty &&
        model.recentPlaces.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (model.recentRoutes.isNotEmpty) ...[
          _buildSavedCollectionHeader(
            context: context,
            title: 'Tuyến quen',
            icon: Icons.route_rounded,
          ),
          const SizedBox(height: 10),
          ...model.recentRoutes
              .take(3)
              .map(
                (route) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildRouteCard(context, route, model),
                ),
              ),
        ],
        if (model.favoritePlaces.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildSavedCollectionHeader(
            context: context,
            title: 'Yêu thích',
            icon: Icons.favorite_rounded,
          ),
          const SizedBox(height: 10),
          ...model.favoritePlaces
              .take(4)
              .map(
                (place) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildSavedPlaceCard(
                    context,
                    place,
                    model,
                    isFavorite: true,
                  ),
                ),
              ),
        ],
        if (model.recentPlaces.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildSavedCollectionHeader(
            context: context,
            title: 'Gần đây',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 10),
          ...model.recentPlaces
              .take(4)
              .map(
                (place) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildSavedPlaceCard(
                    context,
                    place,
                    model,
                    isFavorite: false,
                  ),
                ),
              ),
        ],
      ],
    );
  }

  bool _validate(BookingModel model) {
    if (!model.hasPickupSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn điểm đón'),
          backgroundColor: Brand.danger,
        ),
      );
      return false;
    }

    if (!model.hasDropSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn điểm đến'),
          backgroundColor: Brand.danger,
        ),
      );
      return false;
    }

    final routeValidationMessage = model.validateRouteSelection();
    if (routeValidationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(routeValidationMessage),
          backgroundColor: Brand.danger,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _goNext(BookingModel model) async {
    if (_isNavigatingNext || !mounted) return;

    dismissBookingKeyboard();
    model.closeAutocompleteSuggestions();

    if (!_validate(model)) return;

    setState(() => _isNavigatingNext = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: model,
            child: Booking2Screen(onRideBooked: widget.onRideBooked),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isNavigatingNext = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BookingModel>();
    final activeLoading = _isPickupActive
        ? model.loadingPickupSuggestions
        : model.loadingDropSuggestions;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chọn địa chỉ',
          style: TextStyle(color: Brand.navy),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Brand.navy),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isNavigatingNext ? null : () => _goNext(model),
              child: Text(
                'Tiếp theo',
                style: TextStyle(
                  color: Brand.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
        // 3 lựa chọn dịch vụ: Xe ghép (luồng hiện tại) / Xe limousine / Xe khách (nhà xe đối tác).
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                for (final (label, category) in const [
                  ('Xe ghép', null),
                  ('Xe limousine', 'LIMOUSINE'),
                  ('Xe khách', 'COACH'),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: SizedBox(width: double.infinity, child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1))),
                        selected: category == null,
                        showCheckmark: false,
                        onSelected: category == null
                            ? (_) {}
                            : (_) => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CarrierSearchScreen(category: category)),
                                ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: BookingKeyboardDismissArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Brand.canvas, Brand.canvas],
            ),
          ),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0x1A041565),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x1A041565),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildAddressField(
                                      context: context,
                                      model: model,
                                      isPickup: true,
                                      focusNode: _pickupFocusNode,
                                      controller: model.pickupAddressController,
                                      hint: 'Điểm đón',
                                      icon: Icons.trip_origin_rounded,
                                      iconColor: Brand.navy,
                                      isLoading: _isPickupActive && activeLoading,
                                      onClearSelection: model.clearPickupSelection,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildAddressField(
                                      context: context,
                                      model: model,
                                      isPickup: false,
                                      focusNode: _dropFocusNode,
                                      controller: model.dropAddressController,
                                      hint: 'Điểm đến',
                                      icon: Icons.place_rounded,
                                      iconColor: Brand.lane500,
                                      isLoading: !_isPickupActive && activeLoading,
                                      onClearSelection: model.clearDropSelection,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Đảo chiều',
                                style: IconButton.styleFrom(backgroundColor: Brand.b50, fixedSize: const Size(44, 44)),
                                onPressed: () {
                                  model.swapRoutePoints();
                                  _maybeAutoAdvance(model);
                                },
                                icon: const Icon(Icons.swap_vert_rounded, color: Brand.navy),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildSuggestionList(context, model),
                        if ((_isPickupActive
                                    ? model.pickupSuggestions
                                    : model.dropSuggestions)
                                .isNotEmpty ==
                            false) ...[
                          const SizedBox(height: 12),
                          _buildSavedCollections(context, model),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
