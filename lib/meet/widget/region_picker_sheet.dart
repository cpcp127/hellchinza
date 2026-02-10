import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../common/common_text_field.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../domain/meet_region.dart';



Future<MeetRegion?> showRegionPickerBottomSheet(BuildContext context) {
  return showModalBottomSheet<MeetRegion>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RegionPickerSheet(),
  );
}

class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet();

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  final _ctrl = TextEditingController();
  String keyword = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _query() {
    final base = FirebaseFirestore.instance.collection('admin_areas');

    final k = keyword.trim();
    if (k.isEmpty) {
      // 처음엔 너무 많이 뜨면 불편하니 안내만 보여주거나,
      // 인기지역 top 같은 걸 띄워도 됨. 일단 20개만.
      return base.orderBy('fullName').limit(20);
    }

    // ✅ searchTokens는 "정확 매칭"이라, 입력값을 토큰화해서 마지막 단어만 쓰는게 UX 좋아
    final token = _lastToken(k);

    return base
        .where('searchTokens', arrayContains: token)
        .orderBy('fullName')
        .limit(30);
  }

  String _lastToken(String input) {
    final t = input.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return t.isEmpty ? input.trim() : t.last;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 80),
        decoration: const BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CommonTextField(
                controller: _ctrl,
                hintText: '동/읍/면 검색 (예: 반포동, 서초, 잠실)',
                onChanged: (v) => setState(() => keyword = v),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _query().snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];
                  if (keyword.trim().isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          '검색어를 입력하면 동/읍/면 목록이 표시돼요.',
                          textAlign: TextAlign.center,
                          style: AppTextStyle.bodyMediumStyle.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        '검색 결과가 없어요',
                        style: AppTextStyle.bodyMediumStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final region = MeetRegion.fromJson(d.data());

                      return InkWell(
                        onTap: () => Navigator.pop(context, region),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 18, color: AppColors.icSecondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  region.fullName,
                                  style: AppTextStyle.bodyMediumStyle.copyWith(
                                    color: AppColors.textDefault,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.icDisabled),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
