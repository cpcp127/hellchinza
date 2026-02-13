import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hellchinza/common/common_profile_avatar.dart';

import '../../common/common_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

class LightningMemberMiniRow extends StatefulWidget {
  const LightningMemberMiniRow({super.key, required this.memberUids});

  final List<String> memberUids;

  @override
  State<LightningMemberMiniRow> createState() => _LightningMemberMiniRowState();
}

class _LightningMemberMiniRowState extends State<LightningMemberMiniRow> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant LightningMemberMiniRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // memberUids가 바뀌면 다시 로드
    if (!_listEquals(oldWidget.memberUids, widget.memberUids)) {
      _future = _load();
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final uids = widget.memberUids.take(3).toList();
    if (uids.isEmpty) return const [];

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', whereIn: uids)
        .get();

    // whereIn은 순서 보장 X → uid 기준으로 다시 정렬
    final map = <String, Map<String, dynamic>>{};
    for (final d in snap.docs) {
      final data = d.data();
      final uid = (data['uid'] ?? d.id).toString();
      map[uid] = data;
    }

    return uids
        .map((uid) => map[uid])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final uids = widget.memberUids.take(3).toList();
    if (uids.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Row(
            children: List.generate(uids.length, (_) => _CircleSkeleton()),
          );
        }

        final users = snap.data!;

        return Row(
          children: [
            ...users.map((u) {
              final photoUrl = u['photoUrl']?.toString();
              // 닉네임은 지금 UI에 안 쓰고 있으니 그대로 둠
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CommonProfileAvatar(imageUrl: photoUrl, size: 22,uid: u['uid'],gender: u['gender'],),
              );
            }),
            if (widget.memberUids.length > 3)
              Text(
                '+${widget.memberUids.length - 3}',
                style: AppTextStyle.labelSmallStyle.copyWith(
                  color: AppColors.textTeritary,
                ),
              ),
          ],
        );
      },
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}


class _CircleSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppColors.gray100,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
