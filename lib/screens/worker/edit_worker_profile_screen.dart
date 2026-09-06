import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/worker_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/worker_provider.dart';

class EditWorkerProfileScreen extends StatefulWidget {
  const EditWorkerProfileScreen({super.key});

  @override
  State<EditWorkerProfileScreen> createState() =>
      _EditWorkerProfileScreenState();
}

class _EditWorkerProfileScreenState extends State<EditWorkerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _professionController = TextEditingController();
  final _skillsController = TextEditingController();
  final _expController = TextEditingController();
  final _descController = TextEditingController();
  final _areaController = TextEditingController();

  List<String> _selectedCategoryIds = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final worker =
        Provider.of<WorkerProvider>(context, listen: false).currentWorkerProfile;
    if (worker != null) {
      _professionController.text = worker.profession;
      _skillsController.text = worker.skills.join(', ');
      _expController.text = worker.experienceYears.toString();
      _descController.text = worker.serviceDescription;
      _areaController.text = worker.workingArea;
      _selectedCategoryIds = List.from(worker.categoryIds);
    }
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);

    final skillsList = _skillsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    WorkerProfileModel updated = WorkerProfileModel(
      workerId: auth.userModel?.uid ?? '',
      name: auth.userModel?.fullName ?? 'Worker',
      phoneNumber: auth.userModel?.phoneNumber ?? '',
      profession: _professionController.text.trim(),
      categoryIds: _selectedCategoryIds,
      skills: skillsList,
      experienceYears: int.tryParse(_expController.text.trim()) ?? 1,
      serviceDescription: _descController.text.trim(),
      workingArea: _areaController.text.trim(),
      isAvailable: workerProvider.currentWorkerProfile?.isAvailable ?? true,
      rating: workerProvider.currentWorkerProfile?.rating ?? 0.0,
      reviewCount: workerProvider.currentWorkerProfile?.reviewCount ?? 0,
      completedJobsCount:
          workerProvider.currentWorkerProfile?.completedJobsCount ?? 0,
    );

    await workerProvider.updateWorkerProfile(updated);

    setState(() => _isSaving = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Worker profile updated successfully!'),
        backgroundColor: AppColors.statusCompleted,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Professional Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profession Title
              TextFormField(
                controller: _professionController,
                decoration: const InputDecoration(
                  labelText: 'Profession Title',
                  hintText: 'e.g. Senior Master Plumber, Electrician',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter profession title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categories Multi-Select
              const Text(
                'Select Service Categories',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryProvider.categories.map((cat) {
                  bool isSelected = _selectedCategoryIds.contains(cat.id);
                  return FilterChip(
                    label: Text(cat.name),
                    selected: isSelected,
                    selectedColor: AppColors.primaryNavy.withOpacity(0.2),
                    checkmarkColor: AppColors.primaryNavy,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategoryIds.add(cat.id);
                        } else {
                          _selectedCategoryIds.remove(cat.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Experience Years
              TextFormField(
                controller: _expController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Years of Experience',
                  prefixIcon: Icon(Icons.history_toggle_off),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter experience years';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Skills (Comma Separated)
              TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  labelText: 'Skills & Tools (Comma separated)',
                  hintText: 'Pipe Fitting, Drain Clearing, Water Heater Repair',
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Working Area
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: 'Working Area / City Coverage',
                  hintText: 'e.g. North Area, Gulberg, City Wide',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Detailed Description
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Service Description & Introduction',
                  hintText: 'Write a brief description of your services and tools...',
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Profile Updates'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
