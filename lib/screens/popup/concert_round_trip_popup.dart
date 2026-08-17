import 'package:flutter/material.dart';

import '../../app_theme.dart';

Future<void> showConcertRoundTripPopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(
        Icons.sync_alt_rounded,
        color: AppColors.accentGold,
        size: 42,
      ),
      title: const Text(
        'Đã chuyển sang vé khứ hồi',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: const Text(
        'Ngày đi và ngày về bạn chọn trùng nhau. Hệ thống đã ghép hai lượt thành vé khứ hồi và áp dụng giảm 10% tổng hai lượt.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black87, height: 1.45),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.accentGold,
          ),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

Future<void> showConcertOvernightJourneyPopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(
        Icons.night_shelter_rounded,
        color: AppColors.accentGold,
        size: 42,
      ),
      title: const Text(
        'Hành trình đi ngày 24, về ngày 25',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: const Text(
        'Bạn chọn tham gia cả hai ngày và chỉ về ngày 25. Hệ thống sẽ tính một lượt đi ngày 24 và một lượt về ngày 25; không phát sinh lượt đi ngày 25.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black87, height: 1.45),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.accentGold,
          ),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

Future<void> showConcertReturnOnlyTimePopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(
        Icons.directions_bus_filled_rounded,
        color: AppColors.accentGold,
        size: 42,
      ),
      title: const Text(
        'Thời gian đón lượt về',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: const Text(
        'Xe sẽ chờ đón hành khách sau khi concert kết thúc. Bạn không cần chọn khung giờ cho lượt về.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black87, height: 1.45),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.accentGold,
          ),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
