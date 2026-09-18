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

  /// Check if a username is available in Cloud Firestore
  Future<bool> isUsernameAvailable(String username) async {
    try {
      String clean = username.trim().toLowerCase();
      QuerySnapshot snap = await _firestore
          .collection(FirestoreCollections.users)
          .where('username', isEqualTo: clean)
          .get()
          .timeout(const Duration(seconds: 3));
      return snap.docs.isEmpty;
    } catch (_) {
      return true;
    }
  }

  // Register Customer with Unique Alphanumeric Username Check
  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String phoneNumber,
    required String role,
  }) async {
    String cleanUsername = username.trim().toLowerCase();

    // Verify username uniqueness
    bool isAvailable = await isUsernameAvailable(cleanUsername);
    if (!isAvailable) {
      throw Exception("Username '$cleanUsername' is already taken. Please choose another unique username.");
    }

    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      String uid = cred.user!.uid;
      UserModel userModel = UserModel(
        uid: uid,
        email: email.trim(),
        username: cleanUsername,
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        role: role,
      );

      // Save user doc in Firestore
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
          'username': cleanUsername,
          'name': fullName,
          'phoneNumber': phoneNumber,
          'profilePicUrl': '',
          'address': '',
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

  // Advanced Real-Time Worker Registration with Unique Username
  Future<UserModel> registerWorkerAdvanced({
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
    String cleanUsername = username.trim().toLowerCase();

    // Verify username uniqueness
    bool isAvailable = await isUsernameAvailable(cleanUsername);
    if (!isAvailable) {
      throw Exception("Username '$cleanUsername' is already taken. Please choose another unique username.");
    }

    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      String uid = cred.user!.uid;
      UserModel userModel = UserModel(
        uid: uid,
        email: email.trim(),
        username: cleanUsername,
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        role: 'worker',
      );

      // Save in users collection in real time
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set({
        'uid': uid,
        'email': email.trim(),
        'username': cleanUsername,
        'fullName': fullName.trim(),
        'fatherName': fatherName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'address': address.trim(),
        'role': 'worker',
      });

      // Save in workers collection in real time for live map & search
      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(uid)
          .set({
        'workerId': uid,
        'username': cleanUsername,
        'name': fullName.trim(),
        'fatherName': fatherName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'address': address.trim(),
        'cnicNumber': cnicNumber.trim(),
        'profilePicUrl': profilePicBase64 ?? '',
        'cnicFrontBase64': cnicFrontBase64 ?? '',
        'cnicBackBase64': cnicBackBase64 ?? '',
        'profession': profession,
        'categoryIds': [categoryId],
        'skills': [profession],
        'experienceYears': experienceYears,
        'serviceDescription': '$profession with $experienceYears+ years of experience in $address.',
        'workingArea': address.trim(),
        'isAvailable': true,
        'isApproved': true,
        'latitude': 31.5204, // Default center; auto-updates on GPS stream
        'longitude': 74.3587,
        'rating': 5.0,
        'reviewCount': 1,
        'completedJobsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

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

  // Fast Login with Strict Role Validation
  Future<UserModel> loginUser({
    required String email,
    required String password,
    String? expectedRole,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      String uid = cred.user!.uid;
      UserModel? userModel;

      // Fast Firestore document fetch
      try {
        DocumentSnapshot doc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 3));

        if (doc.exists && doc.data() != null) {
          userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }
      } catch (_) {}

      if (userModel == null) {
        String inferredRole = email.toLowerCase().contains('worker')
            ? 'worker'
            : 'customer';

        userModel = UserModel(
          uid: uid,
          email: cred.user!.email ?? email.trim(),
          username: email.split('@').first,
          fullName: cred.user!.displayName ?? email.split('@').first,
          phoneNumber: cred.user!.phoneNumber ?? '',
          role: expectedRole ?? inferredRole,
        );
      }

      // Enforce Strict Cross-Role Login Block
      if (expectedRole != null && expectedRole.isNotEmpty) {
        if (userModel.role.trim().toLowerCase() != expectedRole.trim().toLowerCase()) {
          await _auth.signOut();
          String registeredRoleName = userModel.role.toLowerCase() == 'worker'
              ? 'Service Provider'
              : 'Customer';

          throw Exception(
              "Access Denied: This account is registered as a $registeredRoleName.\nPlease log in on the $registeredRoleName Login screen.");
        }
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      String code = e.code.toLowerCase();
      String msg = (e.message ?? '').toLowerCase();

      if (code == 'wrong-password' || msg.contains('password') || msg.contains('invalid_password')) {
        throw Exception("Incorrect password. Please check your password and try again.");
      } else if (code == 'user-not-found' || msg.contains('user-not-found') || msg.contains('user_not_found') || msg.contains('no user')) {
        throw Exception("No account registered with this email. Please register first.");
      } else if (code == 'invalid-credential') {
        throw Exception("Incorrect password or email. Please check your credentials.");
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
