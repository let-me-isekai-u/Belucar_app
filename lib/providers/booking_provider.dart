import '../models/booking_model.dart';

/// Provider-facing booking state.
///
/// The inherited implementation is kept for backward compatibility with the
/// standalone BigBang demo, which intentionally continues to use BookingModel
/// until its REST API is available.
class BookingProvider extends BookingModel {}
