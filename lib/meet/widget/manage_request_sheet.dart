import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/auth/domain/user_mini_provider.dart';

import '../../common/common_network_image.dart';
import '../../common/common_profile_avatar.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../services/snackbar_service.dart';

final meetRequestUidsProvider = FutureProvider.family<List<String>, String>((
  ref,
  meetId,
) async {
  final snap = await FirebaseFirestore.instance
      .collection('meets')
      .doc(meetId)
      .collection('requests')
      // 네가 pending만 보고 있으면 유지
      .where('status', isEqualTo: 'pending')
      .get();

  // 보통 요청 문서 id == uid
  return snap.docs.map((d) => d.id).toList();
});

class ManageRequestsSheet extends ConsumerWidget {
  const ManageRequestsSheet({
    super.key,
    required this.meetId,
    required this.onChanged,
  });

  final String meetId;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqAsync = ref.watch(meetRequestUidsProvider(meetId));
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        final reqQuery = FirebaseFirestore.instance
            .collection('meets')
            .doc(meetId)
            .collection('requests')
            .orderBy('createdAt', descending: true);

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '참가 요청 관리',
                      style: AppTextStyle.titleMediumBoldStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.icDefault),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),
              reqAsync.when(
                loading: () {
                  // ✅ 너 원래 로딩 UI 그대로 넣어
                  return const Center(child: CupertinoActivityIndicator());
                },
                error: (e, _) {
                  // ✅ 너 원래 에러 UI 그대로 넣어
                  return Center(child: Text('요청 불러오기 실패: $e'));
                },
                data: (uids) {
                  // ✅ 여기부터는 "기존 builder에서 snap.data!.docs" 대신 uids를 쓰면 됨
                  if (uids.isEmpty) {
                    // ✅ 기존 empty UI 그대로
                    return Text(
                      '대기 중인 요청이 없어요',
                      style: AppTextStyle.bodyMediumStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    );
                  }

                  // ✅ 기존 ListView/Column 등 구조 그대로 유지
                  return Expanded(
                    child: ListView.builder(
                      itemCount: uids.length,
                      itemBuilder: (context, index) {
                        final uid = uids[index];

                        return _RequestRow(
                          meetId: meetId,
                          uid: uid,
                          onChanged: onChanged,
                        );
                      },
                    ),
                  );
                },
              ),

            ],
          ),
        );
      },
    );
  }
}

class _RequestRow extends StatefulWidget {
  const _RequestRow({
    required this.meetId,
    required this.uid,
    required this.onChanged,
  });

  final String meetId;
  final String uid;
  final Future<void> Function() onChanged;

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _busy = false;

  DocumentReference<Map<String, dynamic>> get _meetRef =>
      FirebaseFirestore.instance.collection('meets').doc(widget.meetId);

  Future<void> _approve() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final reqRef = _meetRef.collection('requests').doc(widget.uid);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final meetSnap = await tx.get(_meetRef);
        final data = meetSnap.data()!;
        final current = (data['currentMemberCount'] ?? 0) as int;
        final max = (data['maxMembers'] ?? 0) as int;
        final members = List<String>.from(data['memberUids'] ?? []);

        if (members.contains(widget.uid)) {
          tx.delete(reqRef);
          return;
        }
        if (current >= max) throw Exception('정원이 마감되었습니다');

        members.add(widget.uid);

        tx.update(_meetRef, {
          'memberUids': members,
          'currentMemberCount': current + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.delete(reqRef);
      });

      SnackbarService.show(type: AppSnackType.success, message: '승인했어요');
      await widget.onChanged(); // ✅ 부모 init 호출
    } catch (e) {
      SnackbarService.show(type: AppSnackType.error, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _meetRef.collection('requests').doc(widget.uid).delete();
      SnackbarService.show(type: AppSnackType.success, message: '거절했어요');
      await widget.onChanged(); // ✅ 부모 init 호출
    } catch (e) {
      SnackbarService.show(type: AppSnackType.error, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid);

    return Consumer(
      builder: (context, ref, _) {
        final userAsync = ref.watch(userMiniProvider(widget.uid));

        return userAsync.when(
          loading: () {
            // ✅ 기존 UI 구조 유지: 로딩 시에도 동일한 row 스켈레톤 느낌으로
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSecondary),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderSecondary),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const Icon(Icons.person, color: AppColors.icDisabled),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '불러오는 중…',
                      style: AppTextStyle.titleSmallBoldStyle.copyWith(
                        color: AppColors.textTeritary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SmallOutlineButton(text: '거절', onTap: null),
                  const SizedBox(width: 8),
                  _SmallPrimaryButton(text: '승인', onTap: null),
                ],
              ),
            );
          },
          error: (e, _) {
            // ✅ 에러 시에도 기존 구조 유지
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSecondary),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderSecondary),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const Icon(Icons.person, color: AppColors.icDisabled),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '사용자 정보를 불러오지 못했어요',
                      style: AppTextStyle.titleSmallBoldStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),
                  ),

                ],
              ),
            );
          },
          data: (mini) {
            final nickname = mini?.nickname.isNotEmpty == true
                ? mini!.nickname
                : '';
            final photoUrl = mini?.photoUrl;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSecondary),
              ),
              child: Row(
                children: [
                  CommonProfileAvatar(imageUrl: photoUrl, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nickname,
                      style: AppTextStyle.titleSmallBoldStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SmallOutlineButton(text: '거절', onTap: _busy ? null : _reject),
                  const SizedBox(width: 8),
                  _SmallPrimaryButton(
                    text: _busy ? '처리중' : '승인',
                    onTap: _busy ? null : _approve,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

  }
}

class _SmallPrimaryButton extends StatelessWidget {
  const _SmallPrimaryButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.btnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.labelMediumStyle.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}

class _SmallOutlineButton extends StatelessWidget {
  const _SmallOutlineButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: AppColors.borderSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.labelMediumStyle.copyWith(
            color: AppColors.textDefault,
          ),
        ),
      ),
    );
  }
}
