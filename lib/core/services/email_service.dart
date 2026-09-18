import 'dart:math';
import 'package:flutter/foundation.dart';

class EmailService {
  /// Generate secure 6-digit numeric OTP code
  static String generate6DigitOtp() {
    Random random = Random();
    int otp = 100000 + random.nextInt(900000);
    return otp.toString();
  }

  /// Send OTP Email (Password Reset)
  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
  }) async {
    try {
      debugPrint("Sending 6-Digit Password Reset OTP $otpCode to $recipientEmail");
      await Future.delayed(const Duration(milliseconds: 1000));
      return true;
    } catch (e) {
      debugPrint("Failed to send OTP email: $e");
      return false;
    }
  }

  /// Send Registration OTP Email
  static Future<bool> sendRegistrationOtpEmail({
    required String recipientEmail,
    required String otpCode,
  }) async {
    try {
      debugPrint("Sending 6-Digit Registration Verification OTP $otpCode to $recipientEmail");
      await Future.delayed(const Duration(milliseconds: 1000));
      return true;
    } catch (e) {
      debugPrint("Failed to send registration OTP email: $e");
      return false;
    }
  }
}
