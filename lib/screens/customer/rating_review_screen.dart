import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/review_model.dart';
import '../../data/models/service_request_model.dart';
import '../../data/repositories/review_repository.dart';
import '../../providers/auth_provider.dart';

import 'package:flutter/services.dart';
import '../../data/repositories/service_request_repository.dart';

class RatingReviewScreen extends StatefulWidget {
  final ServiceRequestModel request;

  const RatingReviewScreen({super.key, required this.request});

  @override
  State<RatingReviewScreen> createState() => _RatingReviewScreenState();
}

class _RatingReviewScreenState extends State<RatingReviewScreen> {
  double _rating = 5.0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;
  final List<String> _selectedTags = [];
  int _selectedTip = 0;
  final List<int> _tipAmounts = [0, 50, 100, 200, 500];
  String? _completionOtp;

  final List<String> _positiveTags = [
    'On Time',
    'Professional',
    'Excellent Quality',
    'Friendly',
    'Quick'
  ];

  final List<String> _negativeTags = [
    'Late',
    'Unprofessional',
    'Messy',
    'Overcharged',
    'Slow'
  ];

  @override
  void initState() {
    super.initState();
    _completionOtp = widget.request.completionOtp;
    _loadCompletionOtp();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _loadCompletionOtp() async {
    final otp = await ServiceRequestRepository().ensureCompletionOtp(
      widget.request.id,
      currentOtp: widget.request.completionOtp,
    );
    if (mounted) {
      setState(() {
        _completionOtp = otp;
      });
    }
  }

  void _submitReview() async {
    if (_reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a short review feedback.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    ReviewModel review = ReviewModel(
      id: '',
      requestId: widget.request.id,
      workerId: widget.request.workerId,
      customerId: auth.userModel?.uid ?? '',
      customerName: auth.userModel?.fullName ?? 'Customer',
      rating: _rating,
      reviewText: _reviewController.text.trim(),
      tags: _selectedTags,
      tipAmount: _selectedTip,
    );

    try {
      await ReviewRepository().addReview(review);
      if (!mounted) return;

      // Show completion verification code popup to ensure customer gives code to worker
      await showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.check_circle_rounded,
              color: AppColors.statusCompleted, size: 52),
          title: const Text(
            'Review Submitted! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your rating and feedback have been saved! Please share this 4-digit code with the technician to mark the job as Completed:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.starGold,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.starGold.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  _completionOtp ?? widget.request.completionOtp ?? '••••',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Done & Return to Chat'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayCode =
        _completionOtp ?? widget.request.completionOtp ?? '••••';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Worker & Verify Job'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4-Digit Cross-Verification Code Banner (Highlighted at Top)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.starGold.withValues(alpha: 0.22),
                    AppColors.starGold.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.starGold, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_person_rounded,
                          color: Colors.orange.shade800, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Job Cross-Verification Code',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: displayCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied to clipboard!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.starGold,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.starGold.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayCode,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 6,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy_rounded,
                              size: 18, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Give this 4-digit code to ${widget.request.workerName} so they can verify and finalize this job.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Icon(Icons.star_rate_rounded,
                size: 64, color: AppColors.starGold),
            const SizedBox(height: 12),
            Text(
              'Rate ${widget.request.workerName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How was the service for ${widget.request.categoryName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Rating Bar
            Center(
              child: RatingBar.builder(
                initialRating: 5,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: AppColors.starGold,
                ),
                onRatingUpdate: (rating) {
                  setState(() {
                    _rating = rating;
                    _selectedTags.clear(); // reset tags on rating change
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Dynamic Tags
            Text(
              _rating >= 4.0 ? 'What did you like?' : 'What went wrong?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: (_rating >= 4.0 ? _positiveTags : _negativeTags)
                  .map(
                    (tag) => FilterChip(
                      label: Text(tag),
                      selected: _selectedTags.contains(tag),
                      selectedColor:
                          AppColors.primaryNavy.withValues(alpha: 0.1),
                      checkmarkColor: AppColors.primaryNavy,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 32),

            // Tip Section
            const Text(
              'Show your appreciation with a tip (Optional)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _tipAmounts.map((amount) {
                final isSelected = _selectedTip == amount;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTip = amount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.starGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.starGold
                            : AppColors.dividerColor,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      amount == 0 ? 'None' : 'Rs $amount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? Colors.black : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Review Input
            TextFormField(
              controller: _reviewController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Write Your Feedback',
                hintText:
                    'Share details about worker punctuality, skills, and behavior...',
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Submit Rating & Review'),
            ),
          ],
        ),
      ),
    );
  }
}
