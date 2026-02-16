import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';

import '../../../../../core/route/go_router_provider.dart';
import '../../../../../core/route/route_names.dart';
import '../../../../../core/utils/image_resources.dart';
import '../../../../../core/providers/onboarding_provider.dart';
import '../../../../../shared/widgets/app_background.dart';
import '../../../../../shared/widgets/app_image.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Know before you go',
      'description':
      'Get quick AI powered checks so you understand the issue before visiting a mechanic.',
      'image': appLanding1path,
    },
    {
      'title': 'Two wheels, one tribe.',
      'description':
      'A space for bikers to swap hacks, troubleshoot, and ride smarter together.',
      'image': appLanding2path,
    },
    {
      'title': 'Trusted hands, trusted parts',
      'description':
      'Connect with mechanics and vendors who deliver honesty and quality.',
      'image': appLanding3path,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(goRouterProvider);
    return AppBackground(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppImage(
                        path: page['image']!,
                        width: 300,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        page['title']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Arvo',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        page['description']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: appTextColor,
                          fontSize: 15,
                          fontFamily: 'Arvo',
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  width: 311,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_currentPage == _pages.length - 1) {
                        // Mark onboarding as seen when finishing
                        await ref.read(markOnboardingSeenProvider)();
                        route.push(getRoutePath(loginRoute));
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appButtonColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(61),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Finish' : 'Next',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                      (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  // Mark onboarding as seen when skipping
                  await ref.read(markOnboardingSeenProvider)();
                  route.push(getRoutePath(loginRoute));
                },
                child: const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 25),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontFamily: 'Arvo',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
