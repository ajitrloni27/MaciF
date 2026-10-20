import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileState {
  const ProfileState({
    required this.name,
    required this.email,
    required this.role,
    required this.badge,
    required this.experience,
    required this.bloodGroup,
    required this.station,
    required this.bio,
  });

  final String name;
  final String email;
  final String role;
  final String badge;
  final String experience;
  final String bloodGroup;
  final String station;
  final String bio;

  ProfileState copyWith({
    String? name,
    String? email,
    String? role,
    String? badge,
    String? experience,
    String? bloodGroup,
    String? station,
    String? bio,
  }) {
    return ProfileState(
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      badge: badge ?? this.badge,
      experience: experience ?? this.experience,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      station: station ?? this.station,
      bio: bio ?? this.bio,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  late final SharedPreferences _prefs;

  @override
  ProfileState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final name = _prefs.getString('clinician_name') ?? 'Dr. Eion Morgan';
    final email = _prefs.getString('clinician_email') ?? 'eion.morgan@medgate.org';
    final role = _prefs.getString('clinician_role') ?? 'Triage Paramedic';
    final badge = _prefs.getString('clinician_badge') ?? 'EMT-10928';
    final experience = _prefs.getString('clinician_experience') ?? '5 Years';
    final bloodGroup = _prefs.getString('clinician_blood_group') ?? 'B+';
    final station = _prefs.getString('clinician_station') ?? 'Sector 4 Emergency';
    final bio = _prefs.getString('clinician_bio') ?? 
        'Clinical specialist dedicated to providing the highest level of care through advanced digital tools and triage networks.';

    return ProfileState(
      name: name,
      email: email,
      role: role,
      badge: badge,
      experience: experience,
      bloodGroup: bloodGroup,
      station: station,
      bio: bio,
    );
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? role,
    String? badge,
    String? experience,
    String? bloodGroup,
    String? station,
    String? bio,
  }) async {
    state = state.copyWith(
      name: name,
      email: email,
      role: role,
      badge: badge,
      experience: experience,
      bloodGroup: bloodGroup,
      station: station,
      bio: bio,
    );

    if (name != null) await _prefs.setString('clinician_name', name);
    if (email != null) await _prefs.setString('clinician_email', email);
    if (role != null) await _prefs.setString('clinician_role', role);
    if (badge != null) await _prefs.setString('clinician_badge', badge);
    if (experience != null) await _prefs.setString('clinician_experience', experience);
    if (bloodGroup != null) await _prefs.setString('clinician_blood_group', bloodGroup);
    if (station != null) await _prefs.setString('clinician_station', station);
    if (bio != null) await _prefs.setString('clinician_bio', bio);

    // Sync back to authProvider name/email
    ref.read(authProvider.notifier).syncProfile(
      name: state.name,
      email: state.email,
    );
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);
