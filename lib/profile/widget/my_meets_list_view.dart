import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../meet/meet_detail/meat_detail_view.dart';
import '../../meet/domain/meet_model.dart';
import '../../meet/domain/meet_summary_model.dart';
import '../../meet/widget/meet_card.dart';

class MyMeetsListView extends StatelessWidget {
  const MyMeetsListView({super.key, required this.title, required this.query});
  final String title;
  final Query<Map<String, dynamic>> query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: Text(title, style: AppTextStyle.titleMediumBoldStyle),
        backgroundColor: AppColors.bgWhite,
      ),
      body: FirestorePagination(
        query: query,
        limit: 10,
        onEmpty: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_rounded,
                size: 42,
                color: AppColors.icDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                '아직 모임이 없어요',
                style: AppTextStyle.titleSmallBoldStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '운동친구를 만나는 첫 모임에 참가,생성 해볼까요?',
                textAlign: TextAlign.center,
                style: AppTextStyle.bodySmallStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        itemBuilder: (context, docSnapshots, index) {
          final doc =
          docSnapshots[index] as DocumentSnapshot<Map<String, dynamic>>;
          final item = MeetModel.fromDoc(doc);

          return Padding(
            padding: const EdgeInsets.only(left: 16,right: 16,bottom: 12),
            child: MeetCard(
              item: item,
              onTap: () {

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
            ),
          );
        },
      ),
    );
  }
}
