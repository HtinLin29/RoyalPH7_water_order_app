import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  Profile? _currentProfile;
  bool _isLoading = false;
  String? _error;

  Profile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _currentProfile?.role == 'admin';
  bool get isDriver => _currentProfile?.role == 'driver';
  bool get isCustomer => _currentProfile?.role == 'customer';
  bool get isLoggedIn => _currentProfile != null;

  Future<void> loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _currentProfile = null;
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentProfile = await _authService.getProfile(user.id);
      if (_currentProfile == null) {
        _error = 'Profile not found';
      }
    } catch (e) {
      _currentProfile = null;
      _error = 'Something went wrong. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearProfile() {
    _currentProfile = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
