import '/backend/api_requests/business_ops_api.dart';
import '/backend/services/api_service.dart';

/// Phase 6: the user's Algorand address and USDC deposits. Server decides all.
class ChainWalletApi {
  static Future<Map<String, dynamic>> mine() => ApiService.request(method: 'GET', path: '/wallet/chain');
  static Future<List<Map<String, dynamic>>> deposits() async =>
      BusinessOpsApi.list(await ApiService.request(method: 'GET', path: '/wallet/chain/deposits'));
}
