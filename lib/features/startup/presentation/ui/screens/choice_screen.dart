import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import '../../../../../core/route/route_names.dart';

class ChoiceScreen extends ConsumerWidget {
  const ChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(goRouterProvider);
    return AppBackground(
      // <-- FIX 1: Add a Scaffold here
      child: Scaffold(
        backgroundColor: Colors.transparent, // So AppBackground shows through
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Continue as',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Arvo',
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildChoiceButton(
                    context: context,
                    icon: Icons.build_circle_outlined,
                    label: 'Mechanics',
                    onTap: () {
                      route.push(getRoutePath(mechanicSignupRoute));
                    },
                  ),
                  const SizedBox(width: 20),
                  _buildChoiceButton(
                    context: context,
                    icon: Icons.person_outline,
                    label: 'Client',
                    onTap: () {
                      route.push(getRoutePath(userSignupRoute));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 120,
        decoration: BoxDecoration(
          color: appCardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: appButtonColor, size: 40),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Arvo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}