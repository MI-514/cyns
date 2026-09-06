import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/service_request_model.dart';
import '../../data/models/worker_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/service_request_provider.dart';
import 'request_waiting_countdown_screen.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  final WorkerProfileModel worker;

  const CreateServiceRequestScreen({super.key, required this.worker});

  @override
  State<CreateServiceRequestScreen> createState() =>
      _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState
    extends State<CreateServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  File? _selectedImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final location = Provider.of<LocationProvider>(context, listen: false);
    _addressController.text = location.currentAddress;

    if (widget.worker.categoryIds.isNotEmpty) {
      _selectedCategoryId = widget.worker.categoryIds.first;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final location = Provider.of<LocationProvider>(context, listen: false);
    final requestProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    // Find Category Name
    String catName = _selectedCategoryName ?? widget.worker.profession;
    if (_selectedCategoryId != null) {
      final found = categoryProvider.categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => categoryProvider.categories.isNotEmpty
            ? categoryProvider.categories.first
            : AppConstants.defaultCategories.first as dynamic,
      );
      catName = found.name;
    }

    setState(() => _isUploading = true);

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await StorageService.uploadImage(
        file: _selectedImage!,
        folder: 'problem_images',
        filename: 'req_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    double lat = location.currentPosition?.latitude ?? 0.0;
    double lng = location.currentPosition?.longitude ?? 0.0;

    ServiceRequestModel request = ServiceRequestModel(
      id: '',
      customerId: auth.userModel?.uid ?? '',
      customerName: auth.userModel?.fullName ?? 'Customer',
      customerPhone: auth.userModel?.phoneNumber ?? '',
      workerId: widget.worker.workerId,
      workerName: widget.worker.name,
      workerPhone: widget.worker.phoneNumber,
      categoryId: _selectedCategoryId ?? 'general',
      categoryName: catName,
      problemDescription: _problemController.text.trim(),
      attachmentUrl: imageUrl,
      customerLat: lat,
      customerLng: lng,
      customerAddress: _addressController.text.trim(),
      workerLat: widget.worker.latitude,
      workerLng: widget.worker.longitude,
      status: AppConstants.statusPending,
    );

    String? reqId = await requestProvider.createRequest(request);

    setState(() => _isUploading = false);

    if (!mounted) return;

    if (reqId != null) {
      // Transition to 30-Second Countdown Waiting Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RequestWaitingCountdownScreen(
            requestId: reqId,
            workerName: widget.worker.name,
            workerPhone: widget.worker.phoneNumber,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requestProvider.errorMessage.isNotEmpty
              ? requestProvider.errorMessage
              : 'Failed to send request.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Service Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Worker Target Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                        child: const Icon(Icons.person,
                            color: AppColors.primaryNavy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.worker.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              widget.worker.profession,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.accentBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Problem Description Input
              const Text(
                'Explain Problem / Service Required *',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _problemController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Describe your issue in detail (e.g. "My kitchen sink pipe is leaking heavily and needs immediate repair.")',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please describe your problem.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Image Attachment
              const Text(
                'Attach Photo (Optional)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: _selectedImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _selectedImage!,
                                width: double.infinity,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 14,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                  onPressed: () {
                                    setState(() => _selectedImage = null);
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                size: 32, color: AppColors.primaryNavy),
                            SizedBox(height: 6),
                            Text(
                              'Tap to attach problem image',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Location / Address
              const Text(
                'Service Location Address *',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _isUploading ? null : _handleSubmit,
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Confirm & Send Request (30s Timer)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
