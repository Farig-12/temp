import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mendlify/features/home/presentation/ui/screens/all_posts.dart';
import 'package:mendlify/features/home/presentation/ui/screens/profile_screen.dart';
import 'package:mendlify/features/home/presentation/ui/screens/vendor_screen.dart';
import 'package:mendlify/features/service_request/presentation/ui/screens/service_request_screen.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/shared/widgets/bottom_navbar.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/core/providers/home_providers.dart';
import 'package:mendlify/core/providers/logout_provider.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
import 'package:mendlify/core/route/route_names.dart';
import 'dart:io';

class MainHomeScreen extends ConsumerStatefulWidget {
  const MainHomeScreen({super.key});

  @override
  ConsumerState<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends ConsumerState<MainHomeScreen> {
  // We start with the home page (index 0) in our navigation history
  final List<int> _navigationHistory = [0];

  final List<Widget> _pages = [
    const _DashboardContent(), // Index 0: Home
    const AllPostsScreen(),
    const ServiceRequestScreen(), // Index 2: Service
    const VendorScreen(), // Index 3: History
    const ProfileScreen(), // Index 4: Profile
  ];

  @override
  Widget build(BuildContext context) {
    // The current index is always the last item in our history list.
    final currentIndex = _navigationHistory.last;

    final route = ref.watch(goRouterProvider);

    return AppBackground(
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          if (_navigationHistory.length > 1) {
            setState(() {
              // Remove the current page from history to go to the previous one.
              _navigationHistory.removeLast();
            });
          } else {
            // Show logout dialog when at the root of navigation
            final shouldLogout = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Do you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );

            if (shouldLogout == true) {
              // Logout and navigate to login
              await ref.read(logoutProvider)();
              route.go(getRoutePath(loginRoute));
            }
          }
        },
        child: Scaffold(
          backgroundColor:
              Colors.transparent, // Important for the background to show
          body: IndexedStack(
            index: currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: CurvedBottomNavBar(
            selectedIndex: currentIndex,
            onItemSelected: (index) {
              // Only update the state if a new tab is selected
              if (currentIndex != index) {
                setState(() {
                  _navigationHistory.add(index);
                });
              }
            },
            icons: const [
              Icons.home_outlined,
              Icons.chat_outlined,
              Icons.build_outlined,
              Icons.shopping_cart_outlined,
              Icons.person_outline,
            ],
          ),
        ),
      ),
    );
  }
}

// The main content
class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeDataProvider);
        },
        color: appButtonColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBarSection(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment
                        .stretch, // This makes the children fill the height
                    children: [
                      _ActionCard(
                        title: 'Find Mechanics',
                        icon: Icons.car_repair_outlined,
                      ),
                      SizedBox(width: 16),
                      _ActionCard(
                        title: 'Repair Guide',
                        icon: Icons.menu_book_outlined,
                        isRepairGuide: true,
                      ),
                    ],
                  ),
                ),
              ),
              _KilometersChartCard(),
              _MaintenanceCard(),
              _TipOfTheDayCard(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarSection extends ConsumerStatefulWidget {
  const _TopBarSection({super.key});

  @override
  ConsumerState<_TopBarSection> createState() => _TopBarSectionState();
}

class _TopBarSectionState extends ConsumerState<_TopBarSection> {
  @override
  Widget build(BuildContext context) {
    final homeDataAsync = ref.watch(homeDataProvider);

    return homeDataAsync.when(
      data: (homeData) {
        print(homeData.fastApiData);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mendlify',
                style: TextStyle(
                  color: appMainTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Hi ${homeData.userName}', // dynamic username
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 32, color: appMainTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'what do you want to do today?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: appTextColor,
                      fontWeight: FontWeight.normal,
                    ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(24.0),
        child: LinearProgressIndicator(
          backgroundColor: Colors.grey.withOpacity(0.3),
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.grey.withOpacity(0.5),
          ),
        ),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

class _ActionCard extends ConsumerWidget {
  final String title;
  final IconData icon;
  final bool isRepairGuide;

  const _ActionCard({
    required this.title,
    required this.icon,
    this.isRepairGuide = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: Card(
        color: appCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: InkWell(
          onTap: () {
            // --- NAVIGATION LOGIC ---
            if (isRepairGuide) {
              ref.read(goRouterProvider).push(getRoutePath(findGuideRoute));
            } else if (title == 'Find Mechanics') {
              // Optional: Navigate to vendor screen via route push if not using bottom bar
              // ref.read(goRouterProvider).push(getRoutePath(vendorRoute));
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: appButtonColor, size: 36),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: appMainTextColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartBar extends ConsumerWidget {
  final String label;
  final int value;
  final double maxValue;
  final double chartHeight = 150.0;
  final VoidCallback? onTap;
  final bool showTooltip;

  const _ChartBar({
    required this.label,
    required this.value,
    required this.maxValue,
    this.onTap,
    this.showTooltip = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If value is 0, show empty space
    if (value == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: appTextColor),
          ),
        ],
      );
    }

    final double heightRatio = maxValue > 0 ? value / maxValue : 0.0;
    final double barHeight = chartHeight * heightRatio;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: chartHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.bottomCenter,
              children: [
                // Show km value in place of bar when tapped
                if (showTooltip)
                  Container(
                    height: barHeight,
                    width: 35,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: appButtonColor.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: appButtonColor,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$value',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: appMainTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  // Show normal bar when not tapped
                  Container(
                    height: barHeight,
                    width: 28,
                    decoration: BoxDecoration(
                      color: appButtonColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: appTextColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _KilometersChartCard extends ConsumerStatefulWidget {
  const _KilometersChartCard();

  @override
  ConsumerState<_KilometersChartCard> createState() =>
      _KilometersChartCardState();
}

class _KilometersChartCardState extends ConsumerState<_KilometersChartCard> {
  int? _selectedBarIndex;

  @override
  Widget build(BuildContext context) {
    final homeDataAsync = ref.watch(homeDataProvider);

    return homeDataAsync.when(
      data: (homeData) {
        const List<String> months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'June',
          'July',
          'August',
          'Sept',
          'Oct',
          'Nov',
          'Dec'
        ];

        // Extract kilometers data from fastApiData
        final kilometersData =
            homeData.fastApiData['kilometers'] as Map<String, dynamic>? ?? {};

        // Get km values for each month
        final List<int> monthlyKm = months.map((month) {
          final value = kilometersData[month];
          if (value is int) return value;
          if (value is num) return value.toInt();
          return 0;
        }).toList();

        // Calculate total km
        final int totalKm = monthlyKm.fold(0, (sum, km) => sum + km);

        // Find max value for scaling (add some padding)
        final int maxKm = monthlyKm.isEmpty
            ? 1
            : (monthlyKm.reduce((a, b) => a > b ? a : b) * 1.2).ceil();
        final double maxValue = maxKm > 0 ? maxKm.toDouble() : 1.0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 12.0),
          color: appCardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text('Kilometres Driven',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: appMainTextColor),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${NumberFormat('#,###').format(totalKm)} km',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: appTextColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // --- Background lines for the chart ---
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (index) {
                            if (index == 0)
                              return const SizedBox
                                  .shrink(); // No line at the top
                            return Divider(
                              color: Colors.white.withOpacity(0.1),
                              thickness: 1,
                              height: 1,
                            );
                          }),
                        ),
                      ),
                      // --- Chart Bars (horizontally scrollable) ---
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(months.length, (index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 7.0),
                                child: _ChartBar(
                                  label: months[index],
                                  value: monthlyKm[index],
                                  maxValue: maxValue,
                                  onTap: () {
                                    setState(() {
                                      _selectedBarIndex =
                                          _selectedBarIndex == index
                                              ? null
                                              : index;
                                    });
                                  },
                                  showTooltip: _selectedBarIndex == index,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        margin: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 12.0),
        color: appCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: LinearProgressIndicator(
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.grey.withOpacity(0.5),
            ),
          ),
        ),
      ),
      error: (error, stackTrace) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 12.0),
        color: appCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Error loading kilometers data: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceCard extends ConsumerWidget {
  const _MaintenanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeDataAsync = ref.watch(homeDataProvider);

    return homeDataAsync.when(
      data: (homeData) {
        // Extract maintenance data from fastApiData
        final maintenanceData =
            homeData.fastApiData['maintenance'] as Map<String, dynamic>? ?? {};

        final String? oilChange = maintenanceData['oil_change'] as String?;
        final String? tireChange = maintenanceData['tire_change'] as String?;
        final String? lastService = maintenanceData['last_service'] as String?;
        final int? healthPercent = maintenanceData['health_percent'] as int?;

        final double healthValue = (healthPercent ?? 75) / 100.0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          color: appCardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Maintenance',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: appMainTextColor)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _MaintenanceItem(
                            icon: Icons.oil_barrel_outlined,
                            title: 'Oil Change',
                            subtitle: oilChange ?? 'Not recorded',
                          ),
                          const SizedBox(height: 16),
                          _MaintenanceItem(
                            icon: Icons.tire_repair_outlined,
                            title: 'Tire Change',
                            subtitle: tireChange ?? 'Not recorded',
                          ),
                          const SizedBox(height: 16),
                          _MaintenanceItem(
                            icon: Icons.settings_outlined,
                            title: 'Last Service',
                            subtitle: lastService ?? 'Not recorded',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: healthValue,
                              strokeWidth: 10,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  appButtonColor),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${healthPercent ?? 75}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: appMainTextColor,
                                    ),
                              ),
                              Text(
                                'Health',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: appTextColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        color: appCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: LinearProgressIndicator(
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.grey.withOpacity(0.5),
            ),
          ),
        ),
      ),
      error: (error, stackTrace) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        color: appCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Error loading maintenance data: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceItem extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MaintenanceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Icon(icon, color: appButtonColor, size: 24),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: appMainTextColor)),
            Text(subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: appTextColor)),
          ],
        ),
      ],
    );
  }
}

class _TipOfTheDayCard extends ConsumerWidget {
  const _TipOfTheDayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      color: appCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline,
                color: appButtonColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tip of the day',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: appMainTextColor)),
                  const SizedBox(height: 8),
                  Text(
                    'Change engine oil every 2,000 km for smooth performance',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: appMainTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
