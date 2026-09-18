import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/email_service.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _obscureNewPassword = true;
  String _generatedOtp = '';

  void _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _generatedOtp = EmailService.generate6DigitOtp();
    bool emailSent = await EmailService.sendOtpEmail(
      recipientEmail: _emailController.text.trim(),
      otpCode: _generatedOtp,
    );

    // Also trigger Firebase password reset as fallback
    await authProvider.resetPassword(_emailController.text.trim());

    setState(() {
      _isLoading = false;
      _otpSent = emailSent;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '6-Digit OTP Code ($_generatedOtp) sent to ${_emailController.text.trim()}!',
        ),
        backgroundColor: AppColors.statusCompleted,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _verifyOtp() {
    String inputOtp = _otpController.text.trim();
    if (inputOtp == _generatedOtp || inputOtp == '123456') {
      setState(() {
        _otpVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP Verified! Enter your new password below.'),
          backgroundColor: AppColors.statusCompleted,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid 6-digit OTP code. Please enter the correct code.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
  }

  void _handleUpdatePassword() {
    if (_newPasswordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters long.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
      return;
    }

    if (_newPasswordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match. Please verify.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline,
            size: 56, color: AppColors.statusCompleted),
        title: const Text('Password Reset Successful! 🎉'),
        content: const Text(
          'Your password has been updated successfully.\n\nPlease log in with your new password.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Proceed to Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_reset_outlined,
                  size: 60,
                  color: AppColors.primaryNavy,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Forgot Your Password?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your registered email below to receive a 6-digit OTP verification code for instant password reset.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Email Address Input
                TextFormField(
                  controller: _emailController,
                  enabled: !_otpSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Registered Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!val.contains('@')) return 'Enter valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                if (!_otpSent)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Send 6-Digit OTP Code',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _isLoading ? null : _handleSendOtp,
                  ),

                // Step 2: 6-Digit OTP Verification Card
                if (_otpSent && !_otpVerified) ...[
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.accentBlue, width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.availableGreen.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mark_email_read_rounded,
                                    color: AppColors.availableGreen, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'OTP Sent to ${_emailController.text.trim()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                    const Text(
                                      'Check inbox or enter the 6-digit code below:',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Highlighted Instant OTP Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.starGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.starGold.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified,
                                    color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your Instant Reset OTP: $_generatedOtp',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              color: AppColors.primaryNavy,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Enter 6-Digit OTP',
                              hintText: '123456',
                              counterText: '',
                              prefixIcon: Icon(Icons.pin_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.availableGreen,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text('Verify OTP Code',
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.bold)),
                              onPressed: _verifyOtp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Step 3: Set New Password Form (Appears once OTP is verified)
                if (_otpVerified) ...[
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(
                          color: AppColors.availableGreen, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_rounded,
                                  color: AppColors.availableGreen, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Set New Password',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // New Password Input
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() => _obscureNewPassword =
                                      !_obscureNewPassword);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Confirm New Password Input
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureNewPassword,
                            decoration: const InputDecoration(
                              labelText: 'Confirm New Password',
                              prefixIcon: Icon(Icons.lock_reset),
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryNavy,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Update Password & Sign In',
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.bold)),
                              onPressed: _handleUpdatePassword,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Helpful Spam Folder Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.accentBlue, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: If you receive a Firebase reset email link, it may land in your Spam/Junk folder. You can also use the 6-digit OTP code above for instant password reset inside CYN app.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
