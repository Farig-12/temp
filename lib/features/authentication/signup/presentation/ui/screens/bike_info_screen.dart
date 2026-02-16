import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/shared/widgets/app_text_form_field.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../../../core/route/go_router_provider.dart';
import '../../../../../../core/route/route_names.dart';
import '../../../../../../core/config/api_config.dart';
import '../../../../../../core/providers/home_providers.dart';

class BikeInfoScreen extends ConsumerStatefulWidget {
  const BikeInfoScreen({super.key});

  @override
  ConsumerState<BikeInfoScreen> createState() => _BikeInfoScreenState();
}

class _BikeInfoScreenState extends ConsumerState<BikeInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kilometersController = TextEditingController();
  final _oilChangeController = TextEditingController();
  final _tireChangeController = TextEditingController();
  final _serviceController = TextEditingController();

  DateTime? _lastOilChange;
  DateTime? _lastTireChange;
  DateTime? _lastService;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Editing; Load existing data
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final token = await user.getIdToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConfig.getEndpoint("user/data")),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Load kilometers; get current month
        final currentMonth = DateFormat('MMM').format(DateTime.now());
        final kilometers = data['kilometers'] as Map<String, dynamic>?;
        if (kilometers != null && kilometers.containsKey(currentMonth)) {
          _kilometersController.text = kilometers[currentMonth].toString();
        }

        // Load maintenance dates
        final maintenance = data['maintenance'] as Map<String, dynamic>?;
        if (maintenance != null) {
          if (maintenance['oil_change'] != null) {
            _lastOilChange = DateTime.parse(maintenance['oil_change']);
            _oilChangeController.text =
                DateFormat('yyyy-MM-dd').format(_lastOilChange!);
          }
          if (maintenance['tire_change'] != null) {
            _lastTireChange = DateTime.parse(maintenance['tire_change']);
            _tireChangeController.text =
                DateFormat('yyyy-MM-dd').format(_lastTireChange!);
          }
          if (maintenance['last_service'] != null) {
            _lastService = DateTime.parse(maintenance['last_service']);
            _serviceController.text =
                DateFormat('yyyy-MM-dd').format(_lastService!);
          }
        }
      }
    } catch (e) {
      // If user data doesn't exist
      print('No existing data found or error loading: $e');
    }
  }

  @override
  void dispose() {
    _kilometersController.dispose();
    _oilChangeController.dispose();
    _tireChangeController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
      BuildContext context,
      Function(DateTime) onDateSelected,
      TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: appButtonColor,
              onPrimary: Colors.white,
              surface: appCardColor,
              onSurface: appMainTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateSelected(picked);
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  int _calculateHealthPercent() {
    if (_lastOilChange == null ||
        _lastTireChange == null ||
        _lastService == null) {
      return 50;
    }

    final now = DateTime.now();
    int health = 100;

    // Oil change; every 3-6 months
    final oilChangeMonths =
        (now.difference(_lastOilChange!).inDays / 30).round();
    if (oilChangeMonths > 6) {
      health -= 20;
    } else if (oilChangeMonths > 4) {
      health -= 10;
    }

    // Tire change; every 1-2 years
    final tireChangeMonths =
        (now.difference(_lastTireChange!).inDays / 30).round();
    if (tireChangeMonths > 24) {
      health -= 25;
    } else if (tireChangeMonths > 18) {
      health -= 15;
    }

    // Last service; every 6-12 months
    final serviceMonths = (now.difference(_lastService!).inDays / 30).round();
    if (serviceMonths > 12) {
      health -= 25;
    } else if (serviceMonths > 9) {
      health -= 10;
    }

    return health.clamp(0, 100);
  }

  Future<void> _saveBikeInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_lastOilChange == null ||
        _lastTireChange == null ||
        _lastService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all maintenance dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final token = await user.getIdToken();
      if (token == null) {
        throw Exception('Failed to get authentication token');
      }

      // Get current month name
      final currentMonth = DateFormat('MMM').format(DateTime.now());
      final currentKilometers = int.tryParse(_kilometersController.text.trim());

      if (currentKilometers == null) {
        throw Exception('Please enter a valid number for kilometers');
      }

      final healthPercent = _calculateHealthPercent();

      // Prepare data
      final bikeData = {
        "kilometers": {
          currentMonth: currentKilometers,
        },
        "maintenance": {
          "oil_change": DateFormat('yyyy-MM-dd').format(_lastOilChange!),
          "tire_change": DateFormat('yyyy-MM-dd').format(_lastTireChange!),
          "last_service": DateFormat('yyyy-MM-dd').format(_lastService!),
          "health_percent": healthPercent,
        },
      };

      final response = await http.post(
        Uri.parse(ApiConfig.getEndpoint("user/data")),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(bikeData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // refresh the home page
        ref.invalidate(fastApiDataProvider(user.uid));
        ref.invalidate(homeDataProvider);

        if (mounted) {
          final route = ref.read(goRouterProvider);
          final isEditing = route.canPop();
          if (isEditing) {
            route.pop();
          } else {
            route.go(getRoutePath(homeRoute));
          }
        }
      } else {
        throw Exception(
            "Failed to save bike info: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(goRouterProvider);
    final user = FirebaseAuth.instance.currentUser;
    // Check if we're editing (user exists and we can pop, meaning we came from profile)
    final isEditing = user != null && route.canPop();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: isEditing
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: appMainTextColor),
                  onPressed: () {
                    if (route.canPop()) {
                      route.pop();
                    }
                  },
                ),
                title: const Text(
                  'Edit Bike Info',
                  style: TextStyle(
                    color: appMainTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isEditing) const SizedBox(height: 20),
                  if (!isEditing)
                    const Text(
                      'Enter your Bike Info',
                      style: TextStyle(
                        color: appMainTextColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (isEditing) const SizedBox(height: 20),
                  const SizedBox(height: 40),

                  // Current Month Kilometers
                  AppTextFormField(
                    controller: _kilometersController,
                    focusNode: FocusNode(),
                    hint: 'Current Month Kilometers',
                    prefixIcon:
                        const Icon(Icons.speed_outlined, color: appTextColor),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter kilometers';
                      }
                      final km = int.tryParse(value.trim());
                      if (km == null || km < 0) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Last Oil Change
                  AppTextFormField(
                    controller: _oilChangeController,
                    focusNode: FocusNode(),
                    hint: 'Last Oil Change',
                    prefixIcon: const Icon(Icons.oil_barrel_outlined,
                        color: appTextColor),
                    suffixIcon: const Icon(Icons.calendar_today,
                        color: appTextColor, size: 20),
                    readOnly: true,
                    onTap: () {
                      _selectDate(context, (date) {
                        setState(() {
                          _lastOilChange = date;
                        });
                      }, _oilChangeController);
                    },
                    validator: (value) {
                      if (_lastOilChange == null) return 'Please select a date';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Last Tire Change
                  AppTextFormField(
                    controller: _tireChangeController,
                    focusNode: FocusNode(),
                    hint: 'Last Tire Change',
                    prefixIcon: const Icon(Icons.tire_repair_outlined,
                        color: appTextColor),
                    suffixIcon: const Icon(Icons.calendar_today,
                        color: appTextColor, size: 20),
                    readOnly: true,
                    onTap: () {
                      _selectDate(context, (date) {
                        setState(() {
                          _lastTireChange = date;
                        });
                      }, _tireChangeController);
                    },
                    validator: (value) {
                      if (_lastTireChange == null)
                        return 'Please select a date';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Last Service
                  AppTextFormField(
                    controller: _serviceController,
                    focusNode: FocusNode(),
                    hint: 'Last Service',
                    prefixIcon:
                        const Icon(Icons.build_outlined, color: appTextColor),
                    suffixIcon: const Icon(Icons.calendar_today,
                        color: appTextColor, size: 20),
                    readOnly: true,
                    onTap: () {
                      _selectDate(context, (date) {
                        setState(() {
                          _lastService = date;
                        });
                      }, _serviceController);
                    },
                    validator: (value) {
                      if (_lastService == null) return 'Please select a date';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveBikeInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appButtonColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
