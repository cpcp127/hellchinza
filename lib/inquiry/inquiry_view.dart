import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/inquiry/write_inquiry_tab.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../services/dialog_service.dart';
import '../services/snackbar_service.dart';
import 'my_inquiry_tab.dart';

class InquiryView extends ConsumerStatefulWidget {
  const InquiryView({super.key});

  @override
  ConsumerState<InquiryView> createState() => _InquiryViewState();
}

class _InquiryViewState extends ConsumerState<InquiryView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: Text('문의하기', style: AppTextStyle.titleMediumBoldStyle),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.textDefault,
          unselectedLabelColor: AppColors.textTeritary,
          labelStyle: AppTextStyle.labelMediumStyle.copyWith(
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: AppTextStyle.labelMediumStyle,
          indicatorColor: AppColors.borderPrimary,
          tabs: const [
            Tab(text: '내 문의'),
            Tab(text: '문의 작성'),
          ],
        ),
      ),
      body: uid == null
          ? Center(
        child: Text(
          '로그인이 필요해요',
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      )
          : TabBarView(
        controller: _tabCtrl,
        children: [
          MyInquiryTab(uid: uid),
          // uid != null 가정
          WriteInquiryTab(
            uid: uid,
            controller: _msgCtrl,
            onSubmitted: () {
              // ✅ 제출 후 "내 문의" 탭으로 이동
              _tabCtrl.animateTo(0);
            },
          ),
        ],
      ),
    );
  }
}