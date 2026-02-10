import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../common/common_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../services/snackbar_service.dart';

class ManageRequestsSheet extends StatelessWidget {
  const ManageRequestsSheet({
    super.key,
    required this.meetId,
    required this.onChanged,
  });

  final String meetId;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
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

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: reqQuery.snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          '대기 중인 요청이 없어요',
                          style: AppTextStyle.bodyMediumStyle.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final uid = (docs[i].data()['uid'] ?? docs[i].id)
                            .toString();

                        return _RequestRow(
                          meetId: meetId,
                          uid: uid,
                          onChanged: onChanged,
                        );
                      },
                    );
                  },
                ),
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final nickname = (data?['nickname'] ?? '사용자') as String;
        final photoUrl = data?['photoUrl'] as String?;

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
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person, color: AppColors.icDisabled)
                    : CommonNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover),
              ),
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
