import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_page_wrapper.dart';
import '../../../core/widgets/floating_nav_bar.dart';
import '../../../core/widgets/glass_container.dart';
import '../providers/settings_provider.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_metrics.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, ProfileState profile) {
    final nameController = TextEditingController(text: profile.name);
    final emailController = TextEditingController(text: profile.email);
    final roleController = TextEditingController(text: profile.role);
    final badgeController = TextEditingController(text: profile.badge);
    final experienceController = TextEditingController(text: profile.experience);
    final bloodGroupController = TextEditingController(text: profile.bloodGroup);
    final stationController = TextEditingController(text: profile.station);
    final bioController = TextEditingController(text: profile.bio);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Clinician Profile'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(labelText: 'Medical Role / Specialty'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: badgeController,
                    decoration: const InputDecoration(labelText: 'Badge Number / License'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: experienceController,
                          decoration: const InputDecoration(labelText: 'Experience'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: bloodGroupController,
                          decoration: const InputDecoration(labelText: 'Blood Type'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: stationController,
                    decoration: const InputDecoration(labelText: 'Station / Base Facility'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bioController,
                    decoration: const InputDecoration(labelText: 'Biography / Notes'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(profileProvider.notifier).updateProfile(
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                      role: roleController.text.trim(),
                      badge: badgeController.text.trim(),
                      experience: experienceController.text.trim(),
                      bloodGroup: bloodGroupController.text.trim(),
                      station: stationController.text.trim(),
                      bio: bioController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final profile = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedPageWrapper(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileHeader(
                onEdit: () => _showEditProfileDialog(context, ref, profile),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProfileMetrics(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dispatch Info',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showEditProfileDialog(context, ref, profile),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit Profile'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: Row(
                        children: [
                          const Icon(Icons.pin_drop_rounded, color: kMedicalAccent, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.station,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Current assigned dispatch facility',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isDark ? Colors.white30 : Colors.black38,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Biography',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.bio,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'App Theme',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appearance',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: isDark ? Colors.white54 : Colors.black45,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select how MedGate appears on your device.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.white30 : Colors.black38,
                                ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('System'),
                                  icon: Icon(Icons.brightness_auto_rounded),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                  icon: Icon(Icons.light_mode_rounded),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                  icon: Icon(Icons.dark_mode_rounded),
                                ),
                              ],
                              selected: {mode},
                              onSelectionChanged: (selection) async {
                                await ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(selection.first);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Developer Options',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Component Gallery',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: isDark ? Colors.white54 : Colors.black45,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Inspect and test clinical UI components in isolation.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.white30 : Colors.black38,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => context.go('/component-gallery'),
                                icon: const Icon(Icons.palette_rounded),
                                label: const Text('Open Gallery'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FloatingNavBar(),
    );
  }
}
