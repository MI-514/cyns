import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class WorkerRegisterScreen extends StatefulWidget {
  const WorkerRegisterScreen({super.key});

  @override
  State<WorkerRegisterScreen> createState() => _WorkerRegisterScreenState();
}

class _WorkerRegisterScreenState extends State<WorkerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnicController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'id': 'electrician', 'name': 'Electrician'},
    {'id': 'plumber', 'name': 'Plumber'},
    {'id': 'painter', 'name': 'Painter'},
    {'id': 'mechanic', 'name': 'Auto Mechanic'},
    {'id': 'carpenter', 'name': 'Carpenter'},
    {'id': 'ac_technician', 'name': 'AC & Fridge Technician'},
    {'id': 'appliance_repair', 'name': 'Appliance Repair'},
    {'id': 'cleaner', 'name': 'Home Cleaner'},
    {'id': 'gardener', 'name': 'Gardener'},
    {'id': 'welder', 'name': 'Welder & Fabricator'},
    {'id': 'mason', 'name': 'Mason / Builder'},
    {'id': 'locksmith', 'name': 'Locksmith'},
    {'id': 'handyman', 'name': 'General Handyman'},
  ];

  String _selectedCategoryId = 'electrician';
  String _selectedProfession = 'Electrician';

  File? _profileImage; // Front selfie / live photo
  File? _cnicFrontImage;
  File? _cnicBackImage;
  File? _certificateImage; // Optional certificate

  String _profileBase64 = '';
  String _cnicFrontBase64 = '';
  String _cnicBackBase64 = '';
  String _certificateBase64 = '';

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
                'Select ${type == 'profile' ? 'Profile Selfie' : type == 'front' ? 'CNIC Front Photo' : type == 'back' ? 'CNIC Back Photo' : 'Certificate / License (Optional)'}',
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
    String base64Str = base64Encode(bytes);

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
      } else if (type == 'cert') {
        _certificateImage = file;
        _certificateBase64 = base64Str;
      }
    });
  }

  void _handleWorkerRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_cnicFrontImage == null || _cnicBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both ID card front and back images.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

    bool success = await authProvider.registerUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      fullName: fullName,
      phoneNumber: _phoneController.text.trim(),
      role: AppConstants.roleWorker,
    );

    if (!mounted) return;

    if (success) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.check_circle, size: 52, color: AppColors.availableGreen),
          title: const Text('Registration Successful!'),
          content: const Text(
            'Your Service Provider account has been created successfully.\nYou can now sign in with your email and password.',
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
            initialEmail: _emailController.text.trim(),
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
        title: const Text('Service Provider Registration'),
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
                  'Join as Service Provider',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fill in your professional details and verification documents',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),

                // Front Selfie / Live Photo Picker
                Center(
                  child: GestureDetector(
                    onTap: () => _pickImage('profile'),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
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
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Tap to take Profile Photo / Selfie',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // First Name & Last Name
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter first name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter last name';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Email Address
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
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
                    labelText: 'Phone Number',
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

                // ID Card Number (CNIC)
                TextFormField(
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ID Card Number (CNIC)',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                    hintText: '35202-1234567-1',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter ID card number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Skills / Service Categories Selector
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Skills Category',
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
                const SizedBox(height: 24),

                // ID Card Front & Back Image Pickers
                const Text(
                  'ID Card Verification Photos',
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
                                    Text('ID Card Front',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                                    Text('ID Card Back',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Certificate Upload (Optional)
                const Text(
                  'Professional Certificate / License (Optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _pickImage('cert'),
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _certificateImage != null
                            ? AppColors.availableGreen
                            : AppColors.textLight,
                        width: _certificateImage != null ? 2 : 1,
                      ),
                    ),
                    child: _certificateImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_certificateImage!,
                                fit: BoxFit.cover, width: double.infinity),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file, color: AppColors.primaryNavy),
                              SizedBox(width: 8),
                              Text('Tap to upload certificate / diploma',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                    labelText: 'Confirm Password',
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
                      : const Text('Create Service Provider Account'),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have a worker account? '),
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
