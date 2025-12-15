// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../models/booking_model.dart';
// import 'activity_screen.dart';
// import 'profile_screen.dart';
//
// class HomeScreen extends StatelessWidget {
//   const HomeScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => BookingModel(),
//       child: const _HomeView(),
//     );
//   }
// }
//
// class _HomeView extends StatefulWidget {
//   const _HomeView();
//
//   @override
//   State<_HomeView> createState() => _HomeViewState();
// }
//
// class _HomeViewState extends State<_HomeView> {
//   int _selectedIndex = 0;
//
//   @override
//   Widget build(BuildContext context) {
//     final model = context.watch<BookingModel>();
//
//     return Scaffold(
//       appBar: _selectedIndex == 2
//           ? null
//           : AppBar(
//         title: const Text('BeluCar'),
//         centerTitle: true,
//       ),
//       body: _buildBody(model),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _selectedIndex,
//         onTap: (i) => setState(() => _selectedIndex = i),
//         items: const [
//           BottomNavigationBarItem(
//               icon: Icon(Icons.directions_car), label: 'Đặt chuyến'),
//           BottomNavigationBarItem(
//               icon: Icon(Icons.access_time_filled), label: 'Hoạt động'),
//           BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBody(BookingModel model) {
//     switch (_selectedIndex) {
//       case 0:
//         return _buildBookingForm(model);
//       case 1:
//         return const ActivityScreen();
//       case 2:
//         return const ProfileScreen();
//       default:
//         return const SizedBox();
//     }
//   }
//
//   // =================== BOOKING FORM ======================
//   Widget _buildBookingForm(BookingModel model) {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text("Đặt chuyến mới",
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 20),
//
//             // ---------- Điểm đón ----------
//             const Text("Điểm đón",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//             const SizedBox(height: 10),
//
//             _provinceDropdown(
//               provinces: model.provinces,
//               value: model.selectedProvincePickup,
//               onChanged: (v) {
//                 model.selectedProvincePickup = v;
//                 model.selectedDistrictPickup = null;
//                 model.fetchDistricts(v, true);
//               },
//             ),
//             const SizedBox(height: 12),
//
//             _districtDropdown(
//               districts: model.districtsPickup,
//               value: model.selectedDistrictPickup,
//               onChanged: (v) {
//                 model.selectedDistrictPickup = v;
//                 model.notifyListeners();
//               },
//             ),
//             const SizedBox(height: 12),
//
//             TextField(
//               decoration: const InputDecoration(
//                 prefixIcon: Icon(Icons.location_on_outlined),
//                 labelText: "Địa chỉ cụ thể",
//                 border: OutlineInputBorder(),
//               ),
//               onChanged: (v) {
//                 model.addressPickup = v;
//               },
//             ),
//             const SizedBox(height: 30),
//
//             // ---------- Điểm đến ----------
//             const Text("Điểm đến",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//             const SizedBox(height: 10),
//
//             _provinceDropdown(
//               provinces: model.provinces,
//               value: model.selectedProvinceDrop,
//               onChanged: (v) {
//                 model.selectedProvinceDrop = v;
//                 model.selectedDistrictDrop = null;
//                 model.fetchDistricts(v, false);
//               },
//             ),
//             const SizedBox(height: 12),
//
//             _districtDropdown(
//               districts: model.districtsDrop,
//               value: model.selectedDistrictDrop,
//               onChanged: (v) {
//                 model.selectedDistrictDrop = v;
//                 model.notifyListeners();
//               },
//             ),
//             const SizedBox(height: 12),
//
//             TextField(
//               decoration: const InputDecoration(
//                 prefixIcon: Icon(Icons.location_on_outlined),
//                 labelText: "Địa chỉ cụ thể",
//                 border: OutlineInputBorder(),
//               ),
//               onChanged: (v) {
//                 model.addressDrop = v;
//               },
//             ),
//             const SizedBox(height: 30),
//
//             // ---------- Số điện thoại ----------
//             TextField(
//               decoration: const InputDecoration(
//                 labelText: "Số điện thoại liên hệ",
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.phone),
//               ),
//             ),
//             const SizedBox(height: 12),
//
//             // ---------- Ghi chú ----------
//             TextField(
//               maxLines: 4,
//               decoration: const InputDecoration(
//                 labelText: "Ghi chú cho tài xế ",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//
//             // ---------- Ngày + giờ ----------
//             _dateTimePicker(model),
//             const SizedBox(height: 20),
//
//             // ---------- Khứ hồi ----------
//             Row(
//               children: [
//                 Checkbox(
//                   value: model.isKhuHoi,
//                   onChanged: (v) {
//                     model.isKhuHoi = v ?? false;
//                     model.notifyListeners();
//                   },
//                 ),
//                 const Text("Thêm chuyến khứ hồi"),
//               ],
//             ),
//
//             if (model.isKhuHoi) _returnTrip(model),
//             const SizedBox(height: 20),
//
//             // ---------- Bao xe ----------
//             Row(
//               children: [
//                 Checkbox(
//                   value: model.isBaoXe,
//                   onChanged: (v) {
//                     model.isBaoXe = v ?? false;
//                     model.notifyListeners();
//                   },
//                 ),
//                 const Text("Bao xe"),
//                 IconButton(
//                   icon: const Icon(Icons.info_outline, color: Colors.blue),
//                   onPressed: () {
//                     showDialog(
//                       context: context,
//                       builder: (_) => AlertDialog(
//                         title: const Text("Bao xe là gì?"),
//                         content: const Text(
//                             "Bao xe nghĩa là thuê trọn chuyến — tài xế không ghép khách."),
//                         actions: [
//                           TextButton(
//                               onPressed: () => Navigator.pop(context),
//                               child: const Text("Đóng"))
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 20),
//
//             // ---------- Đặt chuyến ----------
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () {},
//                 child: const Text("Đặt chuyến"),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // =================== Widgets nhỏ tách riêng =====================
//
//   Widget _provinceDropdown({
//     required List<dynamic> provinces,
//     required String? value,
//     required void Function(String?) onChanged,
//   }) {
//     return DropdownButtonFormField<String>(
//       value: value,
//       isExpanded: true,
//       decoration: const InputDecoration(
//         labelText: "Tỉnh / Thành phố",
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.flag_outlined),
//       ),
//       items: provinces
//           .map((p) =>
//           DropdownMenuItem(value: p["id"].toString(), child: Text(p["name"])))
//           .toList(),
//       onChanged: onChanged,
//     );
//   }
//
//   Widget _districtDropdown({
//     required List<dynamic> districts,
//     required String? value,
//     required void Function(String?) onChanged,
//   }) {
//     return DropdownButtonFormField<String>(
//       value: value,
//       isExpanded: true,
//       decoration: const InputDecoration(
//         labelText: "Quận / Huyện",
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.location_city_outlined),
//       ),
//       items: districts
//           .map((d) =>
//           DropdownMenuItem(value: d["id"].toString(), child: Text(d["name"])))
//           .toList(),
//       onChanged: onChanged,
//     );
//   }
//
//   // ------------------- Date + Time picker -------------------
//   Widget _dateTimePicker(BookingModel model) {
//     return Row(
//       children: [
//         Expanded(
//           child: _dateField(
//             label: "Ngày đón",
//             date: model.goDate,
//             onTap: () async {
//               final today = DateTime.now();
//               final picked = await showDatePicker(
//                 context: context,
//                 firstDate: today,
//                 lastDate: DateTime(today.year + 1),
//                 initialDate: model.goDate ?? today,
//               );
//               if (picked != null) {
//                 model.goDate = picked;
//                 model.notifyListeners();
//               }
//             },
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: _timeField(
//             label: "Giờ đón",
//             time: model.goTime,
//             onTap: () async {
//               final picked = await showTimePicker(
//                 context: context,
//                 initialTime: model.goTime ?? TimeOfDay.now(),
//               );
//               if (picked != null) {
//                 model.goTime = picked;
//                 model.notifyListeners();
//               }
//             },
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _returnTrip(BookingModel model) {
//     return Column(
//       children: [
//         const Text("Thông tin chuyến khứ hồi",
//             style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//         const SizedBox(height: 12),
//
//         Row(
//           children: [
//             Expanded(
//               child: _dateField(
//                 label: "Ngày đón (khứ hồi)",
//                 date: model.returnDate,
//                 onTap: () async {
//                   final today = DateTime.now();
//                   final picked = await showDatePicker(
//                     context: context,
//                     firstDate: today,
//                     lastDate: DateTime(today.year + 1),
//                     initialDate: model.returnDate ?? today,
//                   );
//                   if (picked != null) {
//                     model.returnDate = picked;
//                     model.notifyListeners();
//                   }
//                 },
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _timeField(
//                 label: "Giờ đón (khứ hồi)",
//                 time: model.returnTime,
//                 onTap: () async {
//                   final picked = await showTimePicker(
//                     context: context,
//                     initialTime: model.returnTime ?? TimeOfDay.now(),
//                   );
//                   if (picked != null) {
//                     model.returnTime = picked;
//                     model.notifyListeners();
//                   }
//                 },
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
//   // ------------------- Field helpers -------------------
//   Widget _dateField({
//     required String label,
//     required DateTime? date,
//     required VoidCallback onTap,
//   }) {
//     final controller = TextEditingController(
//       text: date == null
//           ? ""
//           : "${date.day.toString().padLeft(2, "0")}/${date.month.toString().padLeft(2, "0")}/${date.year}",
//     );
//
//     return GestureDetector(
//       onTap: onTap,
//       child: AbsorbPointer(
//         child: TextField(
//           controller: controller,
//           decoration: InputDecoration(
//             labelText: label,
//             border: const OutlineInputBorder(),
//             prefixIcon: const Icon(Icons.calendar_today),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _timeField({
//     required String label,
//     required TimeOfDay? time,
//     required VoidCallback onTap,
//   }) {
//     final controller = TextEditingController(
//       text: time == null
//           ? ""
//           : "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
//     );
//
//     return GestureDetector(
//       onTap: onTap,
//       child: AbsorbPointer(
//         child: TextField(
//           controller: controller,
//           decoration: InputDecoration(
//             labelText: label,
//             border: const OutlineInputBorder(),
//             prefixIcon: const Icon(Icons.access_time),
//           ),
//         ),
//       ),
//     );
//   }
// }
