import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repositories/expense_repository.dart';

/// Grava em `users/{uid}/expenses`. O cache offline do Firestore garante que o
/// registro funcione sem internet e sincronize depois.
class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository(
      {required this.userId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('expenses');

  @override
  Stream<List<ExpenseEntity>> watchExpenses() {
    return _collection
        .orderBy('date', descending: true)
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> addExpense(ExpenseEntity expense) {
    return _collection.doc(expense.id).set({
      'amount': expense.amount,
      'category': expense.category.name,
      'description': expense.description,
      'date': Timestamp.fromDate(expense.date),
    });
  }

  ExpenseEntity _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    // Escritas locais pendentes chegam com `date` preenchido pelo cliente.
    final rawDate = data['date'];
    return ExpenseEntity(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      category: ExpenseCategory.fromName(data['category'] as String?),
      description: (data['description'] as String?) ?? '',
      date: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
    );
  }
}
