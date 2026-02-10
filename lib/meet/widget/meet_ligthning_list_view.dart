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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final meetRef = FirebaseFirestore.instance.collection('meets').doc(meetId);

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('번개 전체보기', style: AppTextStyle.titleMediumBoldStyle),
        ),
        body: Center(
          child: Text(
            '로그인이 필요합니다',
            style: AppTextStyle.bodyMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: meetRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text('번개 전체보기', style: AppTextStyle.titleMediumBoldStyle),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text('번개 전체보기', style: AppTextStyle.titleMediumBoldStyle),
            ),
            body: Center(
              child: Text(
                '모임이 없어요',
                style: AppTextStyle.bodyMediumStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        final memberUids = List<String>.from(data['memberUids'] ?? const []);
        final isMeetMember = memberUids.contains(uid);

        if (!isMeetMember) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SnackbarService.show(
              type: AppSnackType.error,
              message: '모임에 먼저 참가해야 볼 수 있어요',
            );
            Navigator.pop(context);
          });
          return const SizedBox.shrink();
        }

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
                  // stream/pagination이라 새 번개가 dateTime 정렬 범위 안이면 자동으로 보이게 됨
                },
              ),
            ],
          ),
          body: FirestorePagination(
            query: query,
            limit: 10,
            // ✅ 번개 리스트는 key로 리셋할 일 거의 없음 (당겨서 새로고침은 아래 확장 가능)
            // key: ValueKey('lightnings_$meetId'),
            isLive: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemBuilder: (context, doc, index) {
              final model = LightningModel.fromDoc(
                doc as DocumentSnapshot<Map<String, dynamic>>,
              );

              // ✅ 과거 번개 제외하고 싶으면 여기서 필터(빈 위젯 반환)
              final now = DateTime.now();
              if (model.dateTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LightningCard(
                  meetId: meetId,
                  model: model,
                  isMeetMember: true, // 이미 멤버 체크 통과
                ),
              );
            },
          ),
        );
      },
    );
  }
}
