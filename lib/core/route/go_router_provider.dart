import 'package:mendlify/features/home/presentation/ui/screens/main_home_screen.dart';
import 'package:mendlify/features/RepairGuide/ui/screens/find_guide_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/signin/presentation/ui/screens/login_screen.dart';
import '../../features/RepairGuide/ui/screens/add_guide_screen.dart';
import '../../features/RepairGuide/ui/screens/guide_detail_screen.dart';
import '../../features/authentication/signup/presentation/ui/screens/signup_screen.dart';
import '../../features/authentication/signup/presentation/ui/screens/user_signup_screen.dart';
import '../../features/authentication/signup/presentation/ui/screens/mechanic_signup_screen.dart';
import '../../features/mechanic/presentation/ui/screens/mechanic_home_screen.dart';
import '../../features/service_request/presentation/ui/screens/my_service_requests_screen.dart';
import '../../features/home/presentation/ui/screens/all_posts.dart';
import '../../features/home/presentation/ui/screens/post_detail_screen.dart';
import '../../features/home/presentation/ui/screens/profile_screen.dart';
import '../../features/home/presentation/ui/screens/vendor_screen.dart';
import '../../features/home/presentation/ui/screens/create_post_screen.dart';
import '../../features/home/presentation/ui/screens/my_posts_screen.dart';
import '../../features/authentication/signup/presentation/ui/screens/bike_info_screen.dart';
import '../../features/authentication/signup/presentation/ui/screens/edit_personal_info_screen.dart';
import '../../features/startup/presentation/ui/screens/choice_screen.dart';
import '../../features/startup/presentation/ui/screens/landing_screen.dart';
import '../../features/startup/presentation/ui/screens/splash_screen.dart';
import '../../features/authentication/forgotpassword/presentation/ui/screens/forgot_password_enter_email_screen.dart';
import '../../features/RepairGuide/ui/screens/my_guides_screen.dart';
import '../../core/providers/onboarding_provider.dart';
import 'route_names.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  // final authState = ref.watch(authStateProvider);

  // Watch onboarding status
  final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);

  return GoRouter(
    initialLocation: getRoutePath(landingRoute),
    redirect: (context, state) {
      // Wait for onboarding check to complete
      if (hasSeenOnboarding.isLoading) {
        return null; // Don't redirect while loading
      }

      final hasSeen = hasSeenOnboarding.value ?? false;
      final isOnLanding = state.matchedLocation == getRoutePath(landingRoute);

      // If user has seen onboarding and is trying to go to landing, redirect to login
      if (hasSeen && isOnLanding) {
        return getRoutePath(loginRoute);
      }

      return null;
    },
    // redirect: (context, state) {
    //   final isGoingToLogin = state.matchedLocation == '/login';
    //
    //   if (authState) {
    //     if (isGoingToLogin) {
    //       return '/home';
    //     }
    //   }
    //
    //   return null;
    // },
    routes: [
      GoRoute(
        path: getRoutePath(splashRoute),
        name: splashRoute,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: getRoutePath(landingRoute),
        name: landingRoute,
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: getRoutePath(choiceRoute),
        name: choiceRoute,
        builder: (context, state) => const ChoiceScreen(),
      ),
      GoRoute(
        path: getRoutePath(loginRoute),
        name: loginRoute,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: getRoutePath(forgotPasswordEnterEmailRoute),
        name: forgotPasswordEnterEmailRoute,
        builder: (context, state) => const ForgotPasswordEnterEmailScreen(),
      ),
      GoRoute(
        path: getRoutePath(singUpRoute),
        name: singUpRoute,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: getRoutePath(userSignupRoute),
        name: userSignupRoute,
        builder: (context, state) => const UserSignupScreen(),
      ),
      GoRoute(
        path: getRoutePath(mechanicSignupRoute),
        name: mechanicSignupRoute,
        builder: (context, state) => const MechanicSignupScreen(),
      ),
      GoRoute(
        path: getRoutePath(homeRoute),
        name: homeRoute,
        builder: (context, state) => const MainHomeScreen(),
      ),
      GoRoute(
        path: getRoutePath(mechanicHomeRoute),
        name: mechanicHomeRoute,
        builder: (context, state) => const MechanicHomeScreen(),
      ),
      GoRoute(
        path: getRoutePath(myServiceRequestsRoute),
        name: myServiceRequestsRoute,
        builder: (context, state) => const MyServiceRequestsScreen(),
      ),
      GoRoute(
        path: getRoutePath(findGuideRoute),
        name: findGuideRoute,
        builder: (context, state) => const FindGuideScreen(),
      ),
      GoRoute(
        path: getRoutePath(guideDetailRoute),
        name: guideDetailRoute,
        builder: (context, state) {
          final guideId = state.extra as String?;
          return GuideDetailScreen(guideId: guideId);
        },
      ),
      GoRoute(
        path: getRoutePath(addGuideRoute),
        name: addGuideRoute,
        builder: (context, state) => const AddGuideScreen(),
      ),
      GoRoute(
        path: getRoutePath(myGuidesRoute),
        name: myGuidesRoute,
        builder: (context, state) => const MyGuidesScreen(),
      ),
      GoRoute(
        path: getRoutePath(vendorRoute),
        name: vendorRoute,
        builder: (context, state) => const VendorScreen(),
      ),
      GoRoute(
        path: getRoutePath(communityRoute),
        name: communityRoute,
        builder: (context, state) => const AllPostsScreen(),
      ),
      GoRoute(
        path: getRoutePath(postDetailRoute),
        name: postDetailRoute,
        builder: (context, state) {
          final postId = state.extra as String?;
          return PostDetailScreen(postId: postId);
        },
      ),
      GoRoute(
        path: getRoutePath(profileRoute),
        name: profileRoute,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: getRoutePath(createPostRoute),
        name: createPostRoute,
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: getRoutePath(myPostsRoute),
        name: myPostsRoute,
        builder: (context, state) => const MyPostsScreen(),
      ),
      GoRoute(
        path: getRoutePath(bikeInfoRoute),
        name: bikeInfoRoute,
        builder: (context, state) => const BikeInfoScreen(),
      ),
      GoRoute(
        path: getRoutePath(editPersonalInfoRoute),
        name: editPersonalInfoRoute,
        builder: (context, state) => const EditPersonalInfoScreen(),
      ),
    ],
  );
});

String getRoutePath(String route) {
  return "/$route";
}
