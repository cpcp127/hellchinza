import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_text_style.dart';
import 'package:hellchinza/inquiry/presentation/tabs/my_inquiry_tab.dart';
import 'package:hellchinza/inquiry/presentation/tabs/write_inquiry_tab.dart';
import 'package:hellchinza/inquiry/providers/inquiry_provider.dart';

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
    final uid = ref.watch(inquiryUidProvider);

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
                WriteInquiryTab(
                  controller: _msgCtrl,
                  onSubmitted: () {
                    _tabCtrl.animateTo(0);
                  },
                ),
              ],
            ),
    );
  }
}
