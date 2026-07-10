import 'package:flutter/foundation.dart';

import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  double get subtotal => product.price * quantity;
}

class CartProvider extends ChangeNotifier {
  static const int maxQuantity = 99;

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalItems =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);

  String get formattedTotal => '฿${totalPrice.toStringAsFixed(0)}';

  bool get isEmpty => _items.isEmpty;

  int getQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index < 0) return 0;
    return _items[index].quantity.clamp(0, maxQuantity);
  }

  void addItem(Product product, int quantity) {
    if (quantity <= 0) return;

    final existingIndex =
        _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final newQty =
          (_items[existingIndex].quantity + quantity).clamp(1, maxQuantity);
      _items[existingIndex].quantity = newQty;
    } else {
      _items.add(
        CartItem(
          product: product,
          quantity: quantity.clamp(1, maxQuantity),
        ),
      );
    }
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity = quantity.clamp(1, maxQuantity);
      notifyListeners();
    }
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
