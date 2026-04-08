import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking_model.dart';
import 'beluca_home_view.dart'; // <-- FILE BỔ SUNG mới

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BookingModel(),
      child: const HomeView(),
    );
  }
}