import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_network_image.dart';
import 'package:hellchinza/meet/domain/meet_model.dart';
import 'package:hellchinza/meet/meet_create/meet_create_view.dart' hide workList;
import 'package:hellchinza/meet/meet_detail/meat_detail_view.dart';
import 'package:hellchinza/meet/widget/empty_meet_list.dart';
import 'package:hellchinza/meet/widget/meet_card.dart';

import '../../common/common_chip.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_style.dart';
import 'meet_list_controller.dart';
import '../domain/meet_summary_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class MeetListView extends ConsumerStatefulWidget {
  const MeetListView({super.key});

  @override
  ConsumerState<MeetListView> createState() => _MeetListViewState();
}

class _MeetListViewState extends ConsumerState<MeetListView> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.read(meetListControllerProvider.notifier);
    final state = ref.watch(meetListControllerProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Container(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: workList.length + 1, // ⭐ +1
              itemBuilder: (context, index) {
                final String label = index == 0 ? '전체' : workList[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: CommonChip(
                    label: label,
                    selected: label == state.selectSubType,
                    onTap: () {
                      controller.onChangeSubType(label);
                    },
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: FirestorePagination(
            key: ValueKey(state.selectSubType),
            // ✅ 핵심: 페이징은 패키지가 처리
            query: controller.buildQuery(),
            limit: 12,
            isLive: false,
            // 새 모임 생기면 자동 반영(원하면 false)
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),

            // 처음 로딩
            initialLoader: const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: CircularProgressIndicator(),
              ),
            ),

            // 더 불러오는 로딩
            bottomLoader: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator()),
            ),

            // 데이터가 없을 때
            onEmpty: EmptyMeetList(
              onTapCreate: () {

                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    fullscreenDialog: true,
                    builder: (context) {
                      return MeetCreateStepperView();
                    },
                  ),
                );
              },
            ),

            itemBuilder: (context, docSnapshots, index) {
              final doc =
                  docSnapshots[index] as DocumentSnapshot<Map<String, dynamic>>;
              final item = MeetModel.fromDoc(doc);

              return MeetCard(
                item: item,
                onTap: () {
                  // TODO: MeetDetailView로 이동(item.id)
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      fullscreenDialog: true,
                      builder: (context) {
                        return MeetDetailView(meetId: item.id);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}


