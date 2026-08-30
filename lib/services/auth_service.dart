import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Wraps Supabase Auth with user-friendly error messages.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseService _supa = SupabaseService();

  User? get currentUser => _supa.currentUser;
  bool get isSignedIn => _supa.isSignedIn;
  bool get isAnonymous => _supa.isAnonymous;
  Stream<AuthState> get authStateChanges => _supa.authStateChanges;

  // ── Anonymous → Permanent conversion ────────────────────────────────────────
  /// Upgrades an anonymous session to a permanent account with email + password.
  /// The user ID is preserved, so usage history (analyses count) carries over.
  /// Returns null on success, or a user-facing error string.
  Future<String?> convertAnonymousToPermanent(String email, String password) async {
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(email: email.trim(), password: password),
      );
      return null;
    } on AuthException catch (e) {
      return _friendlyAuthError(e.message);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Sign Up ─────────────────────────────────────────────────────────────────
  /// Returns null on success, or a user-facing error string.
  Future<String?> signUp(String email, String password) async {
    try {
      await _supa.signUpWithEmail(email.trim(), password);
      return null;
    } on AuthException catch (e) {
      return _friendlyAuthError(e.message);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Sign In ─────────────────────────────────────────────────────────────────
  /// Returns null on success, or a user-facing error string.
  Future<String?> signIn(String email, String password) async {
    try {
      await _supa.signInWithEmail(email.trim(), password);
      return null;
    } on AuthException catch (e) {
      return _friendlyAuthError(e.message);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Sign Out ────────────────────────────────────────────────────────────────
  Future<void> signOut() => _supa.signOut();

  // ── Password Reset ──────────────────────────────────────────────────────────
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _supa.resetPassword(email.trim());
      return null;
    } on AuthException catch (e) {
      return _friendlyAuthError(e.message);
    } catch (_) {
      return 'Could not send reset email. Please try again.';
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _friendlyAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email already registered') ||
        msg.contains('already been registered') ||
        msg.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('unable to validate email')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('email rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return raw;
  }
}
