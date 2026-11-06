import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Nền bản đồ TrackAsia (ADR 0005 của backend). Đang dùng key mẫu `public` vì tài khoản chỉ có 1 key;
/// có key riêng thì build với --dart-define=TRACKASIA_KEY=... (key nằm trong app nên coi là công khai).
const String trackAsiaKey = String.fromEnvironment('TRACKASIA_KEY', defaultValue: 'public');
const String trackAsiaRasterTiles = 'https://tiles.track-asia.com/raster-tiles/v2/{z}/{x}/{y}.png?key=$trackAsiaKey';

/// Ô ảnh 512 px của TrackAsia: lùi 1 mức zoom để hiển thị đúng tỉ lệ trên flutter_map.
TileLayer trackAsiaTileLayer() => TileLayer(
      urlTemplate: trackAsiaRasterTiles,
      tileDimension: 512,
      zoomOffset: -1,
      maxNativeZoom: 16,
      userAgentPackageName: 'com.belucar.beluga',
    );

/// Ghi nguồn bắt buộc của TrackAsia/OpenStreetMap.
Widget trackAsiaAttribution() => const SimpleAttributionWidget(
      source: Text('TrackAsia · © OpenStreetMap', style: TextStyle(fontSize: 10)),
      backgroundColor: Color(0xB3FFFFFF),
    );
