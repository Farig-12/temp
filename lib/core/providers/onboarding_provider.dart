import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _hasSeenOnboardingKey = 'has_seen_onboarding';

// Provider to check if user has seen onboarding
final hasSeenOnboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_hasSeenOnboardingKey) ?? false;
});

// Provider to mark onboarding as seen
final markOnboardingSeenProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
    // Invalidate the hasSeenOnboardingProvider to refresh
    ref.invalidate(hasSeenOnboardingProvider);
  };
});

