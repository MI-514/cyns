import 'package:flutter/material.dart';
import '../../data/models/worker_profile_model.dart';

enum WorkerTierLevel {
  platinum,
  gold,
  silver,
  bronze,
}

class WorkerBadgeHelper {
  static WorkerTierLevel getTier({
    required double rating,
    required int completedJobs,
  }) {
    if (rating >= 4.8 && completedJobs >= 10) {
      return WorkerTierLevel.platinum;
    } else if (rating >= 4.5 && completedJobs >= 4) {
      return WorkerTierLevel.gold;
    } else if (rating >= 3.8 && completedJobs >= 1) {
      return WorkerTierLevel.silver;
    }
    return WorkerTierLevel.bronze;
  }

  static String getTierName(WorkerTierLevel tier) {
    switch (tier) {
      case WorkerTierLevel.platinum:
        return 'Platinum Pro';
      case WorkerTierLevel.gold:
        return 'Gold Master';
      case WorkerTierLevel.silver:
        return 'Silver Specialist';
      case WorkerTierLevel.bronze:
        return 'Bronze Skilled';
    }
  }

  static IconData getTierIcon(WorkerTierLevel tier) {
    switch (tier) {
      case WorkerTierLevel.platinum:
        return Icons.diamond_rounded;
      case WorkerTierLevel.gold:
        return Icons.military_tech_rounded;
      case WorkerTierLevel.silver:
        return Icons.workspace_premium_rounded;
      case WorkerTierLevel.bronze:
        return Icons.verified_user_rounded;
    }
  }

  static Color getTierColor(WorkerTierLevel tier) {
    switch (tier) {
      case WorkerTierLevel.platinum:
        return const Color(0xFF7C3AED); // Vivid Violet
      case WorkerTierLevel.gold:
        return const Color(0xFFD97706); // Warm Amber Gold
      case WorkerTierLevel.silver:
        return const Color(0xFF475569); // Slate Silver
      case WorkerTierLevel.bronze:
        return const Color(0xFFB45309); // Bronze Brown
    }
  }

  static Color getTierBgColor(WorkerTierLevel tier) {
    switch (tier) {
      case WorkerTierLevel.platinum:
        return const Color(0xFFEDE9FE);
      case WorkerTierLevel.gold:
        return const Color(0xFFFEF3C7);
      case WorkerTierLevel.silver:
        return const Color(0xFFF1F5F9);
      case WorkerTierLevel.bronze:
        return const Color(0xFFFFEDD5);
    }
  }
}

class WorkerTierBadge extends StatelessWidget {
  final double rating;
  final int completedJobs;
  final bool compact;

  const WorkerTierBadge({
    super.key,
    required this.rating,
    required this.completedJobs,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tier = WorkerBadgeHelper.getTier(
      rating: rating,
      completedJobs: completedJobs,
    );
    final name = WorkerBadgeHelper.getTierName(tier);
    final icon = WorkerBadgeHelper.getTierIcon(tier);
    final color = WorkerBadgeHelper.getTierColor(tier);
    final bgColor = WorkerBadgeHelper.getTierBgColor(tier);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class CnicVerifiedBadge extends StatelessWidget {
  final bool compact;

  const CnicVerifiedBadge({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5), // Emerald light
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: compact ? 12 : 14,
            color: const Color(0xFF059669),
          ),
          const SizedBox(width: 4),
          Text(
            'CNIC Verified',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerBadgeRow extends StatelessWidget {
  final WorkerProfileModel worker;
  final bool compact;

  const WorkerBadgeRow({
    super.key,
    required this.worker,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasCnic =
        worker.cnicNumber.trim().isNotEmpty || worker.isApproved;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WorkerTierBadge(
          rating: worker.rating,
          completedJobs: worker.completedJobsCount,
          compact: compact,
        ),
        if (hasCnic)
          CnicVerifiedBadge(compact: compact),
      ],
    );
  }
}
