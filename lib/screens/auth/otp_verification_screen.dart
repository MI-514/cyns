import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'new_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String generatedOtp;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.generatedOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isVerifying = false;

  void _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isVerifying = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool isValid =
        await authProvider.verifyOtp(widget.email, _otpController.text.trim());

    setState(() => _isVerifying = false);

    if (!mounted) return;

    if (isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP Verified Successfully!'),
          backgroundColor: AppColors.statusCompleted,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NewPasswordScreen(email: widget.email),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage.isNotEmpty
              ? authProvider.errorMessage
              : 'Wrong 6-Digit OTP. Please enter the correct code.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter 6-Digit OTP'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top OTP Preview Banner for Test Verification
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.key, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Text(
                        '🔑 Your 6-Digit OTP Code: ${widget.generatedOtp}',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: AppColors.primaryNavy,
                ),
                const SizedBox(height: 16),

                const Text(
                  'Verify 6-Digit OTP Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'A 6-digit OTP code has been generated for ${widget.email}.\nEnter the code below to proceed with password update:',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 32),

                // OTP 6-Digit Field
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: const InputDecoration(
                    hintText: '000000',
                    prefixIcon: Icon(Icons.security),
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length != 6) {
                      return 'Please enter 6-digit OTP code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Verify OTP Code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
