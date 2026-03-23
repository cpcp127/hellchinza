import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:hellchinza/inquiry/data/inquiry_repo.dart';
import 'package:hellchinza/inquiry/presentation/inquiry_controller.dart';
import 'package:hellchinza/inquiry/presentation/inquiry_state.dart';

final inquiryAuthProvider = Provider<fb_auth.FirebaseAuth>((ref) {
  return fb_auth.FirebaseAuth.instance;
});

final inquiryFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final inquiryStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final inquiryRepoProvider = Provider<InquiryRepo>((ref) {
  return InquiryRepo(
    ref.read(inquiryFirestoreProvider),
    ref.read(inquiryStorageProvider),
  );
});

final inquiryControllerProvider =
    StateNotifierProvider.autoDispose<InquiryController, InquiryState>((ref) {
      return InquiryController(ref);
    });

final inquiryUidProvider = Provider<String?>((ref) {
  return ref.read(inquiryAuthProvider).currentUser?.uid;
});
