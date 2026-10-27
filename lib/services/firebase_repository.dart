import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/base_model.dart';

class FirebaseRepository<T extends BaseModel> {
  final CollectionReference _collection;
  final T Function(Map<String, dynamic> map, String id) _fromMap;

  FirebaseRepository(String collectionPath, this._fromMap)
    : _collection = FirebaseFirestore.instance.collection(collectionPath);

  // Lắng nghe dữ liệu realtime từ Firebase
  Stream<List<T>> getRealtimeList({String? whereField, dynamic whereValue}) {
    Query query = _collection;
    if (whereField != null) {
      query = query.where(whereField, isEqualTo: whereValue);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return _fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Lấy 1 document theo ID
  Stream<T?> getRealtimeById(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return _fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  // Thêm mới document
  Future<void> add(T item) async {
    await _collection.doc(item.id).set(item.toMap());
  }

  // Cập nhật document
  Future<void> update(T item) async {
    await _collection.doc(item.id).update(item.toMap());
  }

  // Xóa document theo ID
  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> deleteWithSubcollection(
    String id,
    String subcollectionName,
  ) async {
    final reference = _collection.doc(id);
    final subcollection = await reference.collection(subcollectionName).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final document in subcollection.docs) {
      batch.delete(document.reference);
    }
    batch.delete(reference);
    await batch.commit();
  }

  // Thêm vào trong class FirebaseRepository<T extends BaseModel>
  Future<T?> getOneByField(String fieldName, dynamic value) async {
    final querySnapshot = await _collection
        .where(fieldName, isEqualTo: value)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      return _fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getSubcollectionMaps(
    String documentId,
    String subcollectionName,
  ) async {
    final snapshot = await _collection
        .doc(documentId)
        .collection(subcollectionName)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<bool> existsByFields(Map<String, dynamic> fields) async {
    Query query = _collection.limit(1);
    for (final entry in fields.entries) {
      query = query.where(entry.key, isEqualTo: entry.value);
    }
    final snapshot = await query.get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> replaceSubcollectionMaps(
    String documentId,
    String subcollectionName,
    List<Map<String, dynamic>> items,
  ) async {
    final reference = _collection.doc(documentId).collection(subcollectionName);
    final existing = await reference.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final document in existing.docs) {
      batch.delete(document.reference);
    }
    for (final item in items) {
      batch.set(reference.doc(), item);
    }
    await batch.commit();
  }

  Future<void> setWithSubcollectionMaps(
    T item,
    String subcollectionName,
    List<Map<String, dynamic>> items,
  ) async {
    final document = _collection.doc(item.id);
    final subcollection = document.collection(subcollectionName);
    final existing = await subcollection.get();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(document, item.toMap());
    for (final oldDocument in existing.docs) {
      batch.delete(oldDocument.reference);
    }
    for (final data in items) {
      batch.set(subcollection.doc(), data);
    }
    await batch.commit();
  }
}
