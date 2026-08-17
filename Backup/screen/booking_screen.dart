// // NOTE: Đây là file đã được chỉnh sửa: chỉ thay _districtDropdown để hiển thị picker giống tỉnh (modal bottom sheet).
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../models/booking_model.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
// import 'activity_screen.dart';
// import 'dart:async';
//
// class BookingScreen extends StatelessWidget {
//   final Function(int) onRideBooked;
//   const BookingScreen({super.key, required this.onRideBooked});
//
//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => BookingModel(),
//       child: _BookingView(onRideBooked: onRideBooked),
//     );
//   }
// }
//
// class _BookingView extends StatefulWidget {
//   final Function(int) onRideBooked;
//   const _BookingView({required this.onRideBooked});
//
//   @override
//   State<_BookingView> createState() => _BookingViewState();
// }
//
// class _BookingViewState extends State<_BookingView> {
//   final _phoneController = TextEditingController();
//   final _noteController = TextEditingController();
//
//   bool _isCreatingRide = false; //Chống double tap
//
//   void _resetControllers() {
//     _phoneController.clear();
//     _noteController.clear();
//   }
//
//   void _handlePaymentMethodChange(BookingModel model, int? value) {
//     if (value == null) return;
//     model.paymentMethod = value;
//   }
//
//   // --- HÀM TẠO DÒNG GIÁ TRONG BẢNG CHI TIẾT ---
//   Widget _buildPriceRow(String label, double amount, {bool isBold = false, Color? color}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
//           Text(
//             formatCurrency(amount),
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
//               color: color,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // =====================================================
//   // GIÁ VÀ NÚT ĐẶT CHUYẾN (CẬP NHẬT CHI TIẾT GIÁ TẠI ĐÂY)
//   // =====================================================
//   Widget _buildPriceAndBookingButton(BookingModel model, BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -2)),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // --- BẢNG CHI TIẾT GIÁ ---
//           if (model.isLoadingPrice)
//             const Padding(
//               padding: EdgeInsets.only(bottom: 10),
//               child: LinearProgressIndicator(),
//             )
//           else if (model.tripPrice != null)
//             Container(
//               padding: const EdgeInsets.only(bottom: 12),
//               child: Column(
//                 children: [
//                   _buildPriceRow("Giá cước gốc:", model.basePrice ?? 0),
//                   _buildPriceRow("Ưu đãi trả trước:", -(model.discount), color: Colors.green),
//                   _buildPriceRow("Phụ phí ngày lễ:", model.surcharge, color: Colors.orange),
//                   const Divider(height: 15),
//                   _buildPriceRow(
//                     "Thành tiền:",
//                     model.tripPrice!,
//                     isBold: true,
//                     color: Colors.blue.shade800,
//                   ),
//                 ],
//               ),
//             )
//           else if (model.priceErrorMessage != null)
//               Text(
//                 model.priceErrorMessage!,
//                 style: const TextStyle(color: Colors.orange, fontSize: 15),
//               )
//             else
//               const Text(
//                 "Vui lòng nhập đầy đủ lộ trình",
//                 style: TextStyle(color: Colors.red, fontSize: 15),
//               ),
//
//           // --- NÚT ĐẶT CHUYẾN ---
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               onPressed: _isCreatingRide
//                   ? null
//                   : () async {
//                 if (!_validateBeforeBooking(model)) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin bắt buộc'), backgroundColor: Colors.red),
//                   );
//                   return;
//                 }
//
//                 final accessToken = await _getAccessToken();
//                 if (accessToken == null) {
//                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn chưa đăng nhập')));
//                   return;
//                 }
//
//                 setState(() => _isCreatingRide = true); //Khoá nút đặt chuyến lại không cho double tap
//
//                 model.customerPhone = _phoneController.text.trim();
//                 model.note = _noteController.text.trim();
//
//                 if (model.paymentMethod == 1) {
//                   _showConfirmPaymentDialog(model, accessToken);
//                 } else {
//                   await _handleDirectBooking(model, accessToken);
//                 }
//               },
//               style: ElevatedButton.styleFrom(
//                 minimumSize: const Size(double.infinity, 50),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                 backgroundColor: Theme.of(context).primaryColor,
//                 foregroundColor: Colors.white,
//               ),
//               child: _isCreatingRide
//                   ? const SizedBox(
//                 height: 22,
//                 width: 22,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   color: Colors.white,
//                 ),
//               )
//                   : const Text(
//                 "Xác nhận Đặt chuyến",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // --- CÁC LOGIC THANH TOÁN (GIỮ NGUYÊN) ---
//   void _showPaymentQR(BookingModel model, String accessToken) async {
//     final prefs = await SharedPreferences.getInstance();
//     final int userId = prefs.getInt("id") ?? 0;
//     final String content = "$userId${DateFormat('HHmmss').format(DateTime.now())}";
//
//     final qrUrl = "https://img.vietqr.io/image/MB-246878888-compact2.png"
//         "?amount=${model.tripPrice!.toStringAsFixed(0)}&addInfo=$content&accountName=THE%20BELUGAS";
//
//     if (!mounted) return;
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (dialogCtx) {
//         int countdown = 300;
//         Timer? countdownTimer;
//         Timer? pollTimer;
//         bool isChecking = false;
//         bool rideCreated = false; // 🔒 đảm bảo 1 QR chỉ tạo 1 đơn
//
//         return StatefulBuilder(
//           builder: (ctx, setDialogState) {
//             // ⏱ Countdown timer
//             countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
//               if (countdown <= 0) {
//                 t.cancel();
//                 pollTimer?.cancel();
//                 Navigator.pop(dialogCtx);
//               } else if (dialogCtx.mounted) {
//                 setDialogState(() => countdown--);
//               }
//             });
//
//             // 🔁 Poll backend kiểm tra thanh toán
//             pollTimer ??= Timer.periodic(const Duration(seconds: 7), (t) async {
//               if (isChecking || rideCreated) return;
//
//               isChecking = true;
//               try {
//                 final result = await model.createRide(
//                   accessToken,
//                   content: content,
//                 );
//
//                 if (result['success'] == true) {
//                   rideCreated = true; // 🔒 khóa vĩnh viễn
//                   t.cancel();
//
//                   if (dialogCtx.mounted) {
//                     Navigator.pop(dialogCtx);
//                     widget.onRideBooked(2);
//                   }
//                 }
//               } catch (e) {
//                 print("Đang đợi thanh toán... $e");
//               }
//
//               isChecking = false;
//             });
//
//             return Dialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(20),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Text(
//                       "Thanh toán chuyến đi",
//                       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
//                     ),
//                     const SizedBox(height: 15),
//                     Image.network(qrUrl),
//                     const SizedBox(height: 15),
//                     const Text("Nội dung chuyển khoản:"),
//                     Text(
//                       content,
//                       style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.red,
//                         fontSize: 18,
//                       ),
//                     ),
//                     const SizedBox(height: 15),
//                     const Text(
//                       "Hệ thống đang kiểm tra tự động...\nVui lòng giữ màn hình này.",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         color: Colors.orange,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     Text(
//                       "Vui lòng chuyển khoản trong: "
//                           "${countdown ~/ 60}:${(countdown % 60).toString().padLeft(2, '0')}",
//                     ),
//                     const SizedBox(height: 10),
//                     TextButton(
//                       onPressed: () {
//                         pollTimer?.cancel();
//                         Navigator.pop(dialogCtx);
//                         if (mounted) {
//                           setState(() => _isCreatingRide = false); // 🔓 mở khóa nút
//                         }
//                       },
//                       child: const Text("Hủy giao dịch"),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     ).then((_) {
//       // PHÒNG TRƯỜNG HỢP dialog bị đóng bất thường
//       if (mounted && _isCreatingRide) {
//         setState(() => _isCreatingRide = false);
//       }
//     });
//   }
//
//   Future<void> _handleDirectBooking(BookingModel model, String accessToken) async {
//     try {
//       final result = await model.createRide(accessToken);
//       if (result['success'] == true) {
//         widget.onRideBooked(2);
//         if (mounted) setState(() => _isCreatingRide = false);
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
//       );
//       setState(() => _isCreatingRide = false); // MỞ LẠI KHI LỖI
//     }
//   }
//
//   bool _validateBeforeBooking(BookingModel model) {
//     // model.tripCategory luôn có giá trị vì enum mặc định
//     if (model.selectedProvincePickup == null || model.selectedDistrictPickup == null || (model.addressPickup?.trim().isEmpty ?? true)) return false;
//     if (model.selectedProvinceDrop == null || model.selectedDistrictDrop == null || (model.addressDrop?.trim().isEmpty ?? true)) return false;
//     if (model.goDate == null || model.goTime == null) return false;
//     if (_phoneController.text.trim().isEmpty) return false;
//     return true;
//   }
//
//   String formatCurrency(double value) {
//     final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND', decimalDigits: 0);
//     return formatter.format(value);
//   }
//
//   Future<String?> _getAccessToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString("accessToken");
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final model = context.watch<BookingModel>();
//     return Scaffold(
//       appBar: AppBar(title: const Text('Đặt chuyến'), centerTitle: true),
//       body: _buildBookingForm(model),
//       bottomNavigationBar: _buildPriceAndBookingButton(model, context),
//     );
//   }
//
//   void _showConfirmPaymentDialog(BookingModel model, String accessToken) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Xác nhận thông tin"),
//         content: const Text("Bạn đã kiểm tra kỹ thông tin chuyến đi chưa?\n\n⚠️ Lưu ý: KHÔNG tắt ứng dụng hoặc đóng mã QR cho đến khi hệ thống báo thành công."),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
//           ElevatedButton(onPressed: () {
//             Navigator.pop(ctx);
//             _showPaymentQR(model, accessToken);
//           }, child: const Text("Xác nhận & Hiện QR")),
//         ],
//       ),
//     );
//   }
//
//   // --- CẤU TRÚC UI GỐC (GIỮ NGUYÊN 100% NHƯ BẠN YÊU CẦU) ---
//   Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       margin: EdgeInsets.zero,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(children: [Icon(icon, color: Colors.blue.shade700), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]),
//             const Divider(height: 20),
//             ...children,
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLocationSection(BookingModel model) {
//     return _buildSectionCard(
//       title: "Điểm Đi và Điểm Đến",
//       icon: Icons.route,
//       children: [
//         _buildLocationInput(
//           label: "Điểm đón",
//           icon: Icons.my_location,
//           color: Colors.green,
//           provinceDropdown: _provincePickerWidget(model: model, isPickup: true),
//           districtDropdown: _districtDropdown(
//             districts: model.pickupDistricts,
//             value: model.selectedDistrictPickup,
//             onChanged: (v) {
//               model.setSelectedDistrictPickup(v);
//               // cập nhật giá khi đã có huyện
//               model.fetchTripPrice();
//             },
//           ),
//           addressField: TextField(decoration: const InputDecoration(labelText: "Số nhà, xã/phường", border: OutlineInputBorder(), isDense: true), onChanged: (v) => model.addressPickup = v),
//         ),
//         const SizedBox(height: 20),
//         // NGÀY GIỜ ĐÓN Ở GIỮA NHƯ CŨ
//         _buildSectionCard(title: "Ngày & Giờ Đón", icon: Icons.calendar_today, children: [_dateTimePicker(model)]),
//         const SizedBox(height: 25),
//         const Padding(padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16), child: Icon(Icons.arrow_downward, color: Colors.grey)),
//         _buildLocationInput(
//           label: "Điểm đến",
//           icon: Icons.location_on,
//           color: Colors.red,
//           provinceDropdown: _provincePickerWidget(model: model, isPickup: false),
//           districtDropdown: _districtDropdown(
//             districts: model.dropDistricts,
//             value: model.selectedDistrictDrop,
//             onChanged: (v) {
//               model.setSelectedDistrictDrop(v);
//               model.fetchTripPrice();
//             },
//           ),
//           addressField: TextField(decoration: const InputDecoration(labelText: "Số nhà, xã/phường", border: OutlineInputBorder(), isDense: true), onChanged: (v) => model.addressDrop = v),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildLocationInput({required String label, required IconData icon, required Color color, required Widget provinceDropdown, Widget? districtDropdown, required Widget addressField}) {
//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color))]),
//       const SizedBox(height: 8),
//       provinceDropdown,
//       if (districtDropdown != null) ...[
//         const SizedBox(height: 8),
//         districtDropdown,
//       ],
//       const SizedBox(height: 8),
//       addressField,
//     ]);
//   }
//
//   Widget _buildBookingForm(BookingModel model) {
//     const compactDensity = VisualDensity(vertical: -4);
//     const radioTextStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildSectionCard(
//             title: "Chọn Loại Chuyến",
//             icon: Icons.directions_car,
//             children: [
//               RadioListTile<TripCategory>(dense: true, visualDensity: compactDensity, contentPadding: EdgeInsets.zero, value: TripCategory.choNguoi, groupValue: model.tripCategory, title: const Text("Chở người", style: radioTextStyle), onChanged: (v) { if (v != null) { model.setTripCategory(v); model.fetchTripPrice(); } }),
//               RadioListTile<TripCategory>(dense: true, visualDensity: compactDensity, contentPadding: EdgeInsets.zero, value: TripCategory.choHang, groupValue: model.tripCategory, title: const Text("Giao hàng", style: radioTextStyle), onChanged: (v) { if (v != null) { model.setTripCategory(v); model.fetchTripPrice(); } }),
//               if (model.isChoNguoi) CheckboxListTile(dense: true, visualDensity: compactDensity, contentPadding: EdgeInsets.zero, value: model.isBaoXe, title: const Text("Bao trọn chuyến xe", style: radioTextStyle), onChanged: (v) { model.setIsBaoXe(v ?? false); model.fetchTripPrice(); }),
//               if (!model.isChoNguoi) CheckboxListTile(dense: true, visualDensity: compactDensity, contentPadding: EdgeInsets.zero, value: model.isHoaToc, title: const Text("Giao Hỏa tốc (Thêm phí)", style: radioTextStyle), onChanged: (v) { model.setIsHoaToc(v ?? false); model.fetchTripPrice(); }),
//             ],
//           ),
//           const SizedBox(height: 18),
//           _buildLocationSection(model),
//           const SizedBox(height: 16),
//           _buildSectionCard(
//             title: "Thông tin Khách hàng & Ghi chú",
//             icon: Icons.person_pin,
//             children: [
//               TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Số điện thoại liên hệ", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
//               const SizedBox(height: 8),
//               TextField(controller: _noteController, maxLines: 3, decoration: const InputDecoration(labelText: "Ghi chú cho tài xế (VD: Mã bưu kiện, số người)", border: OutlineInputBorder(), alignLabelWithHint: true)),
//             ],
//           ),
//           const SizedBox(height: 15),
//           _buildSectionCard(
//             title: "Phương thức thanh toán",
//             icon: Icons.payments_outlined,
//             children: [
//               RadioListTile<int>(dense: true, visualDensity: compactDensity, contentPadding: EdgeInsets.zero, value: 1, groupValue: model.paymentMethod, title: const Text("Chuyển khoản", style: radioTextStyle), secondary: const Icon(Icons.account_balance, color: Colors.blue), onChanged: (v) => _handlePaymentMethodChange(model, v)),
//               RadioListTile<int>(dense: true, visualDensity: compactDensity, contentPadding: EdgeInsets.zero, value: 2, groupValue: model.paymentMethod, title: const Text("Thanh toán bằng ví", style: radioTextStyle), secondary: const Icon(Icons.wallet_giftcard, color: Colors.green), onChanged: (v) => _handlePaymentMethodChange(model, v)),
//               RadioListTile<int>(dense: true, visualDensity: compactDensity, contentPadding: EdgeInsets.zero, value: 3, groupValue: model.paymentMethod, title: const Text("Thanh toán sau", style: radioTextStyle), secondary: const Icon(Icons.person_outline, color: Colors.orange), onChanged: (v) => _handlePaymentMethodChange(model, v)),
//             ],
//           ),
//           const SizedBox(height: 100),
//         ],
//       ),
//     );
//   }
//
//   // --- HELPERS (ĐÃ CHUYỂN SANG INT ID) ---
//
//   // Widget picker giống phong cách ReceiveOrderTab: mở modal bottom sheet show list of provinces
//   Widget _provincePickerWidget({required BookingModel model, required bool isPickup}) {
//     final int? selectedId = isPickup ? model.selectedProvincePickup : model.selectedProvinceDrop;
//     final String label = "Tỉnh / Thành phố";
//     final displayName = () {
//       final sel = selectedId == null ? null : model.provinces.cast<dynamic?>().firstWhere(
//             (p) => p != null && (p['id'].toString() == selectedId.toString()),
//         orElse: () => null,
//       );
//       return sel == null ? null : (sel['name']?.toString() ?? '');
//     }();
//
//     // Sử dụng controller để hiển thị tên tỉnh đã chọn (nếu có)
//     final controller = TextEditingController(text: displayName ?? '');
//
//     return GestureDetector(
//       onTap: () async {
//         final chosen = await _showProvincePickerForBooking(context, model, isPickup: isPickup);
//         if (!mounted) return;
//         if (chosen == null) return;
//         // apply through model so it loads districts
//         if (isPickup) {
//           await model.setSelectedProvincePickup(chosen);
//         } else {
//           await model.setSelectedProvinceDrop(chosen);
//         }
//       },
//       child: AbsorbPointer(
//         child: TextFormField(
//           controller: controller,
//           readOnly: true,
//           decoration: InputDecoration(
//             labelText: label,
//             hintText: displayName == null ? 'Chọn tỉnh / thành phố' : null,
//             border: const OutlineInputBorder(),
//             isDense: true,
//             prefixIcon: const Icon(Icons.location_city, size: 20),
//             suffixIcon: const Icon(Icons.unfold_more_rounded),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Modal picker. Nếu isPickup=true thì không cho chọn province == model.selectedProvinceDrop (và ngược lại)
//   Future<int?> _showProvincePickerForBooking(BuildContext context, BookingModel model, {required bool isPickup}) {
//     final otherSelected = isPickup ? model.selectedProvinceDrop : model.selectedProvincePickup;
//
//     return showModalBottomSheet<int?>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (ctx) {
//         return Container(
//           height: MediaQuery.of(context).size.height * 0.75,
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
//           ),
//           child: Column(
//             children: [
//               Container(margin: const EdgeInsets.only(top: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
//               Padding(
//                 padding: const EdgeInsets.all(20),
//                 child: Row(
//                   children: [
//                     Expanded(child: Text(isPickup ? "Chọn tỉnh đón khách" : "Chọn tỉnh điểm đến", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
//                     TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Đóng"))
//                   ],
//                 ),
//               ),
//               const Divider(height: 1),
//               Expanded(
//                 child: (model.provinces.isEmpty)
//                     ? const Center(child: CircularProgressIndicator())
//                     : ListView.separated(
//                   padding: const EdgeInsets.symmetric(vertical: 10),
//                   itemCount: model.provinces.length,
//                   separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
//                   itemBuilder: (context, index) {
//                     final p = model.provinces[index];
//                     final id = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString());
//                     final name = p['name']?.toString() ?? '';
//                     final bool isDisabled = (id != null && otherSelected != null && id == otherSelected);
//                     return ListTile(
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
//                       leading: Icon(Icons.location_on_outlined, color: isDisabled ? Colors.grey[300] : Colors.blue),
//                       title: Text(
//                         name,
//                         style: TextStyle(
//                           color: isDisabled ? Colors.grey : Colors.black,
//                           fontWeight: isDisabled ? FontWeight.w400 : FontWeight.w600,
//                           fontSize: 16,
//                         ),
//                       ),
//                       onTap: isDisabled || id == null ? null : () => Navigator.pop(ctx, id),
//                     );
//                   },
//                 ),
//               )
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   // ---- CHỖ NÀY ĐÃ ĐƯỢC SỬA: district dropdown bây giờ hiển thị giống tỉnh (modal bottom sheet),
//   // ---- UI và logic bên ngoài KHÔNG đổi: vẫn truyền danh sách districts và callback onChanged.
//   Widget _districtDropdown({required List<dynamic> districts, required int? value, required void Function(int?) onChanged}) {
//     // Tìm tên quận/huyện đã chọn để hiển thị trong TextField
//     final selected = value == null ? null : districts.cast<dynamic?>().firstWhere(
//           (d) => d != null && (d['id'].toString() == value.toString()),
//       orElse: () => null,
//     );
//     final displayName = selected == null ? null : (selected['name']?.toString() ?? '');
//     final controller = TextEditingController(text: displayName ?? '');
//
//     return GestureDetector(
//       onTap: districts.isEmpty
//           ? null
//           : () async {
//         final chosen = await showModalBottomSheet<int?>(
//           context: context,
//           isScrollControlled: true,
//           backgroundColor: Colors.transparent,
//           builder: (ctx) {
//             return Container(
//               height: MediaQuery.of(context).size.height * 0.65,
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
//               ),
//               child: Column(
//                 children: [
//                   Container(margin: const EdgeInsets.only(top: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
//                   Padding(
//                     padding: const EdgeInsets.all(20),
//                     child: Row(
//                       children: [
//                         const Expanded(child: Text("Chọn Quận / Huyện", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
//                         TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Đóng"))
//                       ],
//                     ),
//                   ),
//                   const Divider(height: 1),
//                   Expanded(
//                     child: ListView.separated(
//                       padding: const EdgeInsets.symmetric(vertical: 10),
//                       itemCount: districts.length,
//                       separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
//                       itemBuilder: (context, index) {
//                         final d = districts[index];
//                         final id = d["id"] is int ? d["id"] as int : int.tryParse(d["id"].toString());
//                         final name = d["name"]?.toString() ?? '';
//                         return ListTile(
//                           contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
//                           leading: Icon(Icons.location_city_outlined, color: id == value ? Colors.blue : Colors.black54),
//                           title: Text(name, style: TextStyle(fontWeight: id == value ? FontWeight.w700 : FontWeight.w500)),
//                           onTap: id == null ? null : () => Navigator.pop(ctx, id),
//                         );
//                       },
//                     ),
//                   )
//                 ],
//               ),
//             );
//           },
//         );
//         if (!mounted) return;
//         if (chosen == null) return;
//         onChanged(chosen);
//       },
//       child: AbsorbPointer(
//         child: TextFormField(
//           controller: controller,
//           readOnly: true,
//           decoration: InputDecoration(
//             labelText: "Quận / Huyện",
//             hintText: displayName == null ? 'Chọn quận / huyện' : null,
//             border: const OutlineInputBorder(),
//             isDense: true,
//             prefixIcon: const Icon(Icons.map, size: 20),
//             suffixIcon: const Icon(Icons.unfold_more_rounded),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _dateField({required String label, required DateTime? date, required VoidCallback onTap}) {
//     return GestureDetector(onTap: onTap, child: AbsorbPointer(child: TextField(controller: TextEditingController(text: date == null ? "" : DateFormat('dd/MM/yyyy').format(date)), decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.event, size: 20)))));
//   }
//
//   Widget _timeField({required String label, required TimeOfDay? time, required VoidCallback onTap}) {
//     return GestureDetector(onTap: onTap, child: AbsorbPointer(child: TextField(controller: TextEditingController(text: time == null ? "" : time.format(context)), decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.access_time, size: 20)))));
//   }
//
//   Widget _dateTimePicker(BookingModel model) {
//     return Row(children: [
//       Expanded(child: _dateField(label: "Ngày đón", date: model.goDate, onTap: () async { final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: model.goDate ?? DateTime.now()); if (picked != null) { model.goDate = picked; model.notifyListeners(); } })),
//       const SizedBox(width: 12),
//       Expanded(child: _timeField(label: "Giờ đón", time: model.goTime, onTap: () async { final picked = await showTimePicker(context: context, initialTime: model.goTime ?? TimeOfDay.now()); if (picked != null) { model.goTime = picked; model.notifyListeners(); } })),
//     ]);
//   }
// }