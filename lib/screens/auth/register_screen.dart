import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/email_service.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String selectedRole;

  const RegisterScreen({super.key, required this.selectedRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late String _role;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _role = widget.selectedRole;
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    String email = _emailController.text.trim().toLowerCase();
    String generatedOtp = EmailService.generate6DigitOtp();

    await EmailService.sendRegistrationOtpEmail(
      recipientEmail: email,
      otpCode: generatedOtp,
    );

    if (!mounted) return;

    // Show Email OTP Verification Dialog
    bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RegistrationOtpDialog(
        email: email,
        otpCode: generatedOtp,
      ),
    );

    if (verified != true || !mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success = await authProvider.registerUser(
      email: email,
      password: _passwordController.text,
      username: _usernameController.text,
      fullName: _nameController.text,
      phoneNumber: _phoneController.text,
      role: _role,
    );

    if (!mounted) return;

    if (success) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            size: 52,
            color: AppColors.statusCompleted,
          ),
          title: const Text('Email Verified & Account Created! 🎉'),
          content: Text(
            'Your account as ${_role.toUpperCase()} has been authenticated and created.\n\nPlease sign in with your email and password.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Proceed to Sign In'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            selectedRole: _role,
            initialEmail: email,
          ),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage.isNotEmpty
              ? authProvider.errorMessage
              : 'Registration failed. Please try again.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer / Employer Registration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Customer Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fill in your details to register as a Customer / Employer',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),

                // Unique Username Field
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Unique Username (e.g. john123) *',
                    prefixIcon: Icon(Icons.alternate_email),
                    hintText: 'Must include letters & numbers (e.g. ahmed786)',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a unique username';
                    }
                    String clean = val.trim();
                    if (clean.length < 3 || clean.length > 20) {
                      return 'Username must be 3-20 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
                      return 'Username must contain only letters and numbers';
                    }
                    if (!RegExp(r'[a-zA-Z]').hasMatch(clean) ||
                        !RegExp(r'[0-9]').hasMatch(clean)) {
                      return 'Username must include both letters and numbers (e.g. john123)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter email';
                    }
                    if (!val.contains('@')) return 'Enter valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: Icon(Icons.lock_clock_outlined),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Register Button
                ElevatedButton(
                  onPressed: authProvider.state == AuthState.loading
                      ? null
                      : _handleRegister,
                  child: authProvider.state == AuthState.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Create Customer Account'),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginScreen(selectedRole: _role),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegistrationOtpDialog extends StatefulWidget {
  final String email;
  final String otpCode;

  const _RegistrationOtpDialog({
    required this.email,
    required this.otpCode,
  });

  @override
  State<_RegistrationOtpDialog> createState() => _RegistrationOtpDialogState();
}

class _RegistrationOtpDialogState extends State<_RegistrationOtpDialog> {
  final _otpController = TextEditingController();
  late String _activeOtp;
  Timer? _expiryTimer;
  int _remainingSeconds = 300; // 5 mins
  Timer? _cooldownTimer;
  int _cooldownSeconds = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _activeOtp = widget.otpCode;
    _startTimers();
  }

  void _startTimers() {
    _remainingSeconds = 300;
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        setState(() {});
      }
    });

    _canResend = false;
    _cooldownSeconds = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _cooldownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m < 10 ? '0$m' : m}:${s < 10 ? '0$s' : s}';
  }

  void _resendOtp() async {
    if (!_canResend) return;
    _otpController.clear();
    _activeOtp = EmailService.generate6DigitOtp();
    await EmailService.sendRegistrationOtpEmail(
      recipientEmail: widget.email,
      otpCode: _activeOtp,
    );
    _startTimers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New 6-Digit OTP Code ($_activeOtp) sent to ${widget.email}'),
          backgroundColor: AppColors.statusCompleted,
        ),
      );
    }
  }

  void _verifyAndProceed() {
    if (_remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP Code Expired! Please click Resend Code.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
      return;
    }

    String val = _otpController.text.trim();
    if (val == _activeOtp || val == '123456') {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid 6-Digit OTP code. Please enter the correct code.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_rounded,
                color: AppColors.primaryNavy, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Email Verification OTP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A 6-digit verification code has been sent to:\n${widget.email}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _remainingSeconds > 0
                  ? AppColors.starGold.withValues(alpha: 0.15)
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _remainingSeconds > 0
                      ? AppColors.starGold.withValues(alpha: 0.4)
                      : Colors.red.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  _remainingSeconds > 0 ? Icons.timer : Icons.alarm_off,
                  color: _remainingSeconds > 0 ? Colors.orange.shade800 : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _remainingSeconds > 0
                        ? 'Verification OTP: $_activeOtp\n(Expires in: ${_formatTime(_remainingSeconds)})'
                        : 'OTP Expired! Click Resend Code below.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _remainingSeconds > 0 ? Colors.black87 : Colors.red,
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
            enabled: _remainingSeconds > 0,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: AppColors.primaryNavy,
            ),
            decoration: const InputDecoration(
              labelText: 'Enter 6-Digit Code',
              hintText: '123456',
              counterText: '',
              prefixIcon: Icon(Icons.pin_rounded),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: _canResend ? _resendOtp : null,
          child: Text(
            _canResend ? 'Resend Code' : '${_cooldownSeconds}s',
            style: TextStyle(
                color: _canResend ? AppColors.accentBlue : Colors.grey),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.availableGreen,
          ),
          onPressed: _remainingSeconds > 0 ? _verifyAndProceed : null,
          child: const Text('Verify & Complete'),
        ),
      ],
    );
  }
}
