import 'dart:math';
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

  /// Check if an email is registered in Cloud Firestore
  Future<bool> isEmailRegistered(String email) async {
    try {
      String clean = email.trim().toLowerCase();
      QuerySnapshot snap = await _firestore
          .collection(FirestoreCollections.users)
          .where('email', isEqualTo: clean)
          .get()
          .timeout(const Duration(seconds: 4));
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
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
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set(userModel.toMap());

      if (role == 'customer') {
        await _firestore
            .collection(FirestoreCollections.customers)
            .doc(uid)
            .set({
          'customerId': uid,
          'username': cleanUsername,
          'name': fullName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'profilePicUrl': '',
          'address': '',
        });
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

  // Step-by-Step Validated Login
  Future<UserModel> loginUser({
    required String email,
    required String password,
  }) async {
    String cleanEmail = email.trim().toLowerCase();

    // STEP 1: Verify Email Registration
    bool isRegistered = await isEmailRegistered(cleanEmail);
    if (!isRegistered) {
      throw Exception("This email is not registered. Please register first.");
    }

    // STEP 2: Verify Password via Firebase Auth
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      String uid = cred.user!.uid;

      // Always fetch real Firestore User document
      try {
        DocumentSnapshot doc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 4));

        if (doc.exists && doc.data() != null) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }
      } catch (_) {}

      String inferredRole = cleanEmail.contains('worker') ? 'worker' : 'customer';

      return UserModel(
        uid: uid,
        email: cred.user!.email ?? cleanEmail,
        username: cleanEmail.split('@').first,
        fullName: cred.user!.displayName ?? 'User',
        phoneNumber: cred.user!.phoneNumber ?? '',
        role: inferredRole,
      );
    } on FirebaseAuthException catch (e) {
      String code = e.code.toLowerCase();
      String msg = (e.message ?? '').toLowerCase();

      if (code == 'wrong-password' || msg.contains('password') || msg.contains('invalid_password') || code == 'invalid-credential') {
        throw Exception("Wrong password. Please enter the correct password.");
      } else if (code == 'user-not-found' || msg.contains('user-not-found')) {
        throw Exception("This email is not registered. Please register first.");
      } else if (code == 'user-disabled') {
        throw Exception("This account has been suspended or disabled.");
      } else {
        throw Exception("Wrong password. Please enter the correct password.");
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Generate & Send 6-Digit OTP & Firebase Reset Email directly to Gmail Inbox
  Future<String> sendPasswordResetOtp(String email) async {
    String cleanEmail = email.trim().toLowerCase();

    // Step 1: Verify Email Registration in Firestore
    bool isRegistered = await isEmailRegistered(cleanEmail);
    if (!isRegistered) {
      throw Exception("This email is not registered in CYN. Please enter your registered email.");
    }

    // Step 2: Generate 6-Digit OTP Code
    String otp = (Random().nextInt(900000) + 100000).toString();

    // Step 3: Save OTP in Firestore `password_resets` collection with 10min expiry
    await _firestore
        .collection('password_resets')
        .doc(cleanEmail)
        .set({
      'email': cleanEmail,
      'otp': otp,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Step 4: Send Official Password Reset Email to Gmail via Firebase Auth
    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception("This email is not registered in CYN.");
      } else if (e.code == 'invalid-email') {
        throw Exception("Invalid email address format.");
      } else {
        throw Exception(e.message ?? "Failed to send reset email to $cleanEmail.");
      }
    }

    return otp;
  }

  /// Verify 6-Digit OTP
  Future<bool> verifyOtp(String email, String inputOtp) async {
    try {
      String cleanEmail = email.trim().toLowerCase();
      DocumentSnapshot doc = await _firestore
          .collection('password_resets')
          .doc(cleanEmail)
          .get();

      if (!doc.exists || doc.data() == null) {
        throw Exception("Invalid OTP. Please request a new OTP code.");
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String storedOtp = data['otp'] ?? '';
      Timestamp? expiresAt = data['expiresAt'] as Timestamp?;

      if (storedOtp != inputOtp.trim()) {
        throw Exception("Wrong OTP code. Please enter the correct 6-digit OTP.");
      }

      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        throw Exception("OTP code has expired. Please request a new OTP.");
      }

      return true;
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
          .timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (_) {}
    return null;
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }
}
