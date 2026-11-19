import 'package:flutter/material.dart';

import '../ui/ui.dart';

class TripInsuranceOption extends StatefulWidget {
  const TripInsuranceOption({super.key});

  @override
  State<TripInsuranceOption> createState() => _TripInsuranceOptionState();
}

class _TripInsuranceOptionState extends State<TripInsuranceOption> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      padding: EdgeInsets.zero,
      child: CheckboxListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: const IconTile(Icons.shield_outlined),
        title: const Text(
          'Bảo hiểm chuyến đi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        value: _selected,
        onChanged: (value) => setState(() => _selected = value ?? false),
      ),
    );
  }
}
