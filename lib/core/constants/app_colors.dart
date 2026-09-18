import 'package:flutter/material.dart';

class AppColors {
  // Primary Navy Blue & Premium Theme Palette
  static const Color primaryNavy = Color(0xFF0B2545);       // Deep Navy
  static const Color darkNavy = Color(0xFF07172C);          // Darker Navy for AppBars/Headers
  static const Color lightNavy = Color(0xFF133A68);         // Lighter Navy for secondary elements
  static const Color accentBlue = Color(0xFF2563EB);        // Vibrant Royal Blue accent
  
  static const Color pureWhite = Color(0xFFFFFFFF);         // Pure White
  static const Color offWhite = Color(0xFFF8FAFC);          // Light Background Surface
  static const Color cardSurface = Color(0xFFFFFFFF);       // White Surface
  static const Color dividerColor = Color(0xFFE2E8F0);      // Soft Border/Divider
  static const Color borderLight = Color(0xFFEEF2F6);       // Ultra soft border
  
  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);       // Slate Dark Text
  static const Color textSecondary = Color(0xFF475569);     // Muted Blue-Grey Text
  static const Color textLight = Color(0xFF94A3B8);         // Light Muted Text
  static const Color textOnNavy = Color(0xFFFFFFFF);        // Text on Dark Backgrounds

  // Status Colors
  static const Color statusPending = Color(0xFFD97706);     // Amber
  static const Color statusAccepted = Color(0xFF2563EB);    // Blue
  static const Color statusOnTheWay = Color(0xFF0284C7);    // Light Blue
  static const Color statusArrived = Color(0xFF7C3AED);     // Purple
  static const Color statusInProgress = Color(0xFF0D9488);  // Teal
  static const Color statusCompleted = Color(0xFF10B981);   // Emerald Green
  static const Color statusRejected = Color(0xFFEF4444);    // Red
  static const Color statusCancelled = Color(0xFF6B7280);   // Grey

  // Availability Badges
  static const Color availableGreen = Color(0xFF10B981);
  static const Color unavailableRed = Color(0xFFEF4444);

  // Additional Accents & Gradients
  static const Color starGold = Color(0xFFF59E0B);
  static const Color glowBlue = Color(0xFF3B82F6);

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryNavy, lightNavy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkNavyGradient = LinearGradient(
    colors: [darkNavy, primaryNavy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentBlue, glowBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

