import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.name = '',
    this.email = '',
    this.password = '',
    this.error = '',
  });

  final bool isAuthenticated;
  final String name;
  final String email;
  final String password;
  final String error;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    final name = prefs.getString('name') ?? 'Dr. Eion Morgan';
    final email = prefs.getString('email') ?? 'eion.morgan@medgate.org';
    final password = prefs.getString('password') ?? '';

    return AuthState(
      isAuthenticated: isAuthenticated,
      name: name,
      email: email,
      password: password,
    );
  }

  bool register({
    required String name,
    required String email,
    required String password,
  }) {
    if (name.trim().isEmpty || !_validEmail(email) || password.length < 6) {
      state = AuthState(
        name: state.name,
        email: state.email,
        password: state.password,
        error: 'Enter a name, valid email, and 6+ character password.',
      );
      return false;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool('isAuthenticated', true);
    prefs.setString('name', name.trim());
    prefs.setString('email', email.trim());
    prefs.setString('password', password);

    state = AuthState(
      isAuthenticated: true,
      name: name.trim(),
      email: email.trim(),
      password: password,
    );
    return true;
  }

  bool signIn({required String email, required String password}) {
    final matchesRegisteredUser =
        email.trim() == state.email && password == state.password;
    final allowFirstLocalLogin = state.email.isEmpty && _validEmail(email);

    if (password.length < 6 ||
        (!matchesRegisteredUser && !allowFirstLocalLogin)) {
      state = AuthState(
        name: state.name,
        email: state.email,
        password: state.password,
        error: 'Check your email and password.',
      );
      return false;
    }

    final name = state.name.isNotEmpty ? state.name : 'Dr. Eion Morgan';
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool('isAuthenticated', true);
    prefs.setString('email', email.trim());
    prefs.setString('password', password);
    prefs.setString('name', name);

    state = AuthState(
      isAuthenticated: true,
      name: name,
      email: email.trim(),
      password: password,
    );
    return true;
  }

  void signOut() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool('isAuthenticated', false);

    state = AuthState(
      isAuthenticated: false,
      name: state.name,
      email: state.email,
      password: state.password,
    );
  }

  void syncProfile({required String name, required String email}) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('name', name);
    prefs.setString('email', email);

    state = AuthState(
      isAuthenticated: state.isAuthenticated,
      name: name,
      email: email,
      password: state.password,
    );
  }

  bool _validEmail(String email) => email.contains('@') && email.contains('.');
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
