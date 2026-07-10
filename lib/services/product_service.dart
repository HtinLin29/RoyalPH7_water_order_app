import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import 'supabase_error_handler.dart';

class ProductService {
  ProductService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Product>> getProducts() async {
    try {
      final response =
          await _client.from('products').select().order('sort_order');

      return (response as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<Product> getProductById(String id) async {
    try {
      final response =
          await _client.from('products').select().eq('id', id).maybeSingle();

      if (response == null) {
        throw Exception('Product not found');
      }

      return Product.fromJson(response);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }
}
