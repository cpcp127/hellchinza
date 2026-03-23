import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hellchinza/inquiry/providers/inquiry_provider.dart';
import 'package:hellchinza/inquiry/presentation/inquiry_state.dart';

class InquiryController extends StateNotifier<InquiryState> {
  InquiryController(this.ref) : super(const InquiryState());

  final Ref ref;

  Future<void> submit({required String message, XFile? image}) async {
    final uid = ref.read(inquiryUidProvider);
    if (uid == null) throw Exception('로그인 필요');

    state = state.copyWith(isSubmitting: true);

    try {
      await ref
          .read(inquiryRepoProvider)
          .createInquiry(uid: uid, message: message, image: image);
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}
