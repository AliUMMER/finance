import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  static AuthService? _instance;

  // Singleton pattern
  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  AuthService._() {
    _user = _firebaseAuth.currentUser;
    _firebaseAuth.authStateChanges().listen((user) {
      _user = user;
      print('Auth state changed: user is ${user?.uid ?? "null"}');
    });
  }

  User? get user => _user;
  bool get isSignedIn => _user != null;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Login with email & password
  Future<bool> login(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;
      print('Login successful: ${_user?.uid}');
      return _user != null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Register only Firebase Auth user (no Firestore)
  Future<bool> createUser(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;
      print('User created in Firebase Auth: ${_user?.uid}');
      return _user != null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('User creation failed: $e');
    }
  }

  /// Register new user and save additional data in Firestore
  Future<bool> registerUserWithData({
    required String email,
    required String password,
    required String companyName,
    required String address,
    required String phone,
  }) async {
    try {
      final success = await createUser(email, password);
      if (success && _user != null) {
        // Write user profile data in Firestore
        await _firestore.collection('users').doc(_user!.uid).set({
          'uid': _user!.uid,
          'email': email,
          'companyName': companyName,
          'address': address,
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('User document created in Firestore for uid: ${_user!.uid}');
        return true;
      }
      return false;
    } catch (e) {
      print('Error during registration with data: $e');
      // Clean up user if Firestore write failed
      if (_user != null) {
        await _user!.delete();
        _user = null;
        print('Deleted Firebase Auth user due to Firestore failure.');
      }
      rethrow;
    }
  }

  // Get user data from Firestore by uid
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Update user data in Firestore by uid
  Future<void> updateUserData({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update(updates);
      print('User data updated for uid: $uid');
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  // Sign out current user
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      _user = null;
      print('User signed out');
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Get current Firebase user (fresh instance)
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      print('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle FirebaseAuthException error messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}
