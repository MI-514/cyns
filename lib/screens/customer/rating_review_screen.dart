import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/review_model.dart';
import '../../data/models/service_request_model.dart';
import '../../data/repositories/review_repository.dart';
import '../../providers/auth_provider.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your rating and review have been saved.'),
          backgroundColor: AppColors.statusCompleted,
        ),
      );
      Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Worker'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.star_rate_rounded,
                size: 72, color: AppColors.starGold),
            const SizedBox(height: 16),
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
            const SizedBox(height: 32),

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
                      selectedColor: AppColors.primaryNavy.withValues(alpha: 0.1),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.starGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.starGold : AppColors.dividerColor,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      amount == 0 ? 'None' : 'Rs $amount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : AppColors.textSecondary,
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
