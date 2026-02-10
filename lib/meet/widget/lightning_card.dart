import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../services/snackbar_service.dart';
import '../domain/lightning_model.dart';
import 'lightning_member_mini_row.dart';

class LightningCard extends StatelessWidget {
  const LightningCard({
    required this.meetId,
    required this.isMeetMember,
    required this.model,
  });

  final String meetId;
  final LightningModel model;
  final bool isMeetMember; // ✅ 추가
  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = myUid != null && model.authorUid == myUid;
    final isMember = myUid != null && model.memberUids.contains(myUid);
    final isFull = model.isFull;
    final isJoined = myUid != null && model.memberUids.contains(myUid);
    final canJoin = myUid != null && !isOwner && !isMember && !isFull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSecondary),
                ),
                child: const Icon(
                  Icons.flash_on_outlined,
                  color: AppColors.icPrimary,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.title, style: AppTextStyle.titleSmallBoldStyle),
                    const SizedBox(height: 4),
                    Text(
                      '${model.category} · ${_formatMmDdHm(model.dateTime)}',
                      style: AppTextStyle.bodySmallStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${model.currentMemberCount}/${model.maxMembers}',
                style: AppTextStyle.labelMediumStyle.copyWith(
                  color: AppColors.textDefault,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 장소 요약(있으면)
          if (model.place != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.icSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (model.place!['title'] ?? model.place!['address'] ?? '')
                        .toString(),
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // 참가자 간단 표시
          LightningMemberMiniRow(memberUids: model.memberUids),

          const SizedBox(height: 12),

          // 참가 버튼
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: canJoin
                  ? () async {
                if (!isMeetMember) {
                  SnackbarService.show(
                    type: AppSnackType.error,
                    message: '모임에 먼저 참가해야 해요',
                  );
                  return;
                }
                try {
                  if (isJoined) {
                    await _leaveLightning(model: model);
                    SnackbarService.show(
                      type: AppSnackType.success,
                      message: '번개 참가를 취소했어요',
                    );
                  } else {
                    await _joinLightning(model: model);
                    SnackbarService.show(
                      type: AppSnackType.success,
                      message: '번개에 참가했어요',
                    );
                  }
                } catch (e) {
                  SnackbarService.show(
                    type: AppSnackType.error,
                    message: e.toString().replaceAll('Exception: ', ''),
                  );
                }
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.btnPrimary,
                disabledBackgroundColor: AppColors.btnDisabled,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isOwner
                    ? '내가 만든 번개'
                    : isMember
                    ? '참가중'
                    : isFull
                    ? '마감'
                    : '참가하기',
                style: AppTextStyle.labelLargeStyle.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMmDdHm(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}월 ${dt.day}일 $hh:$mm';
  }

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance
          .collection('meets')
          .doc(meetId)
          .collection('lightnings')
          .doc(model.id);

  Future<void> _joinLightning({required LightningModel model}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_ref);
      final data = snap.data() ?? {};

      final current = (data['currentMemberCount'] as num?)?.toInt() ?? 0;
      final max = (data['maxMembers']);
      final memberUids = List<String>.from(data['memberUids'] ?? const []);

      if (memberUids.contains(uid)) return;
      if (current >= max) throw Exception('정원이 마감되었습니다');

      memberUids.add(uid);

      tx.update(_ref, {
        'memberUids': memberUids,
        'currentMemberCount': current + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }


  Future<void> _leaveLightning({required LightningModel model}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    // 호스트는 번개에서 나가면 애매하니(원하면 허용 가능) 막아두자
    if (model.authorUid == uid) throw Exception('호스트는 나갈 수 없어요');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_ref);
      final data = snap.data() ?? {};

      final current = (data['currentMemberCount'] as num?)?.toInt() ?? 0;
      final memberUids = List<String>.from(data['memberUids'] ?? const []);

      if (!memberUids.contains(uid)) return;

      memberUids.remove(uid);

      final nextCount = (current - 1) < 0 ? 0 : (current - 1);

      tx.update(_ref, {
        'memberUids': memberUids,
        'currentMemberCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}