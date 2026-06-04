import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking_model.dart';
import '../providers/home_provider.dart';
import 'beluca_home_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookingModel()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
      ],
      child: const HomeView(),
    );
  }
}
