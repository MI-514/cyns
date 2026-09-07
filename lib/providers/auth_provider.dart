import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

enum AuthState { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();

  AuthState _state = AuthState.uninitialized;
  UserModel? _userModel;
  String _errorMessage = '';

  AuthState get state => _state;
  UserModel? get userModel => _userModel;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isGuest = prefs.getBool('is_guest') ?? false;
    String? savedRole = prefs.getString('user_role');

    if (isGuest && savedRole != null) {
      String uid =
          savedRole == 'worker' ? 'guest_worker_id' : 'guest_customer_id';

      String name = savedRole == 'worker' ? 'Guest Worker' : 'Guest Customer';

      _userModel = UserModel(
        uid: uid,
        email: 'guest_${savedRole}@cyn.app',
        fullName: name,
        phoneNumber: '+923001234567',
        role: savedRole,
        isVerified: true,
      );
      _state = AuthState.authenticated;
      notifyListeners();
      return;
    }

    _authRepository.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        _userModel = await _authRepository.getUserModel(firebaseUser.uid);
        if (_userModel != null) {
          _state = AuthState.authenticated;
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', _userModel!.role);
        } else {
          _state = AuthState.unauthenticated;
        }
      } else {
        _userModel = null;
        _state = AuthState.unauthenticated;
      }
      notifyListeners();
    });
  }

  Future<void> loginAsGuest({String role = 'customer'}) async {
    _state = AuthState.loading;
    notifyListeners();

    String uid = role == 'worker' ? 'guest_worker_id' : 'guest_customer_id';

    String name = role == 'worker' ? 'Guest Worker' : 'Guest Customer';

    _userModel = UserModel(
      uid: uid,
      email: 'guest_${role}@cyn.app',
      fullName: name,
      phoneNumber: '+923001234567',
      role: role,
      isVerified: true,
    );

    _state = AuthState.authenticated;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    await prefs.setBool('is_guest', true);
    notifyListeners();
  }

  Future<bool> registerUser({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String role,
  }) async {
    try {
      _state = AuthState.loading;
      _errorMessage = '';
      notifyListeners();

      await _authRepository.registerUser(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        role: role,
      );

      // Immediately sign out after registration so user must explicitly log in
      await _authRepository.logout();
      _userModel = null;
      _state = AuthState.unauthenticated;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_guest');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      _state = AuthState.loading;
      _errorMessage = '';
      notifyListeners();

      _userModel = await _authRepository.loginUser(
        email: email,
        password: password,
      );

      _state = AuthState.authenticated;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_guest');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _errorMessage = '';
      await _authRepository.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _userModel = null;
    _state = AuthState.unauthenticated;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.remove('is_guest');
    notifyListeners();
  }
}
