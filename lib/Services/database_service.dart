import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _users => _firestore.collection('users');

  Future<void> createUser({
    required String uid,
    required String email,
    required String companyName,
    required String address,
    required String phone,
  }) async {
    await _users.doc(uid).set({
      'uid': uid,
      'email': email,
      'companyName': companyName,
      'address': address,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createTransaction({
    required String uid,
    required String date,
    required int cashIn,
    required int cashOut,
    required String description,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc();

    await docRef.set({
      'enteredDate': date,
      'cashIn': cashIn,
      'cashOut': cashOut,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveTransaction(String userId, Map<String, dynamic> data) async {
    final txns = _users.doc(userId).collection('transactions');

    if (!data.containsKey('createdAt')) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await txns.add(data);
  }

  Stream<QuerySnapshot> streamTransactions(String uid) {
    return _users
        .doc(uid)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
