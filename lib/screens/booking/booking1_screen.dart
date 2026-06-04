import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/booking_model.dart';
import '../../models/location_models.dart';
import 'booking2_screen.dart';
import 'booking_address_map_picker_screen.dart';
import 'booking_ui.dart';

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
      hintStyle: const TextStyle(color: Color(0xFF7D8D88)),
      prefixIcon: Icon(icon, color: iconColor, size: 20),
      suffixIcon: suffixIcon,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
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
        color: Color(0xFF123C2E),
        fontWeight: FontWeight.w600,
        fontSize: 15.5,
      ),
      cursorColor: Theme.of(context).colorScheme.secondary,
      decoration: _addressFieldDecoration(
        context: context,
        hint: hint,
        icon: icon,
        iconColor: iconColor,
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : controller.text.trim().isNotEmpty
            ? IconButton(
                onPressed: onClearSelection,
                icon: const Icon(Icons.close_rounded, color: Color(0xFF50635D)),
              )
            : null,
      ),
    );
  }

  Widget _buildSuggestionList(BuildContext context, BookingModel model) {
    final theme = Theme.of(context);
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
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        primary: false,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
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
            },
            leading: Icon(
              Icons.location_on_outlined,
              color: theme.colorScheme.secondary,
            ),
            title: Text(
              suggestion.primaryText,
              style: const TextStyle(
                color: Color(0xFF123C2E),
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
              ),
            ),
            subtitle: suggestion.secondaryText.isEmpty
                ? null
                : Text(
                    suggestion.secondaryText,
                    style: const TextStyle(
                      color: Color(0xFF50635D),
                      fontSize: 12.5,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMapShortcut({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldActions({
    required BuildContext context,
    required BookingModel model,
    required bool isPickup,
  }) {
    final hasSelection = isPickup
        ? model.hasPickupSelection
        : model.hasDropSelection;
    final isFavorite = model.isCurrentSelectionFavorite(isPickup: isPickup);

    return Wrap(
      spacing: 18,
      runSpacing: 0,
      children: [
        _buildMapShortcut(
          context: context,
          label: 'Chọn trên bản đồ',
          icon: Icons.map_outlined,
          onTap: () => _pickPointOnMap(context, model, isPickup: isPickup),
        ),
        if (hasSelection)
          _buildMapShortcut(
            context: context,
            label: isFavorite ? 'Đã lưu' : 'Lưu yêu thích',
            icon: isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            onTap: () => model.toggleFavoriteForSelection(isPickup: isPickup),
          ),
      ],
    );
  }

  Widget _buildSavedCollectionHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF123C2E),
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
    final theme = Theme.of(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          dismissBookingKeyboard();
          model.closeAutocompleteSuggestions();
          model.applySavedRoute(route);
          _pickupFocusNode.unfocus();
          _dropFocusNode.unfocus();
          setState(() => _isPickupActive = false);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
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
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.route_rounded,
                      size: 18,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildRoutePointLine(
                icon: Icons.trip_origin_rounded,
                color: const Color(0xFF3D7DFF),
                text: route.pickup.title,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 1.5,
                  height: 14,
                  color: Colors.black.withValues(alpha: 0.10),
                ),
              ),
              const SizedBox(height: 8),
              _buildRoutePointLine(
                icon: Icons.location_on_rounded,
                color: const Color(0xFF16B26A),
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
              color: Color(0xFF123C2E),
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
    final theme = Theme.of(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
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
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.history_rounded,
                  color: theme.colorScheme.secondary,
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
                        color: Color(0xFF123C2E),
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
                          color: Color(0xFF6B7B76),
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
                  color: theme.colorScheme.secondary,
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
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (!model.hasDropSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn điểm đến'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final routeValidationMessage = model.validateRouteSelection();
    if (routeValidationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(routeValidationMessage),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  void _goNext(BookingModel model) {
    dismissBookingKeyboard();
    model.closeAutocompleteSuggestions();

    if (!_validate(model)) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: model,
          child: Booking2Screen(onRideBooked: widget.onRideBooked),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BookingModel>();
    final theme = Theme.of(context);
    final activeLoading = _isPickupActive
        ? model.loadingPickupSuggestions
        : model.loadingDropSuggestions;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chọn địa chỉ',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => _goNext(model),
              child: Text(
                'Tiếp theo',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: BookingKeyboardDismissArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7F6F1), Color(0xFFEAF1ED)],
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
                            color: Colors.white.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildAddressField(
                                context: context,
                                model: model,
                                isPickup: true,
                                focusNode: _pickupFocusNode,
                                controller: model.pickupAddressController,
                                hint: 'Điểm đón',
                                icon: Icons.local_taxi_outlined,
                                iconColor: const Color(0xFF3D7DFF),
                                isLoading: _isPickupActive && activeLoading,
                                onClearSelection: model.clearPickupSelection,
                              ),
                              _buildFieldActions(
                                context: context,
                                model: model,
                                isPickup: true,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Material(
                                    color: theme.colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      onTap: model.swapRoutePoints,
                                      borderRadius: BorderRadius.circular(14),
                                      child: const SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: Icon(
                                          Icons.swap_vert_rounded,
                                          color: AppColors.primaryGreen,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _buildAddressField(
                                context: context,
                                model: model,
                                isPickup: false,
                                focusNode: _dropFocusNode,
                                controller: model.dropAddressController,
                                hint: 'Điểm đến',
                                icon: Icons.local_taxi_outlined,
                                iconColor: const Color(0xFF16B26A),
                                isLoading: !_isPickupActive && activeLoading,
                                onClearSelection: model.clearDropSelection,
                              ),
                              _buildFieldActions(
                                context: context,
                                model: model,
                                isPickup: false,
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
