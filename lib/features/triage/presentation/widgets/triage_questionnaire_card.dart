import 'package:flutter/material.dart';
import '../../../../core/theme/glass_style.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../logic/triage_models.dart';

class TriageQuestionnaireCard extends StatelessWidget {
  const TriageQuestionnaireCard({
    super.key,
    required this.questionnaire,
    required this.onToggleFever,
    required this.onToggleChestPain,
    required this.onToggleBreathlessness,
    required this.onToggleBleedingInjury,
    required this.onToggleAbdominalPain,
    required this.onToggleSkinProblem,
    required this.onToggleChildUnder5,
    required this.onTogglePregnancy,
  });

  final TriageSymptomQuestionnaire questionnaire;
  final ValueChanged<bool> onToggleFever;
  final ValueChanged<bool> onToggleChestPain;
  final ValueChanged<bool> onToggleBreathlessness;
  final ValueChanged<bool> onToggleBleedingInjury;
  final ValueChanged<bool> onToggleAbdominalPain;
  final ValueChanged<bool> onToggleSkinProblem;
  final ValueChanged<bool> onToggleChildUnder5;
  final ValueChanged<bool> onTogglePregnancy;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rtl_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Symptom Questionnaire',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select all symptoms present to aid routing and triage.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SymptomChip(
                label: 'Fever',
                icon: Icons.thermostat_rounded,
                selected: questionnaire.fever,
                isRedFlag: false,
                onSelected: onToggleFever,
              ),
              _SymptomChip(
                label: 'Chest pain',
                icon: Icons.heart_broken_rounded,
                selected: questionnaire.chestPain,
                isRedFlag: true,
                onSelected: onToggleChestPain,
              ),
              _SymptomChip(
                label: 'Breathlessness',
                icon: Icons.air_rounded,
                selected: questionnaire.breathlessness,
                isRedFlag: true,
                onSelected: onToggleBreathlessness,
              ),
              _SymptomChip(
                label: 'Bleeding / Injury',
                icon: Icons.healing_rounded,
                selected: questionnaire.bleedingInjury,
                isRedFlag: true,
                onSelected: onToggleBleedingInjury,
              ),
              _SymptomChip(
                label: 'Abdominal pain',
                icon: Icons.personal_injury_rounded,
                selected: questionnaire.abdominalPain,
                isRedFlag: false,
                onSelected: onToggleAbdominalPain,
              ),
              _SymptomChip(
                label: 'Skin problem',
                icon: Icons.bubble_chart_rounded,
                selected: questionnaire.skinProblem,
                isRedFlag: false,
                onSelected: onToggleSkinProblem,
              ),
              _SymptomChip(
                label: 'Child under 5',
                icon: Icons.child_care_rounded,
                selected: questionnaire.childUnder5,
                isRedFlag: false,
                onSelected: onToggleChildUnder5,
              ),
              _SymptomChip(
                label: 'Pregnancy',
                icon: Icons.pregnant_woman_rounded,
                selected: questionnaire.pregnancy,
                isRedFlag: false,
                onSelected: onTogglePregnancy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SymptomChip extends StatelessWidget {
  const _SymptomChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isRedFlag,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool isRedFlag;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = isRedFlag ? Colors.redAccent : theme.colorScheme.primary;

    return InkWell(
      onTap: () => onSelected(!selected),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: glassDecoration(
          color: selected ? activeColor.withValues(alpha: 0.25) : Colors.transparent,
          radius: 20,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? activeColor : theme.iconTheme.color?.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? activeColor : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
