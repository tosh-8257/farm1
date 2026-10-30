import '/backend/api_requests/business_ops_api.dart';
import '/backend/services/api_service.dart';

/// Phase 8: Travel. Prices, holds, refunds and provider calls all happen on the server.
class TravelApi {
  static Map<String, dynamic> _d(Map<String, dynamic> r) =>
      r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : r;
  static Future<Map<String, dynamic>> status() async => _d(await ApiService.request(method: 'GET', path: '/travel/status'));
  static Future<List<Map<String, dynamic>>> search(Map<String, dynamic> q) async => BusinessOpsApi.list(
      await ApiService.request(method: 'POST', path: '/travel/flights/search', body: q, timeoutSeconds: 60));
  static Future<Map<String, dynamic>> offer(String id) async =>
      _d(await ApiService.request(method: 'GET', path: '/travel/flights/offers/$id'));
  static Future<Map<String, dynamic>> book(Map<String, dynamic> body) async =>
      _d(await ApiService.request(method: 'POST', path: '/travel/flights/book', body: body, timeoutSeconds: 90));
  static Future<List<Map<String, dynamic>>> bookings() async =>
      BusinessOpsApi.list(await ApiService.request(method: 'GET', path: '/travel/bookings'));
  static Future<Map<String, dynamic>> booking(String id) async =>
      _d(await ApiService.request(method: 'GET', path: '/travel/bookings/$id'));

  // Hotels (LiteAPI). Off unless the server reports hotels.enabled.
  static Future<List<Map<String, dynamic>>> hotelSearch(Map<String, dynamic> q) async => BusinessOpsApi.list(
      await ApiService.request(method: 'POST', path: '/travel/hotels/search', body: q, timeoutSeconds: 60));
  static Future<Map<String, dynamic>> hotelPrebook(String offerId) async =>
      _d(await ApiService.request(method: 'POST', path: '/travel/hotels/prebook', body: {'offer_id': offerId}, timeoutSeconds: 60));
  static Future<Map<String, dynamic>> hotelBook(Map<String, dynamic> body) async =>
      _d(await ApiService.request(method: 'POST', path: '/travel/hotels/book', body: body, timeoutSeconds: 120));
  static Future<Map<String, dynamic>> hotelCancel(String id) async =>
      _d(await ApiService.request(method: 'POST', path: '/travel/hotels/bookings/$id/cancel', timeoutSeconds: 90));
}

/// Admin: review travel bookings whose provider outcome was unknown.
class AdminTravelApi {
  static Future<List<Map<String, dynamic>>> bookings({String? status}) async => BusinessOpsApi.list(await ApiService.request(
      method: 'GET', path: '/admin/travel/bookings${status == null ? '' : '?status=$status'}'));
  static Future<Map<String, dynamic>> resolve(String id, Map<String, dynamic> body) async {
    final r = await ApiService.request(method: 'POST', path: '/admin/travel/bookings/$id/resolve', body: body);
    return r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : r;
  }
}
