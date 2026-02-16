import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_providers.dart';
import 'posts_providers.dart';
import 'guides_providers.dart';
import 'auth_providers.dart';

// Logout provider - clears all cache and signs out
final logoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Invalidate ALL data providers before signing out

    // Home/User data providers
    ref.invalidate(homeDataProvider);
    ref.invalidate(currentUserIdProvider);
    ref.invalidate(userNameProvider);
    ref.invalidate(fastApiDataProvider);
    ref.invalidate(userProfileProvider);

    // Posts providers
    ref.invalidate(allPostsProvider);
    ref.invalidate(myPostsProvider);
    ref.invalidate(postProvider);
    ref.invalidate(postStateProvider);
    ref.invalidate(createPostProvider);
    ref.invalidate(toggleLikeProvider);
    ref.invalidate(addCommentProvider);

    // Guides providers
    ref.invalidate(allGuidesProvider);
    ref.invalidate(myGuidesProvider);
    ref.invalidate(guideProvider);
    ref.invalidate(guideStateProvider);
    ref.invalidate(createGuideProvider);
    ref.invalidate(toggleGuideLikeProvider);
    ref.invalidate(addGuideCommentProvider);

    // Auth providers
    ref.invalidate(loginProvider);
    ref.invalidate(loginWithRoleProvider);
    ref.invalidate(userRoleProvider);

    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();
  };
});
