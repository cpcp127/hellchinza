import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hellchinza/oow_step/presentation/widget/oow_day_feed_step_card.dart';
import 'package:hellchinza/oow_step/presentation/widget/oow_goal_step_card.dart';
import 'package:hellchinza/oow_step/presentation/widget/oow_last5weeks_step_card.dart';
import 'package:hellchinza/oow_step/presentation/widget/oow_today_cert_step_card.dart';
import 'package:hellchinza/oow_step/presentation/widget/oow_top_workout_step_card.dart';

import '../../../../constants/app_colors.dart';
import '../../../../constants/app_text_style.dart';
import '../providers/oow_provider.dart';
import 'oow_step_controller.dart';

class OowStepView extends ConsumerStatefulWidget {
  const OowStepView({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<OowStepView> createState() => _OowStepViewState();
}

class _OowStepViewState extends ConsumerState<OowStepView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(oowStepControllerProvider(widget.uid).notifier).init();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(oowStepControllerProvider(widget.uid));
    final controller = ref.read(oowStepControllerProvider(widget.uid).notifier);
    ref.listen<int>(oowRefreshTickProvider(widget.uid), (previous, next) {
      if (previous == null) return;
      if (previous != next) {
        ref.read(oowStepControllerProvider(widget.uid).notifier).refresh();
      }
    });
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: widget.uid == FirebaseAuth.instance.currentUser!.uid
          ? null
          : AppBar(title: Text('오운완')),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: Column(
          children: [
            const SizedBox(height: 20),
            _PageIndicator(currentIndex: state.currentPage, count: 5),
            const SizedBox(height: 16),
            Expanded(
              child: state.isLoading
                  ? const _LoadingBody()
                  : state.errorMessage != null
                  ? _ErrorBody(onRetry: controller.refresh)
                  : PageView(
                      controller: _pageController,
                      onPageChanged: controller.changePage,
                      children: [
                        OowTodayCertStepPage(uid: widget.uid),
                        OowGoalStepPage(uid: widget.uid),
                        OowDayFeedStepPage(uid: widget.uid),
                        OowLast5WeeksStepPage(uid: widget.uid),
                        OowTopWorkoutStepPage(uid: widget.uid),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.currentIndex, required this.count});

  final int currentIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isSelected = currentIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isSelected ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.btnPrimary
                : AppColors.borderSecondary,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('오운완 데이터를 불러오지 못했어요', style: AppTextStyle.titleSmallBoldStyle),
            const SizedBox(height: 8),
            Text(
              '잠시 후 다시 시도해주세요',
              style: AppTextStyle.bodyMediumStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                '다시 시도',
                style: AppTextStyle.labelMediumStyle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
