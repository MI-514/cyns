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

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success = await authProvider.registerWorkerAdvanced(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
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
          title: const Text('Registration Successful!'),
          content: const Text(
            'Your Service Provider account has been created and saved in Cloud Firestore.\nYou can now sign in with your registered email and password.',
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
                  'Enter your details, trade skills, and CNIC photos to register in Cloud Firestore',
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
