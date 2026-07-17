import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'EasySplit';
  static const String appVersion = '2.1.0';

  // API
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://easysplit-p6z9.onrender.com/api/',
  );

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String themeKey = 'theme_mode';
  static const String currencyKey = 'currency';
  static const String onboardedKey = 'onboarded';

  // Pagination
  static const int defaultPageSize = 20;

  // OTP
  static const int otpLength = 6;
  static const int otpExpiryMinutes = 10;
  static const int otpResendCooldown = 60; // seconds

  // Built-in Avatar Presets (16 high-quality minimalist presets)
  static const List<Map<String, dynamic>> avatarPresets = [
    {'id': 'avatar_1', 'name': 'Rocket', 'icon': Icons.rocket_launch_rounded, 'bgHex': '6366F1'},
    {'id': 'avatar_2', 'name': 'Coffee', 'icon': Icons.coffee_rounded, 'bgHex': 'F59E0B'},
    {'id': 'avatar_3', 'name': 'Headphones', 'icon': Icons.headphones_rounded, 'bgHex': 'EC4899'},
    {'id': 'avatar_4', 'name': 'Palette', 'icon': Icons.palette_rounded, 'bgHex': '8B5CF6'},
    {'id': 'avatar_5', 'name': 'Camera', 'icon': Icons.camera_alt_rounded, 'bgHex': '10B981'},
    {'id': 'avatar_6', 'name': 'Globe', 'icon': Icons.public_rounded, 'bgHex': '3B82F6'},
    {'id': 'avatar_7', 'name': 'Gamepad', 'icon': Icons.sports_esports_rounded, 'bgHex': 'EF4444'},
    {'id': 'avatar_8', 'name': 'Fitness', 'icon': Icons.fitness_center_rounded, 'bgHex': '14B8A6'},
    {'id': 'avatar_9', 'name': 'Book', 'icon': Icons.menu_book_rounded, 'bgHex': '64748B'},
    {'id': 'avatar_10', 'name': 'Star', 'icon': Icons.star_rounded, 'bgHex': 'F59E0B'},
    {'id': 'avatar_11', 'name': 'Pizza', 'icon': Icons.local_pizza_rounded, 'bgHex': 'F97316'},
    {'id': 'avatar_12', 'name': 'Flight', 'icon': Icons.flight_rounded, 'bgHex': '06B6D4'},
    {'id': 'avatar_13', 'name': 'Bolt', 'icon': Icons.bolt_rounded, 'bgHex': 'EAB308'},
    {'id': 'avatar_14', 'name': 'Heart', 'icon': Icons.favorite_rounded, 'bgHex': 'F43F5E'},
    {'id': 'avatar_15', 'name': 'Crown', 'icon': Icons.workspace_premium_rounded, 'bgHex': 'A855F7'},
    {'id': 'avatar_16', 'name': 'Smile', 'icon': Icons.sentiment_very_satisfied_rounded, 'bgHex': '0284C7'},
  ];

  // Split Types
  static const String splitEqual = 'equal';
  static const String splitExact = 'exact';
  static const String splitPercentage = 'percentage';
  static const String splitShares = 'shares';

  // Expense Categories
  static const List<String> expenseCategories = [
    'Food & Drink',
    'Transport',
    'Accommodation',
    'Entertainment',
    'Shopping',
    'Utilities',
    'Healthcare',
    'Travel',
    'Education',
    'Other',
  ];

  // Currency Options
  static const List<Map<String, String>> currencies = [
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
  ];

  // Settlement Status
  static const String settlementPending = 'pending';
  static const String settlementCompleted = 'completed';

  // Notification Types
  static const String notifExpenseAdded = 'expense_added';
  static const String notifSettlementReminder = 'settlement_reminder';
  static const String notifInvitationAccepted = 'invitation_accepted';
  static const String notifGroupCreated = 'group_created';
  static const String notifSettlementCompleted = 'settlement_completed';

  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'No internet connection. Check your network.';
  static const String sessionExpired = 'Your session has expired. Please log in again.';
}

/// App route names for GoRouter
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String emailLogin = '/auth/email';
  static const String otpVerify = '/auth/otp';
  static const String signUp = '/auth/signup';
  static const String home = '/home';
  static const String groups = '/groups';
  static const String groupDetail = '/groups/:groupId';
  static const String groupAnalytics = '/groups/:groupId/analytics';
  static const String createGroup = '/groups/create';
  static const String editGroup = '/groups/:groupId/edit';
  static const String addExpense = '/groups/:groupId/expenses/add';
  static const String expenseDetail = '/expenses/:expenseId';
  static const String activity = '/activity';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String groupInvitations = '/invitations';
  static const String settlementHistory = '/settlements/history';
  static const String updateRequired = '/update-required';
}

/// Enum: Split type for expenses
enum SplitType { equal, exact, percentage, shares }

/// Enum: Settlement status
enum SettlementStatus { pending, completed }

/// Enum: Theme mode preference
enum AppThemeMode { light, dark, system }
