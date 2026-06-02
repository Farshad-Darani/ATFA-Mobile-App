import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Supabase credentials — publishable key is safe in client code.
// The secret key NEVER goes here. Edge Functions use the secret server-side.
// ─────────────────────────────────────────────────────────────────────────────
const String _supabaseUrl = 'https://ajquzzfnyoxfeiljqfvk.supabase.co';
const String _supabasePublishableKey =
    'sb_publishable_XBK42yiFqlwLdcgQFdi01A_NcaKLK1O';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static SupabaseClient get client => Supabase.instance.client;

  /// Call once in main() before runApp().
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabasePublishableKey,
    );
  }

  /// Ensures there is always an active session.
  /// If the user has no session (first launch / after sign-out) this silently
  /// creates an anonymous session so usage can be tracked immediately.
  static Future<void> ensureSession() async {
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  }

  // ── Auth shortcuts ──────────────────────────────────────────────────────────
  User? get currentUser => client.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  /// True when the current session is anonymous (no email/password yet).
  bool get isAnonymous => currentUser?.isAnonymous == true;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<AuthResponse> signUpWithEmail(String email, String password) =>
      client.auth.signUp(email: email, password: password);

  Future<AuthResponse> signInWithEmail(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => client.auth.signOut();

  Future<void> resetPassword(String email) =>
      client.auth.resetPasswordForEmail(email);
}
