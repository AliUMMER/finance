import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference _userCollection =
      FirebaseFirestore.instance.collection('users');

  /// Create user document in Firestore
  Future<void> createUser({
    required String uid,
    required String email,
    required String companyName,
    required String address,
    required String phone,
  }) async {
    try {
      await _userCollection.doc(uid).set({
        'uid': uid,
        'email': email,
        'companyName': companyName,
        'address': address,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("User data stored for $uid");
    } catch (e) {
      print("Error storing user data: $e");
      throw e;
    }
  }

  /// Get user data
  Future<DocumentSnapshot> getUser(String uid) async {
    return await _userCollection.doc(uid).get();
  }

  /// Stream user data
  Stream<DocumentSnapshot> streamUser(String uid) {
    return _userCollection.doc(uid).snapshots();
  }

  /// Delete user data
  Future<void> deleteUser(String uid) async {
    try {
      await _userCollection.doc(uid).delete();
    } catch (e) {
      throw Exception("Failed to delete user: $e");
    }
  }
}
