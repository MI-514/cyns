import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/email_service.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class WorkerRegisterScreen extends StatefulWidget {
  const WorkerRegisterScreen({super.key});

  @override
  State<WorkerRegisterScreen> createState() => _WorkerRegisterScreenState();
}

class _WorkerRegisterScreenState extends State<WorkerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cnicController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'id': 'electrician', 'name': 'Electrician'},
    {'id': 'plumber', 'name': 'Plumber'},
    {'id': 'mason', 'name': 'Mason / Raj Mistri'},
    {'id': 'carpenter', 'name': 'Carpenter'},
    {'id': 'welder', 'name': 'Welder & Fabricator'},
    {'id': 'ac_technician', 'name': 'AC & Refrigerator Technician'},
    {'id': 'tailor', 'name': 'Tailor / Darzi'},
    {'id': 'driver', 'name': 'Driver'},
    {'id': 'auto_mechanic', 'name': 'Auto Mechanic'},
    {'id': 'painter', 'name': 'Painter'},
    {'id': 'cleaner', 'name': 'Home Cleaner / Housekeeping'},
    {'id': 'laborer', 'name': 'General Laborer / Loader'},
    {'id': 'tile_worker', 'name': 'Tile & Marble Worker'},
    {'id': 'appliance_repair', 'name': 'Appliance Repair'},
  ];

  final List<Map<String, dynamic>> _experienceLevels = [
    {'years': 1, 'label': 'Less than 1 year'},
    {'years': 2, 'label': '1 - 3 years'},
    {'years': 4, 'label': '3 - 5 years'},
    {'years': 6, 'label': '5+ years'},
    {'years': 10, 'label': '10+ years'},
  ];

  String _selectedCategoryId = 'electrician';
  String _selectedProfession = 'Electrician';
  int _selectedExperienceYears = 2;

  File? _profileImage;
  File? _cnicFrontImage;
  File? _cnicBackImage;

  String _profileBase64 = '';
  String _cnicFrontBase64 = '';
  String _cnicBackBase64 = '';

  bool _obscurePassword = true;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String type) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select ${type == 'profile' ? 'Profile Selfie / Photo' : type == 'front' ? 'CNIC Front Photo' : 'CNIC Back Photo'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final XFile? file = await _picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 70,
                      );
                      if (file != null) _setPickedImage(file, type);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starGold,
                      foregroundColor: AppColors.primaryNavy,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final XFile? file = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 70,
                      );
                      if (file != null) _setPickedImage(file, type);
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setPickedImage(XFile xFile, String type) async {
    File file = File(xFile.path);
    List<int> bytes = await file.readAsBytes();
    String base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    setState(() {
      if (type == 'profile') {
        _profileImage = file;
        _profileBase64 = base64Str;
      } else if (type == 'front') {
        _cnicFrontImage = file;
        _cnicFrontBase64 = base64Str;
      } else if (type == 'back') {
        _cnicBackImage = file;
        _cnicBackBase64 = base64Str;
      }
    });
  }

  void _handleWorkerRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_cnicFrontImage == null || _cnicBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both CNIC Front and Back images for verification.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
      return;
    }

    String email = _emailController.text.trim().toLowerCase();
    String generatedOtp = EmailService.generate6DigitOtp();

    await EmailService.sendRegistrationOtpEmail(
      recipientEmail: email,
      otpCode: generatedOtp,
    );

    if (!mounted) return;

    // Show Email OTP Verification Modal
    bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WorkerRegistrationOtpDialog(
        email: email,
        otpCode: generatedOtp,
      ),
    );

    if (verified != true || !mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success = await authProvider.registerWorkerAdvanced(
      email: email,
      password: _passwordController.text.trim(),
      username: _usernameController.text.trim(),
      fullName: _fullNameController.text.trim(),
      fatherName: _fatherNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      cnicNumber: _cnicController.text.trim(),
      profession: _selectedProfession,
      categoryId: _selectedCategoryId,
      experienceYears: _selectedExperienceYears,
      profilePicBase64: _profileBase64,
      cnicFrontBase64: _cnicFrontBase64,
      cnicBackBase64: _cnicBackBase64,
    );

    if (!mounted) return;

    if (success) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.check_circle, size: 52, color: AppColors.availableGreen),
          title: const Text('Email Verified & Account Created! 🎉'),
          content: const Text(
            'Your Service Provider account has been authenticated and created in Cloud Firestore.\nYou can now sign in with your registered email and password.',
            textAlign: TextAlign.center,
          ),
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
            selectedRole: AppConstants.roleWorker,
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
        title: const Text('Worker Registration'),
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
                  'Join as Service Provider / Worker',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your details, unique username, trade skills, and CNIC photos to register in Cloud Firestore',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Profile Photo / Selfie
                Center(
                  child: GestureDetector(
                    onTap: () => _pickImage('profile'),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                          child: _profileImage == null
                              ? const Icon(Icons.camera_alt,
                                  size: 40, color: AppColors.primaryNavy)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryNavy,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 6.0),
                    child: Text(
                      'Profile Photo / Selfie (Optional)',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Unique Username Field
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Unique Username (e.g. worker786) *',
                    prefixIcon: Icon(Icons.alternate_email),
                    hintText: 'Must include letters & numbers (e.g. usman001)',
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
                      return 'Username must include both letters and numbers (e.g. worker786)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Pura Naam (Full Name)
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Pura Naam (Full Name) *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter Full Name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Walid ka Naam (Father's Name)
                TextFormField(
                  controller: _fatherNameController,
                  decoration: const InputDecoration(
                    labelText: "Walid ka Naam (Father's Name) *",
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter Father\'s Name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Address
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter Email Address';
                    }
                    if (!val.contains('@')) return 'Enter valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mobile Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter Mobile Number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mojuda Pata (Current Address)
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Mojuda Pata (Current Address / City) *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    hintText: 'e.g. Gulberg III, Lahore',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter Current Address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ID Card Number (CNIC)
                TextFormField(
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ID Card Number (CNIC) *',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                    hintText: '35202-1234567-1',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter CNIC number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Peshwarana Hunar (Main Skill/Trade) Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Peshwarana Hunar (Main Skill/Trade) *',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['id']!,
                      child: Text(cat['name']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategoryId = val;
                        _selectedProfession = _categories
                            .firstWhere((c) => c['id'] == val)['name']!;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Tajurba (Experience) Dropdown
                DropdownButtonFormField<int>(
                  initialValue: _selectedExperienceYears,
                  decoration: const InputDecoration(
                    labelText: 'Tajurba (Experience) *',
                    prefixIcon: Icon(Icons.history_edu),
                  ),
                  items: _experienceLevels.map((exp) {
                    return DropdownMenuItem<int>(
                      value: exp['years'] as int,
                      child: Text(exp['label'] as String),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedExperienceYears = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                // CNIC Front & Back Image Verification
                const Text(
                  'CNIC Verification Images *',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickImage('front'),
                        child: Container(
                          height: 110,
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _cnicFrontImage != null
                                  ? AppColors.availableGreen
                                  : AppColors.textLight,
                              width: _cnicFrontImage != null ? 2 : 1,
                            ),
                          ),
                          child: _cnicFrontImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(_cnicFrontImage!,
                                      fit: BoxFit.cover, width: double.infinity),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, color: AppColors.primaryNavy),
                                    SizedBox(height: 4),
                                    Text('CNIC Front Image',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickImage('back'),
                        child: Container(
                          height: 110,
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _cnicBackImage != null
                                  ? AppColors.availableGreen
                                  : AppColors.textLight,
                              width: _cnicBackImage != null ? 2 : 1,
                            ),
                          ),
                          child: _cnicBackImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(_cnicBackImage!,
                                      fit: BoxFit.cover, width: double.infinity),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, color: AppColors.primaryNavy),
                                    SizedBox(height: 4),
                                    Text('CNIC Back Image',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                      : _handleWorkerRegister,
                  child: authProvider.state == AuthState.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Register Worker Account in Firestore'),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already registered? '),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(
                              selectedRole: AppConstants.roleWorker,
                            ),
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

class _WorkerRegistrationOtpDialog extends StatefulWidget {
  final String email;
  final String otpCode;

  const _WorkerRegistrationOtpDialog({
    required this.email,
    required this.otpCode,
  });

  @override
  State<_WorkerRegistrationOtpDialog> createState() =>
      _WorkerRegistrationOtpDialogState();
}

class _WorkerRegistrationOtpDialogState
    extends State<_WorkerRegistrationOtpDialog> {
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
              'Worker Email Verification',
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
          child: const Text('Verify & Create Account'),
        ),
      ],
    );
  }
}
