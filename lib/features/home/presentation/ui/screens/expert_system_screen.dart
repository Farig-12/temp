import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/expert_system_providers.dart';
import '../../../../../core/route/go_router_provider.dart';
import '../../../../../core/route/route_names.dart';
import '../../../../../core/utils/theme/app_colors.dart';

class ExpertSystemScreen extends ConsumerStatefulWidget {
  const ExpertSystemScreen({super.key});

  @override
  ConsumerState<ExpertSystemScreen> createState() => _ExpertSystemScreenState();
}

class _ExpertSystemScreenState extends ConsumerState<ExpertSystemScreen> {
  final Set<String> _observedSymptoms = <String>{};

  int _groupIndex = 0;
  int _batchStart = 0;
  int? _selectedBatchOption;
  bool _isSubmitting = false;
  Map<String, dynamic>? _diagnosisResult;

  Future<void> _runDiagnosis() async {
    if (_observedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one symptom to diagnose.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _selectedBatchOption = null;
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
        _selectedBatchOption = null;
      });
    } else {
      _runDiagnosis();
    }
  }

  void _advanceBatch(List<Map<String, dynamic>> symptoms, int groupCount) {
    _batchStart += 4;
    if (_batchStart >= symptoms.length && _groupIndex < groupCount - 1) {
      _groupIndex += 1;
      _batchStart = 0;
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
        _selectedBatchOption = null;
        _advanceBatch(symptoms, groups.length);
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
      const SnackBar(content: Text('Select a symptom option from the list.')),
    );
  }

  void _submitSelectedOption(List<Map<String, dynamic>> groups) {
    if (_selectedBatchOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose one symptom before continuing.')),
      );
      return;
    }

    _handleOption(_selectedBatchOption!, groups);
  }

  void _goToServiceRequest() {
    ref.read(goRouterProvider).push(getRoutePath(serviceRequestRoute));
  }

  void _openRecommendedGuides(String diagnosisQuery) {
    final query = diagnosisQuery.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Diagnosis is empty. Run diagnosis first.')),
      );
      return;
    }

    final encoded = Uri.encodeQueryComponent(query);
    ref
        .read(goRouterProvider)
        .push('${getRoutePath(findGuideRoute)}?q=$encoded');
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

          final symptomLookup = <String, String>{};
          for (final group in groups) {
            final symptoms =
                (group['symptoms'] as List<dynamic>? ?? <dynamic>[])
                    .cast<Map<String, dynamic>>();
            for (final symptom in symptoms) {
              final code = symptom['code']?.toString() ?? '';
              final text = symptom['text']?.toString() ?? code;
              if (code.isNotEmpty && text.isNotEmpty) {
                symptomLookup[code] = text;
              }
            }
          }

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
              _buildSelectionActions(groups, hasBatchItems: batch.isNotEmpty),
              const SizedBox(height: 12),
              _buildFlowHint(),
              const SizedBox(height: 16),
              if (_isSubmitting)
                const Center(
                  child: CircularProgressIndicator(color: appButtonColor),
                ),
              if (_diagnosisResult != null)
                _buildResultSection(_diagnosisResult!, symptomLookup),
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
            'Select observed symptom',
            style: TextStyle(color: appTextColor, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (batch.isEmpty)
            const Text(
              'No more symptoms in this domain. Use Skip Domain or End Q&A.',
              style: TextStyle(color: appMainTextColor),
            ),
          ...batch.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final symptom = entry.value;
            final code = symptom['code']?.toString() ?? '';
            final text = symptom['text']?.toString() ?? code;
            final isSelected = _observedSymptoms.contains(code);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: appBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedBatchOption == idx
                      ? appButtonColor.withOpacity(0.45)
                      : appTextColor.withOpacity(0.08),
                ),
              ),
              child: RadioListTile<int>(
                value: idx,
                groupValue: _selectedBatchOption,
                activeColor: appButtonColor,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedBatchOption = value;
                        });
                      },
                title: Text(
                  '$idx. $text',
                  style: const TextStyle(color: appMainTextColor),
                ),
                secondary: isSelected
                    ? const Icon(Icons.check_circle,
                        color: appButtonColor, size: 18)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectionActions(
    List<Map<String, dynamic>> groups, {
    required bool hasBatchItems,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting || !hasBatchItems
                ? null
                : () => _submitSelectedOption(groups),
            style: ElevatedButton.styleFrom(
              backgroundColor: appButtonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirm Selection'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _isSubmitting ? null : () => _moveToNextDomain(groups),
                style: OutlinedButton.styleFrom(
                  foregroundColor: appTextColor,
                  side: BorderSide(color: appTextColor.withOpacity(0.25)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.skip_next_outlined),
                label: const Text('Skip Domain'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _runDiagnosis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appButtonColor.withOpacity(0.9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.task_alt_outlined),
                label: const Text('End Q&A'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlowHint() {
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
            'How this works',
            style: TextStyle(color: appTextColor, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('Select one option and tap Confirm Selection',
              style: TextStyle(color: appMainTextColor)),
          Text('Skip Domain jumps to the next symptom group',
              style: TextStyle(color: appMainTextColor)),
          Text('End Q&A runs diagnosis with current selections',
              style: TextStyle(color: appMainTextColor)),
        ],
      ),
    );
  }

  Widget _buildResultSection(
    Map<String, dynamic> result,
    Map<String, String> symptomLookup,
  ) {
    final topMatch = result['top_match'] as Map<String, dynamic>?;
    final selectedCodes =
        (result['selected_symptom_codes'] as List<dynamic>? ?? <dynamic>[])
            .map((value) => value.toString())
            .toList();
    final selectedSymptoms = selectedCodes
        .map((code) => symptomLookup[code] ?? code)
        .where((text) => text.isNotEmpty)
        .toList();
    final score = ((topMatch?['score'] ?? 0.0) as num).toDouble();
    final diagnosisText = topMatch?['diagnosis']?.toString().trim() ?? '';
    final diagnosisDomain = topMatch?['domain']?.toString().trim() ?? '';
    final tentativeCost = topMatch?['cost']?.toString().trim() ?? '';
    final diagnosisQuery =
        diagnosisText.isNotEmpty ? diagnosisText : diagnosisDomain;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appButtonColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most Likely Problem',
            style: TextStyle(
              color: appTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (diagnosisText.isNotEmpty)
            _buildDiagnosisAccordion(
              diagnosisText: diagnosisText,
              domainText: diagnosisDomain,
            ),
          const SizedBox(height: 12),
          if (topMatch != null)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Confidence',
                    value: '${(score * 100).toStringAsFixed(1)}%',
                    icon: Icons.percent_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Tentative cost',
                    value:
                        tentativeCost.isNotEmpty ? tentativeCost : 'Not listed',
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          if (selectedSymptoms.isNotEmpty) ...[
            const Text(
              'Symptoms used',
              style: TextStyle(
                color: appTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedSymptoms
                  .map(
                    (symptom) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: appBackgroundColor,
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: appButtonColor.withOpacity(0.25)),
                      ),
                      child: Text(
                        symptom,
                        style: const TextStyle(color: appMainTextColor),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _goToServiceRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appButtonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.car_repair_outlined),
                  label: const Text('Find Mechanics'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: diagnosisQuery.isEmpty
                      ? null
                      : () => _openRecommendedGuides(diagnosisQuery),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appTextColor,
                    side: BorderSide(color: appTextColor.withOpacity(0.25)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Recommended Guides'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisAccordion({
    required String diagnosisText,
    required String domainText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: appBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appButtonColor.withOpacity(0.22)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: appTextColor,
          collapsedIconColor: appTextColor,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: const Row(
            children: [
              Icon(Icons.medical_information_outlined, color: appButtonColor),
              SizedBox(width: 8),
              Text(
                'Diagnosis',
                style: TextStyle(
                  color: appTextColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          subtitle: domainText.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    domainText,
                    style: const TextStyle(
                      color: appSecondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ),
          children: [
            Text(
              diagnosisText,
              style: const TextStyle(
                color: appMainTextColor,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appButtonColor.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: appButtonColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: appButtonColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: appSecondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: appTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
