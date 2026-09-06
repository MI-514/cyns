import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  // Register Customer or Worker or Admin
  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String role,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      String uid = cred.user!.uid;
      UserModel userModel = UserModel(
        uid: uid,
        email: email.trim(),
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        role: role,
      );

      // Save user doc in Firestore (non-blocking attempt)
      _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set(userModel.toMap())
          .catchError((_) {});

      if (role == 'customer') {
        _firestore
            .collection(FirestoreCollections.customers)
            .doc(uid)
            .set({
          'customerId': uid,
          'name': fullName,
          'phoneNumber': phoneNumber,
          'profilePicUrl': '',
          'address': '',
        }).catchError((_) {});
      } else if (role == 'worker') {
        _firestore
            .collection(FirestoreCollections.workers)
            .doc(uid)
            .set({
          'workerId': uid,
          'name': fullName,
          'phoneNumber': phoneNumber,
          'profilePicUrl': '',
          'profession': 'General Skilled Worker',
          'categoryIds': [],
          'skills': [],
          'experienceYears': 1,
          'serviceDescription': '',
          'workingArea': '',
          'isAvailable': true,
          'rating': 0.0,
          'reviewCount': 0,
          'completedJobsCount': 0,
          'isApproved': true,
          'createdAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception("An account already exists for this email. Please sign in instead.");
      } else if (e.code == 'weak-password') {
        throw Exception("Password should be at least 6 characters.");
      } else if (e.code == 'invalid-email') {
        throw Exception("Invalid email address format.");
      } else {
        throw Exception(e.message ?? "Registration failed. Please try again.");
      }
    } catch (e) {
      rethrow;
    }
  }

  // Fast Login with precise error messages
  Future<UserModel> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      String uid = cred.user!.uid;

      // Fast Firestore document fetch with 2-second timeout
      try {
        DocumentSnapshot doc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 2));

        if (doc.exists && doc.data() != null) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }
      } catch (_) {
        // Fallback to Auth User data
      }

      String inferredRole = email.toLowerCase().contains('worker')
          ? 'worker'
          : email.toLowerCase().contains('admin')
              ? 'admin'
              : 'customer';

      return UserModel(
        uid: uid,
        email: cred.user!.email ?? email.trim(),
        fullName: cred.user!.displayName ?? email.split('@').first,
        phoneNumber: cred.user!.phoneNumber ?? '',
        role: inferredRole,
      );
    } on FirebaseAuthException catch (e) {
      String code = e.code.toLowerCase();
      String msg = (e.message ?? '').toLowerCase();

      if (code == 'wrong-password' || msg.contains('password') || msg.contains('invalid_password')) {
        throw Exception("Incorrect password. Please check your password and try again.");
      } else if (code == 'user-not-found' || msg.contains('user-not-found') || msg.contains('user_not_found') || msg.contains('no user')) {
        throw Exception("No account registered with this email. Please register first.");
      } else if (code == 'invalid-credential') {
        throw Exception("Incorrect password. Please check your password and try again.");
      } else if (code == 'invalid-email') {
        throw Exception("Invalid email address format.");
      } else if (code == 'user-disabled') {
        throw Exception("This account has been suspended or disabled.");
      } else {
        throw Exception(e.message ?? "Authentication failed. Please check your credentials.");
      }
    } catch (e) {
      rethrow;
    }
  }

  // Fast Get User Profile Document
  Future<UserModel?> getUserModel(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 2));
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (_) {}
    return null;
  }

  // Reset Password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception("No account found with this email.");
      }
      throw Exception(e.message ?? "Failed to send password reset email.");
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }
}
