import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const double mapMinZoom = 5;
const double mapMaxZoom = 18;
const double webMercatorMaxLatitude = 85.0511287798066;

/// Reject invalid input instead of inventing/clamping a user's GPS location.
bool isValidMapCoordinate(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180 &&
    latitude.abs() <= webMercatorMaxLatitude;

bool isValidMapPoint(LatLng point) =>
    isValidMapCoordinate(point.latitude, point.longitude);

bool isValidMapZoom(double zoom) =>
    zoom.isFinite && zoom >= mapMinZoom && zoom <= mapMaxZoom;

/// Runs inside moveRaw, BEFORE camera state/events/tile projection are updated.
/// onPositionChanged is too late to reject a bad gesture/animation camera.
class FiniteMapCameraConstraint extends CameraConstraint {
  const FiniteMapCameraConstraint();

  @override
  MapCamera? constrain(MapCamera camera) =>
      isValidMapPoint(camera.center) &&
              isValidMapZoom(camera.zoom) &&
              camera.rotation.isFinite
          ? camera
          : null;
}

/// Call only after onMapReady. Already at the target counts as success.
bool moveMapTo(
  MapController controller,
  LatLng target,
  double zoom, {
  Offset offset = Offset.zero,
}) {
  if (!isValidMapPoint(target) || !isValidMapZoom(zoom) ||
      !offset.dx.isFinite || !offset.dy.isFinite) return false;
  final camera = controller.camera;
  if (!isValidMapPoint(camera.center) ||
      !isValidMapZoom(camera.zoom) ||
      !camera.rotation.isFinite ||
      !camera.nonRotatedSize.width.isFinite ||
      !camera.nonRotatedSize.height.isFinite ||
      camera.nonRotatedSize.width <= 0 ||
      camera.nonRotatedSize.height <= 0) {
    return false;
  }
  // Match flutter_map's offset transform and validate the resulting camera
  // center before moveRaw can project or store it. GPS/marker stays unchanged.
  var expectedCenter = target;
  if (offset != Offset.zero) {
    final projected = camera.projectAtZoom(target, zoom);
    final shifted = camera.rotatePoint(projected, projected - offset);
    if (!shifted.dx.isFinite || !shifted.dy.isFinite) return false;
    expectedCenter = camera.unprojectAtZoom(shifted, zoom);
    if (!isValidMapPoint(expectedCenter)) return false;
  }
  // flutter_map interrupts gesture animations synchronously for a controller
  // move event. Keep this move synchronous; do not enqueue an app animation.
  controller.move(target, zoom, offset: offset);
  return controller.camera.center == expectedCenter &&
      controller.camera.zoom == zoom;
}

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
