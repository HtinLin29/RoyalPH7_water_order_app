import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectivityService {
  ConnectivityService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static Future<bool> isConnected() async {
    return ConnectivityService()._check();
  }

  Future<bool> _check() async {
    try {
      await _client.from('products').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}
