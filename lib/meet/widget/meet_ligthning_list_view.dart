import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../services/snackbar_service.dart';
import '../domain/lightning_model.dart';
import '../lightning_create/lightning_create_view.dart';
import 'lightning_card.dart';

class MeetLightningListView extends StatelessWidget {
  const MeetLightningListView({super.key, required this.meetId});
  final String meetId;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('meets')
        .doc(meetId)
        .collection('lightnings')
        .where('status', isEqualTo: 'open')
        .orderBy('dateTime', descending: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('번개 전체보기', style: AppTextStyle.titleMediumBoldStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.icDefault),
            onPressed: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => LightningCreateView(meetId: meetId),
                ),
              );
              // isLive=true면 자동 반영
            },
          ),
        ],
      ),
      body: FirestorePagination(
        query: query,
        limit: 10,
        isLive: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

        // ✅ 패키지에 따라 docs(List)로 들어오는 케이스가 있어서 안전하게 처리
        itemBuilder: (context, docs, index) {
          // docs가 단일 doc이면 아래 두 줄이 필요 없고 doc으로 바로 쓰면 됨
          final list = docs as List<DocumentSnapshot<Object?>>;
          final d = list[index] as DocumentSnapshot<Map<String, dynamic>>;

          final model = LightningModel.fromDoc(d);

          final now = DateTime.now();
          if (model.dateTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LightningCard(
              meetId: meetId,
              model: model,
              isMeetMember: true, // ✅ rules에서 이미 보장됨
            ),
          );
        },

        // ✅ 권한 없으면 여기서 에러 처리 (패키지에 onError가 있으면 쓰고, 없으면 itemBuilder 이전에 잡히는 방식일 수 있음)
      ),
    );
  }
}
