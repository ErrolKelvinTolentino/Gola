import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoalStorageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _goalsCollection(String uid) {
    return _db.collection('users').doc(uid).collection('goals');
  }

  /// LOAD ALL GOALS
  Future<List<Map<String, dynamic>>> loadGoals() async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _goalsCollection(uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // 🔥 attach document ID
      return data;
    }).toList();
  }

  /// ADD NEW GOAL (Firestore auto ID)
  Future<String?> addGoal({
    required String title,
    required String description,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _goalsCollection(uid).add({
      'title': title,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// UPDATE GOAL
  Future<void> updateGoal({
    required String goalId,
    required Map<String, dynamic> data,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _goalsCollection(uid).doc(goalId).update(data);
  }

  /// DELETE GOAL
  Future<void> deleteGoal(String goalId) async {
    final uid = _uid;
    if (uid == null) return;

    await _goalsCollection(uid).doc(goalId).delete();
  }
}
