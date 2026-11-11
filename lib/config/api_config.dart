/// Gốc API của backend. Mặc định production; bản debug có thể trỏ backend local, ví dụ:
/// flutter run --dart-define=API_ORIGIN=http://127.0.0.1:5088  (kèm `adb reverse tcp:5088 tcp:5088`).
const String apiOrigin = String.fromEnvironment('API_ORIGIN', defaultValue: 'https://datxedongduong.com');
