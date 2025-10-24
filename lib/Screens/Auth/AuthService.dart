// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sign in with email & password.
  /// Returns UserCredential on success, throws FirebaseAuthException on failure.
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  /// Sign out
  Future<void> signOut() => _auth.signOut();

  /// Get the Firestore role for the current user (fallback method).
  /// Returns 'user' when no doc/role exists.
  Future<String> getRoleFromFirestore(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return 'user';
    final data = doc.data();
    if (data == null) return 'user';
    return (data['role'] ?? 'user') as String;
  }

  /// Check admin via custom claims (preferred).
  /// Tries to refresh token and inspect admin claim.
  Future<bool> isAdminFromClaims({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final idTokenResult = await user.getIdTokenResult(forceRefresh);
    final claims = idTokenResult.claims ?? {};
    return claims['admin'] == true || claims['admin'] == 'true';
  }

  /// Convenient method that first checks claims (secure), then falls back to Firestore role.
  Future<bool> isAdmin(String uid, {bool forceRefresh = false}) async {
    try {
      final claimsAdmin = await isAdminFromClaims(forceRefresh: forceRefresh);
      if (claimsAdmin) return true;
    } catch (_) {
      // ignore token/claims error and fallback
    }
    final role = await getRoleFromFirestore(uid);
    return role == 'admin';
  }

  /// Helper to get current user's uid if signed in
  String? currentUid() => _auth.currentUser?.uid;
}
