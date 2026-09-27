import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/service_request_model.dart';
import '../../data/models/worker_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/location_picker_screen.dart';
import 'request_waiting_countdown_screen.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  final WorkerProfileModel? worker;
  final String? categoryId;
  final String? categoryName;

  const CreateServiceRequestScreen({
    super.key,
    this.worker,
    this.categoryId,
    this.categoryName,
  });

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
  double? _pickedLat;
  double? _pickedLng;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final location = Provider.of<LocationProvider>(context, listen: false);
    _addressController.text = location.currentAddress;

    if (widget.worker != null && widget.worker!.categoryIds.isNotEmpty) {
      _selectedCategoryId = widget.worker!.categoryIds.first;
      _selectedCategoryName = widget.worker!.profession;
    } else {
      _selectedCategoryId = widget.categoryId;
      _selectedCategoryName = widget.categoryName;
    }
  }

  Future<void> _openLocationPicker() async {
    final location = Provider.of<LocationProvider>(context, listen: false);
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _pickedLat ?? location.currentPosition?.latitude,
          initialLng: _pickedLng ?? location.currentPosition?.longitude,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _pickedLat = result.latitude;
        _pickedLng = result.longitude;
        _addressController.text = result.address;
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Attach Issue Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final picked = await _picker.pickImage(
                          source: ImageSource.camera, imageQuality: 80);
                      if (picked != null) {
                        setState(() => _selectedImage = File(picked.path));
                      }
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starGold,
                      foregroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final picked = await _picker.pickImage(
                          source: ImageSource.gallery, imageQuality: 80);
                      if (picked != null) {
                        setState(() => _selectedImage = File(picked.path));
                      }
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

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final location = Provider.of<LocationProvider>(context, listen: false);
    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    setState(() => _isUploading = true);

    await location.fetchCurrentLocation(context: context);

    double cLat = _pickedLat ?? location.currentPosition?.latitude ?? 31.5204;
    double cLng = _pickedLng ?? location.currentPosition?.longitude ?? 74.3587;

    String catId = _selectedCategoryId ?? widget.categoryId ?? 'general';
    String catName = _selectedCategoryName ?? widget.categoryName ?? 'Service';

    if (_selectedCategoryId != null && _selectedCategoryName == null) {
      final found = categoryProvider.categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => categoryProvider.categories.isNotEmpty
            ? categoryProvider.categories.first
            : AppConstants.defaultCategories.first as dynamic,
      );
      catName = found.name;
    }

    WorkerProfileModel? targetWorker = widget.worker;

    // If targetWorker is not directly provided, search 10 KM nearest priority worker in this category!
    if (targetWorker == null) {
      await workerProvider.searchWorkers(
        categoryId: catId,
        customerLat: cLat,
        customerLng: cLng,
        maxRadiusKm: 10.0,
      );

      if (workerProvider.searchResults.isNotEmpty) {
        targetWorker = workerProvider.searchResults.first;
      } else {
        setState(() => _isUploading = false);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.location_off_rounded,
                size: 48, color: AppColors.statusPending),
            title: const Text('No Worker Found Within 10 KM'),
            content: Text(
              'No available $catName worker found within 10 Kilometers of your current location right now.',
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // Upload issue image if attached
    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await StorageService.uploadImage(
        file: _selectedImage!,
        folder: 'problem_images',
        filename: 'req_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    double dist = LocationService.calculateDistanceKm(
      cLat,
      cLng,
      targetWorker.latitude ?? cLat,
      targetWorker.longitude ?? cLng,
    );

    String problemText = _problemController.text.trim();
    if (problemText.isEmpty) {
      problemText = 'Requesting doorstep service for $catName';
    }

    ServiceRequestModel request = ServiceRequestModel(
      id: '',
      customerId: auth.userModel?.uid ?? 'c1',
      customerName: auth.userModel?.fullName ?? 'Customer',
      customerPhone: auth.userModel?.phoneNumber ?? '',
      workerId: targetWorker.workerId,
      workerName: targetWorker.name,
      workerPhone: targetWorker.phoneNumber,
      categoryId: catId,
      categoryName: catName,
      problemDescription: problemText,
      attachmentUrl: imageUrl,
      customerLat: cLat,
      customerLng: cLng,
      customerAddress: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : location.currentAddress,
      workerLat: targetWorker.latitude ?? cLat,
      workerLng: targetWorker.longitude ?? cLng,
      status: AppConstants.statusPending,
    );

    String? reqId = await requestProvider.createRequest(request);

    setState(() => _isUploading = false);

    if (!mounted) return;

    if (reqId != null) {
      ServiceRequestModel createdReq = ServiceRequestModel(
        id: reqId,
        customerId: request.customerId,
        customerName: request.customerName,
        customerPhone: request.customerPhone,
        workerId: request.workerId,
        workerName: request.workerName,
        workerPhone: request.workerPhone,
        categoryId: request.categoryId,
        categoryName: request.categoryName,
        problemDescription: request.problemDescription,
        attachmentUrl: request.attachmentUrl,
        customerLat: request.customerLat,
        customerLng: request.customerLng,
        customerAddress: request.customerAddress,
        workerLat: request.workerLat,
        workerLng: request.workerLng,
        status: request.status,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Dispatched to nearest 10KM worker: ${targetWorker.name} (${LocationService.formatDistance(dist)} away)...'),
          backgroundColor: AppColors.primaryNavy,
          duration: const Duration(seconds: 3),
        ),
      );

      // Transition to 30-Second Countdown Waiting Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RequestWaitingCountdownScreen(
            request: createdReq,
            attemptedWorkerIds: [targetWorker!.workerId],
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
    String titleText = _selectedCategoryName ??
        widget.categoryName ??
        widget.worker?.profession ??
        'Service Request';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Target Info Card (Specific Worker or 10KM Priority Dispatch)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryNavy.withValues(alpha: 0.08),
                      AppColors.accentBlue.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppColors.primaryNavy.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryNavy,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.worker != null
                            ? Icons.person_rounded
                            : Icons.near_me_rounded,
                        color: AppColors.pureWhite,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.worker != null
                                ? widget.worker!.name
                                : '10 KM Nearest Worker Priority Match',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.worker != null
                                ? widget.worker!.profession
                                : 'Category: $titleText (Auto-Dispatches to Nearest Available Worker)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Problem Description Input (Comment / Masla) - Optional
              const Text(
                'Issue Details / Comments (Optional)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _problemController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'Describe your issue (Optional e.g., "Kitchen sink pipe is leaking")',
                ),
                validator: (val) {
                  return null; // Optional
                },
              ),
              const SizedBox(height: 20),

              // Image Attachment - Optional
              const Text(
                'Attach Photo (Optional)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedImage != null
                          ? AppColors.availableGreen
                          : AppColors.dividerColor,
                      width: _selectedImage != null ? 2 : 1,
                    ),
                  ),
                  child: _selectedImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                _selectedImage!,
                                width: double.infinity,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selectedImage = null);
                                },
                                child: CircleAvatar(
                                  backgroundColor:
                                      Colors.black.withValues(alpha: 0.7),
                                  radius: 14,
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
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
                              'Tap to upload issue photo (Camera / Gallery)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Location / Address
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Service Location Address *',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  if (_pickedLat != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.availableGreen
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14,
                              color: AppColors.availableGreen),
                          SizedBox(width: 4),
                          Text(
                            'GPS Set',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.availableGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Pick Location on Map Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentBlue,
                    side: BorderSide(
                      color: _pickedLat != null
                          ? AppColors.availableGreen
                          : AppColors.accentBlue,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    _pickedLat != null
                        ? Icons.edit_location_alt
                        : Icons.map_rounded,
                    size: 20,
                    color: _pickedLat != null
                        ? AppColors.availableGreen
                        : AppColors.accentBlue,
                  ),
                  label: Text(
                    _pickedLat != null
                        ? 'Change Location on Map'
                        : '📍 Pick Exact Location on Map',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _pickedLat != null
                          ? AppColors.availableGreen
                          : AppColors.accentBlue,
                    ),
                  ),
                  onPressed: _openLocationPicker,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_rounded,
                      color: AppColors.primaryNavy),
                  hintText: 'Or type your address manually',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your service address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isUploading ? null : _handleSubmit,
                  icon: _isUploading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.near_me_rounded, size: 20),
                  label: _isUploading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send Request to 10KM Nearest Worker',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
