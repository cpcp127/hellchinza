import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hellchinza/inquiry/domain/inquiry_model.dart';

class InquiryRepo {
  InquiryRepo(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  Future<void> createInquiry({
    required String uid,
    required String message,
    XFile? image,
  }) async {
    final docRef = _db.collection('inquiries').doc();

    String? imageUrl;

    if (image != null) {
      final ref = _storage
          .ref()
          .child('inquiries')
          .child(uid)
          .child('${docRef.id}.webp');

      final task = await ref.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/webp'),
      );

      imageUrl = await task.ref.getDownloadURL();
    }

    await docRef.set({
      'id': docRef.id,
      'authorUid': uid,
      'message': message,
      'status': 'open',
      'imageUrls': imageUrl == null ? [] : [imageUrl],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'answer': '',
    });
  }

  Query<Map<String, dynamic>> getMyInquiryQuery(String uid) {
    return _db
        .collection('inquiries')
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true);
  }
}