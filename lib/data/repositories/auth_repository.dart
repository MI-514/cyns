import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final ActionCodeSettings _actionCodeSettings = ActionCodeSettings(
    url: 'https://cyns-f77ec.firebaseapp.com',
    handleCodeInApp: true,
    androidPackageName: 'com.example.cyns',
    androidInstallApp: true,
    androidMinimumVersion: '12',
  );

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

  /// Check if an email is registered in Cloud Firestore across users, workers, or customers
  Future<bool> isEmailRegistered(String email) async {
    try {
      String clean = email.trim().toLowerCase();

      QuerySnapshot userSnap = await _firestore
          .collection(FirestoreCollections.users)
          .where('email', isEqualTo: clean)
          .get()
          .timeout(const Duration(seconds: 4));
      if (userSnap.docs.isNotEmpty) return true;

      QuerySnapshot workerSnap = await _firestore
          .collection(FirestoreCollections.workers)
          .where('email', isEqualTo: clean)
          .get()
          .timeout(const Duration(seconds: 4));
      if (workerSnap.docs.isNotEmpty) return true;

      QuerySnapshot customerSnap = await _firestore
          .collection(FirestoreCollections.customers)
          .where('email', isEqualTo: clean)
          .get()
          .timeout(const Duration(seconds: 4));
      if (customerSnap.docs.isNotEmpty) return true;
    } catch (_) {}
    return false;
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

  // Register Customer with Self-Healing Orphaned Auth Recovery
  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String phoneNumber,
    required String role,
  }) async {
    String cleanUsername = username.trim().toLowerCase();
    String cleanEmail = email.trim().toLowerCase();

    bool isAvailable = await isUsernameAvailable(cleanUsername);
    if (!isAvailable) {
      throw Exception("Username '$cleanUsername' is already taken. Please choose another unique username.");
    }

    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      if (cred.user != null) {
        try {
          await cred.user!.sendEmailVerification(_actionCodeSettings);
        } catch (_) {}
      }

      String uid = cred.user!.uid;
      UserModel userModel = UserModel(
        uid: uid,
        email: cleanEmail,
        username: cleanUsername,
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        role: role,
      );

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
          'email': cleanEmail,
          'username': cleanUsername,
          'name': fullName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'profilePicUrl': '',
          'address': '',
        }, SetOptions(merge: true));
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Self-Healing Recovery: If Auth exists but Firestore profile was reset/deleted, sign in & re-provision profile!
        try {
          UserCredential cred = await _auth.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password.trim(),
          );
          String uid = cred.user!.uid;

          UserModel userModel = UserModel(
            uid: uid,
            email: cleanEmail,
            username: cleanUsername,
            fullName: fullName.trim(),
            phoneNumber: phoneNumber.trim(),
            role: role,
          );

          await _firestore.collection(FirestoreCollections.users).doc(uid).set(userModel.toMap());
          if (role == 'customer') {
            await _firestore.collection(FirestoreCollections.customers).doc(uid).set({
              'customerId': uid,
              'email': cleanEmail,
              'username': cleanUsername,
              'name': fullName.trim(),
              'phoneNumber': phoneNumber.trim(),
            }, SetOptions(merge: true));
          }
          return userModel;
        } catch (_) {
          throw Exception("An account already exists for this email with a different password. Please sign in or reset your password.");
        }
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

  // Advanced Worker Registration with Self-Healing Orphaned Auth Recovery
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
    String cleanEmail = email.trim().toLowerCase();

    bool isAvailable = await isUsernameAvailable(cleanUsername);
    if (!isAvailable) {
      throw Exception("Username '$cleanUsername' is already taken. Please choose another unique username.");
    }

    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      if (cred.user != null) {
        try {
          await cred.user!.sendEmailVerification(_actionCodeSettings);
        } catch (_) {}
      }

      String uid = cred.user!.uid;
      UserModel userModel = UserModel(
        uid: uid,
        email: cleanEmail,
        username: cleanUsername,
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        role: 'worker',
      );

      await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set({
        'uid': uid,
        'email': cleanEmail,
        'username': cleanUsername,
        'fullName': fullName.trim(),
        'fatherName': fatherName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'address': address.trim(),
        'role': 'worker',
      });

      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(uid)
          .set({
        'workerId': uid,
        'email': cleanEmail,
        'username': cleanUsername,
        'name': fullName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'address': address.trim(),
        'profilePicUrl': profilePicBase64 ?? '',
        'profession': profession,
        'categoryIds': [categoryId],
        'skills': [profession],
        'experienceYears': experienceYears,
        'serviceDescription': '$profession with $experienceYears+ years of experience in $address.',
        'workingArea': address.trim(),
        'isAvailable': true,
        'isApproved': true,
        'rating': 0.0,
        'reviewCount': 0,
        'completedJobsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(uid)
          .collection('private')
          .doc('identity')
          .set({
        'fatherName': fatherName.trim(),
        'cnicNumber': cnicNumber.trim(),
        'cnicFrontBase64': cnicFrontBase64 ?? '',
        'cnicBackBase64': cnicBackBase64 ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return userModel;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          UserCredential cred = await _auth.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password.trim(),
          );
          String uid = cred.user!.uid;

          UserModel userModel = UserModel(
            uid: uid,
            email: cleanEmail,
            username: cleanUsername,
            fullName: fullName.trim(),
            phoneNumber: phoneNumber.trim(),
            role: 'worker',
          );

          await _firestore.collection(FirestoreCollections.users).doc(uid).set({
            'uid': uid,
            'email': cleanEmail,
            'username': cleanUsername,
            'fullName': fullName.trim(),
            'fatherName': fatherName.trim(),
            'phoneNumber': phoneNumber.trim(),
            'address': address.trim(),
            'role': 'worker',
          }, SetOptions(merge: true));

          await _firestore.collection(FirestoreCollections.workers).doc(uid).set({
            'workerId': uid,
            'email': cleanEmail,
            'username': cleanUsername,
            'name': fullName.trim(),
            'phoneNumber': phoneNumber.trim(),
            'address': address.trim(),
            'profession': profession,
            'categoryIds': [categoryId],
            'skills': [profession],
            'experienceYears': experienceYears,
            'serviceDescription': '$profession with $experienceYears+ years of experience in $address.',
            'workingArea': address.trim(),
            'isAvailable': true,
            'isApproved': true,
          }, SetOptions(merge: true));

          return userModel;
        } catch (_) {
          throw Exception("An account already exists for this email with a different password. Please sign in or reset your password.");
        }
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

  // Fast Seamless Login with Multi-Collection Role & Data Detection
  Future<UserModel> loginUser({
    required String email,
    required String password,
  }) async {
    String cleanEmail = email.trim().toLowerCase();

    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      if (cred.user != null) {
        await cred.user!.reload();

        if (!cred.user!.emailVerified) {
          await _auth.signOut();
          throw Exception("Please verify your email address first. Check your Gmail inbox ($cleanEmail) and click the verification link to activate your account.");
        }
      }

      String uid = cred.user!.uid;

      // STEP 1: Check workers collection first (If document exists in workers/{uid}, this is 100% a Worker!)
      try {
        DocumentSnapshot workerDoc = await _firestore
            .collection(FirestoreCollections.workers)
            .doc(uid)
            .get();

        if (workerDoc.exists && workerDoc.data() != null) {
          Map<String, dynamic> wData = workerDoc.data() as Map<String, dynamic>;

          String wName = (wData['name'] ?? wData['fullName'] ?? '').toString().trim();
          String wUsername = (wData['username'] ?? wData['userName'] ?? '').toString().trim();
          String wPhone = (wData['phoneNumber'] ?? wData['phone'] ?? '').toString().trim();

          if (wName.isEmpty) wName = 'Worker';
          if (wUsername.isEmpty) wUsername = cleanEmail.split('@').first;

          await _firestore.collection(FirestoreCollections.users).doc(uid).set({
            'uid': uid,
            'email': wData['email'] ?? cleanEmail,
            'username': wUsername,
            'fullName': wName,
            'phoneNumber': wPhone,
            'role': 'worker',
          }, SetOptions(merge: true));

          return UserModel(
            uid: uid,
            email: wData['email'] ?? cleanEmail,
            username: wUsername,
            fullName: wName,
            phoneNumber: wPhone,
            role: 'worker',
          );
        }
      } catch (_) {}

      // STEP 2: Check users collection
      try {
        DocumentSnapshot userDoc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> uData = userDoc.data() as Map<String, dynamic>;
          String role = (uData['role'] ?? '').toString().toLowerCase();

          String fullName = (uData['fullName'] ?? uData['name'] ?? '').toString().trim();
          String username = (uData['username'] ?? uData['userName'] ?? '').toString().trim();
          String phoneNumber = (uData['phoneNumber'] ?? uData['phone'] ?? '').toString().trim();

          if (fullName.isEmpty) fullName = role == 'worker' ? 'Worker' : 'Customer';
          if (username.isEmpty) username = cleanEmail.split('@').first;

          return UserModel(
            uid: uid,
            email: uData['email'] ?? cleanEmail,
            username: username,
            fullName: fullName,
            phoneNumber: phoneNumber,
            role: role.isNotEmpty ? role : (cleanEmail.contains('worker') ? 'worker' : 'customer'),
          );
        }
      } catch (_) {}

      // STEP 3: Check customers collection
      try {
        DocumentSnapshot cDoc = await _firestore
            .collection(FirestoreCollections.customers)
            .doc(uid)
            .get();

        if (cDoc.exists && cDoc.data() != null) {
          Map<String, dynamic> cData = cDoc.data() as Map<String, dynamic>;

          String cName = (cData['name'] ?? cData['fullName'] ?? '').toString().trim();
          String cUsername = (cData['username'] ?? cData['userName'] ?? '').toString().trim();
          String cPhone = (cData['phoneNumber'] ?? cData['phone'] ?? '').toString().trim();

          if (cName.isEmpty) cName = 'Customer';
          if (cUsername.isEmpty) cUsername = cleanEmail.split('@').first;

          await _firestore.collection(FirestoreCollections.users).doc(uid).set({
            'uid': uid,
            'email': cData['email'] ?? cleanEmail,
            'username': cUsername,
            'fullName': cName,
            'phoneNumber': cPhone,
            'role': 'customer',
          }, SetOptions(merge: true));

          return UserModel(
            uid: uid,
            email: cData['email'] ?? cleanEmail,
            username: cUsername,
            fullName: cName,
            phoneNumber: cPhone,
            role: 'customer',
          );
        }
      } catch (_) {}

      String inferredRole = cleanEmail.contains('worker') ? 'worker' : 'customer';

      return UserModel(
        uid: uid,
        email: cred.user!.email ?? cleanEmail,
        username: cleanEmail.split('@').first,
        fullName: cred.user!.displayName ?? (inferredRole == 'worker' ? 'Worker' : 'Customer'),
        phoneNumber: cred.user!.phoneNumber ?? '',
        role: inferredRole,
      );
    } on FirebaseAuthException catch (e) {
      String code = e.code.toLowerCase();
      String msg = (e.message ?? '').toLowerCase();

      if (code == 'wrong-password' || msg.contains('password') || msg.contains('invalid_password') || code == 'invalid-credential') {
        throw Exception("Wrong password. Please enter the correct password.");
      } else if (code == 'user-not-found' || msg.contains('user-not-found')) {
        throw Exception("This email ($cleanEmail) is not registered in CYN. Please register first.");
      } else if (code == 'user-disabled') {
        throw Exception("This account has been suspended or disabled.");
      } else {
        throw Exception("Sign in failed: ${e.message ?? 'Please check your email and password.'}");
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Option to resend email verification link
  Future<void> resendVerificationEmail(String email, String password) async {
    String cleanEmail = email.trim().toLowerCase();
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );
      if (cred.user != null) {
        await cred.user!.sendEmailVerification(_actionCodeSettings);
        await _auth.signOut();
      }
    } catch (e) {
      throw Exception("Failed to resend verification email: ${e.toString().replaceAll('Exception: ', '')}");
    }
  }

  /// Official Firebase Auth sendPasswordResetEmail() with ActionCodeSettings
  Future<void> sendPasswordResetEmail(String email) async {
    String cleanEmail = email.trim().toLowerCase();

    bool isRegistered = await isEmailRegistered(cleanEmail);
    if (!isRegistered) {
      throw Exception("This email ($cleanEmail) is not registered in CYN.");
    }

    try {
      await _auth.sendPasswordResetEmail(
        email: cleanEmail,
        actionCodeSettings: _actionCodeSettings,
      );
      debugPrint("[Firebase Auth] sendPasswordResetEmail() successful for $cleanEmail");
    } on FirebaseAuthException catch (e) {
      debugPrint("[Firebase Auth Error] sendPasswordResetEmail (${e.code}): ${e.message}");
      if (e.code == 'user-not-found') {
        throw Exception("This email ($cleanEmail) is not registered in CYN.");
      } else if (e.code == 'invalid-email') {
        throw Exception("Invalid email address format.");
      } else {
        try {
          await _auth.sendPasswordResetEmail(email: cleanEmail);
        } catch (_) {
          throw Exception(e.message ?? "Failed to send reset email.");
        }
      }
    }
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

  // Fast Get User Profile Document with Multi-Collection Fallback & Full Alias Matching
  Future<UserModel?> getUserModel(String uid) async {
    try {
      DocumentSnapshot wDoc = await _firestore
          .collection(FirestoreCollections.workers)
          .doc(uid)
          .get();

      if (wDoc.exists && wDoc.data() != null) {
        Map<String, dynamic> wData = wDoc.data() as Map<String, dynamic>;
        String wName = (wData['name'] ?? wData['fullName'] ?? 'Worker').toString().trim();
        String wUsername = (wData['username'] ?? wData['userName'] ?? '').toString().trim();
        String wPhone = (wData['phoneNumber'] ?? wData['phone'] ?? '').toString().trim();

        if (wName.isEmpty) wName = 'Worker';

        return UserModel(
          uid: uid,
          email: wData['email'] ?? '',
          username: wUsername,
          fullName: wName,
          phoneNumber: wPhone,
          role: 'worker',
        );
      }

      DocumentSnapshot doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> uData = doc.data() as Map<String, dynamic>;
        String role = (uData['role'] ?? '').toString().toLowerCase();

        String fullName = (uData['fullName'] ?? uData['name'] ?? '').toString().trim();
        String username = (uData['username'] ?? uData['userName'] ?? '').toString().trim();
        String phoneNumber = (uData['phoneNumber'] ?? uData['phone'] ?? '').toString().trim();

        if (fullName.isEmpty) fullName = role == 'worker' ? 'Worker' : 'Customer';

        if (role == 'worker') {
          DocumentSnapshot workerDoc = await _firestore
              .collection(FirestoreCollections.workers)
              .doc(uid)
              .get();

          Map<String, dynamic> wData = workerDoc.exists && workerDoc.data() != null
              ? workerDoc.data() as Map<String, dynamic>
              : {};

          return UserModel(
            uid: uid,
            email: uData['email'] ?? wData['email'] ?? '',
            username: username.isNotEmpty ? username : (wData['username'] ?? ''),
            fullName: fullName != 'Worker' ? fullName : (wData['name'] ?? 'Worker'),
            phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : (wData['phoneNumber'] ?? ''),
            role: 'worker',
          );
        } else {
          DocumentSnapshot customerDoc = await _firestore
              .collection(FirestoreCollections.customers)
              .doc(uid)
              .get();

          Map<String, dynamic> cData = customerDoc.exists && customerDoc.data() != null
              ? customerDoc.data() as Map<String, dynamic>
              : {};

          return UserModel(
            uid: uid,
            email: uData['email'] ?? cData['email'] ?? '',
            username: username.isNotEmpty ? username : (cData['username'] ?? ''),
            fullName: fullName != 'Customer' ? fullName : (cData['name'] ?? 'Customer'),
            phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : (cData['phoneNumber'] ?? ''),
            role: 'customer',
          );
        }
      }

      DocumentSnapshot cDoc = await _firestore
          .collection(FirestoreCollections.customers)
          .doc(uid)
          .get();

      if (cDoc.exists && cDoc.data() != null) {
        Map<String, dynamic> cData = cDoc.data() as Map<String, dynamic>;
        String cName = (cData['name'] ?? cData['fullName'] ?? 'Customer').toString().trim();
        String cUsername = (cData['username'] ?? cData['userName'] ?? '').toString().trim();
        String cPhone = (cData['phoneNumber'] ?? cData['phone'] ?? '').toString().trim();

        return UserModel(
          uid: uid,
          email: cData['email'] ?? '',
          username: cUsername,
          fullName: cName,
          phoneNumber: cPhone,
          role: 'customer',
        );
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
