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
    notifyListeners();
  }
}
