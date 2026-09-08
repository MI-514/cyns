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
    required String username,
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
        username: username,
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

  // Advanced Worker Registration with Unique Alphanumeric Username Check
  Future<bool> registerWorkerAdvanced({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String fatherName,
    required String phoneNumber,
    required String address,
    required String cnicNumber,
    required String profession,
    required String categoryId,
    required int experienceYears,
    String? profilePicBase64,
    String? cnicFrontBase64,
    String? cnicBackBase64,
  }) async {
    try {
      _state = AuthState.loading;
      _errorMessage = '';
      notifyListeners();

      await _authRepository.registerWorkerAdvanced(
        email: email,
        password: password,
        username: username,
        fullName: fullName,
        fatherName: fatherName,
        phoneNumber: phoneNumber,
        address: address,
        cnicNumber: cnicNumber,
        profession: profession,
        categoryId: categoryId,
        experienceYears: experienceYears,
        profilePicBase64: profilePicBase64,
        cnicFrontBase64: cnicFrontBase64,
        cnicBackBase64: cnicBackBase64,
      );

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

  Future<void> loginAsGuest({required String role}) async {
    String guestUid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    _userModel = UserModel(
      uid: guestUid,
      email: '$role.guest@cyns.app',
      username: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      fullName: '${role == "worker" ? "Worker" : "Customer"} Guest',
      phoneNumber: '+923000000000',
      role: role,
    );
    _state = AuthState.authenticated;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    notifyListeners();
  }

  /// Strict Role-Validated User Login
  Future<bool> loginUser({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    try {
      _state = AuthState.loading;
      _errorMessage = '';
      notifyListeners();

      UserModel user = await _authRepository.loginUser(
        email: email,
        password: password,
      );

      // STRICT ROLE VALIDATION: Verify registered role matches the login screen role!
      if (user.role != expectedRole) {
        await _authRepository.logout();
        _userModel = null;
        _state = AuthState.unauthenticated;

        if (user.role == 'customer') {
          _errorMessage =
              'Access Denied: This account is registered as a Customer. Please switch to Customer Sign In.';
        } else if (user.role == 'worker') {
          _errorMessage =
              'Access Denied: This account is registered as a Worker. Please switch to Worker Sign In.';
        } else {
          _errorMessage = 'Access Denied: Role mismatch for this account.';
        }
        notifyListeners();
        return false;
      }

      _userModel = user;
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
