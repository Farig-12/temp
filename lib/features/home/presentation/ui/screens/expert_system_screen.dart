import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/expert_system_providers.dart';
import '../../../../../core/utils/theme/app_colors.dart';

class ExpertSystemScreen extends ConsumerStatefulWidget {
  const ExpertSystemScreen({super.key});

  @override
  ConsumerState<ExpertSystemScreen> createState() => _ExpertSystemScreenState();
}

class _ExpertSystemScreenState extends ConsumerState<ExpertSystemScreen> {
  final Set<String> _observedSymptoms = <String>{};
  final TextEditingController _optionController = TextEditingController();

  int _groupIndex = 0;
  int _batchStart = 0;
  bool _isSubmitting = false;
  Map<String, dynamic>? _diagnosisResult;

  @override
  void dispose() {
    _optionController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnosis() async {
    if (_observedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No symptoms selected. Please select at least one option 1-4.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await ref.read(
        expertSystemDiagnoseProvider({
          'selected_symptom_codes': _observedSymptoms.toList()..sort(),
          'top_k': 5,
        }).future,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _diagnosisResult = result;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Diagnosis failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _moveToNextDomain(List<Map<String, dynamic>> groups) {
    if (_groupIndex < groups.length - 1) {
      setState(() {
        _groupIndex += 1;
        _batchStart = 0;
      });
    } else {
      _runDiagnosis();
    }
  }

  void _handleOption(int option, List<Map<String, dynamic>> groups) {
    if (_groupIndex >= groups.length) {
      return;
    }

    final currentGroup = groups[_groupIndex];
    final symptoms = (currentGroup['symptoms'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    if (option >= 1 && option <= 4) {
      final localIndex = option - 1;
      final symptomIndex = _batchStart + localIndex;

      if (symptomIndex >= symptoms.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid option for this batch.')),
        );
        return;
      }

      final code = symptoms[symptomIndex]['code']?.toString() ?? '';
      if (code.isEmpty) {
        return;
      }

      setState(() {
        if (_observedSymptoms.contains(code)) {
          _observedSymptoms.remove(code);
        } else {
          _observedSymptoms.add(code);
        }

        _diagnosisResult = null;
        _batchStart += 4;

        if (_batchStart >= symptoms.length) {
          if (_groupIndex < groups.length - 1) {
            _groupIndex += 1;
            _batchStart = 0;
          }
        }
      });
      return;
    }

    if (option == 5) {
      _moveToNextDomain(groups);
      return;
    }

    if (option == 6) {
      _runDiagnosis();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter an option number between 1 and 6.')),
    );
  }

  void _submitOption(List<Map<String, dynamic>> groups) {
    final raw = _optionController.text.trim();
    final option = int.tryParse(raw);

    _optionController.clear();

    if (option == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number (1-6).')),
      );
      return;
    }

    _handleOption(option, groups);
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(expertSystemQuestionsProvider);

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBackgroundColor,
        foregroundColor: appTextColor,
        title: const Text('Expert Diagnosis QnA'),
      ),
      body: questionsAsync.when(
        data: (data) {
          final groups =
              (data['symptom_groups'] as List<dynamic>? ?? <dynamic>[])
                  .cast<Map<String, dynamic>>();

          if (groups.isEmpty) {
            return const Center(
              child: Text(
                'No question domains found.',
                style: TextStyle(color: appTextColor),
              ),
            );
          }

          final clampedGroupIndex = _groupIndex.clamp(0, groups.length - 1);
          final currentGroup = groups[clampedGroupIndex];
          final domain = currentGroup['domain']?.toString() ?? 'Domain';
          final symptoms =
              (currentGroup['symptoms'] as List<dynamic>? ?? <dynamic>[])
                  .cast<Map<String, dynamic>>();

          final batch = symptoms.skip(_batchStart).take(4).toList();
          final totalDomains = groups.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildProgressCard(
                domain: domain,
                currentDomain: clampedGroupIndex + 1,
                totalDomains: totalDomains,
                selectedCount: _observedSymptoms.length,
              ),
              const SizedBox(height: 12),
              _buildBatchCard(batch),
              const SizedBox(height: 12),
              _buildOptionInput(groups),
              const SizedBox(height: 12),
              _buildOptionLegend(),
              const SizedBox(height: 16),
              if (_isSubmitting)
                const Center(
                  child: CircularProgressIndicator(color: appButtonColor),
                ),
              if (_diagnosisResult != null)
                _buildResultSection(_diagnosisResult!),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: appButtonColor),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Unable to load expert-system questions\n$error',
              style: const TextStyle(color: appTextColor),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard({
    required String domain,
    required int currentDomain,
    required int totalDomains,
    required int selectedCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Domain $currentDomain of $totalDomains: $domain',
            style: const TextStyle(
              color: appTextColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Symptoms selected: $selectedCount',
            style: const TextStyle(color: appMainTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(List<Map<String, dynamic>> batch) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select observed symptoms using option number:',
            style: TextStyle(color: appTextColor, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (batch.isEmpty)
            const Text(
              'No more symptoms in this domain. Enter 5 for next domain or 6 to diagnose.',
              style: TextStyle(color: appMainTextColor),
            ),
          ...batch.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final symptom = entry.value;
            final code = symptom['code']?.toString() ?? '';
            final text = symptom['text']?.toString() ?? code;
            final isSelected = _observedSymptoms.contains(code);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$idx. [${isSelected ? 'X' : ' '}] $code - $text',
                style: const TextStyle(color: appMainTextColor),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOptionInput(List<Map<String, dynamic>> groups) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _optionController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: appTextColor),
            decoration: InputDecoration(
              hintText: 'Enter option number (1-6)',
              hintStyle: const TextStyle(color: appSecondaryTextColor),
              filled: true,
              fillColor: appCardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _submitOption(groups),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _submitOption(groups),
          style: ElevatedButton.styleFrom(
            backgroundColor: appButtonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Widget _buildOptionLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Options',
            style: TextStyle(color: appTextColor, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('1-4: Toggle symptom in current batch',
              style: TextStyle(color: appMainTextColor)),
          Text('5: Switch to next symptom group',
              style: TextStyle(color: appMainTextColor)),
          Text('6: End QnA and run diagnosis',
              style: TextStyle(color: appMainTextColor)),
        ],
      ),
    );
  }

  Widget _buildResultSection(Map<String, dynamic> result) {
    final topMatch = result['top_match'] as Map<String, dynamic>?;
    final items = (result['results'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Diagnosis Results',
            style: TextStyle(
              color: appTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (topMatch != null)
            Text(
              "Top match: ${topMatch['diagnosis_code']} (${((((topMatch['score'] ?? 0.0) as num) * 100)).toStringAsFixed(1)}%)",
              style: const TextStyle(color: appMainTextColor),
            ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final score = ((item['score'] ?? 0.0) as num).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${item['diagnosis_code']} - ${item['diagnosis']}",
                    style: const TextStyle(
                      color: appTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Score: ${(score * 100).toStringAsFixed(1)}% | Domain: ${item['domain']}",
                    style:
                        const TextStyle(color: appMainTextColor, fontSize: 13),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
