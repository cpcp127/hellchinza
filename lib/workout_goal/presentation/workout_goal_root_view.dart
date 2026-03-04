import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hellchinza/utils/date_time_util.dart';


import '../../common/common_feed_card.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../presentation/workout_goal_controller.dart';
import '../presentation/workout_goal_state.dart';
import '../provider/workout_goal_provider.dart'; // workoutGoalControllerProvider
import '../domain/week_oow_stat_model.dart';

class WorkoutGoalRootView extends ConsumerStatefulWidget {
  const WorkoutGoalRootView({super.key});

  @override
  ConsumerState<WorkoutGoalRootView> createState() => _WorkoutGoalRootViewState();
}

class _WorkoutGoalRootViewState extends ConsumerState<WorkoutGoalRootView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(workoutGoalControllerProvider.notifier);
      await controller.init();
      // ✅ 5주 차트 데이터도 같이 로드
      await controller.loadLast5Weeks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutGoalControllerProvider);
    final controller = ref.read(workoutGoalControllerProvider.notifier);

    final weekStart = DateTimeUtil.startOfWeekMonday(state.selectedDay);
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    final goal = state.goalPerWeek ?? 0;
    final done = state.doneDays;
    final progress = (goal <= 0) ? 0.0 : (done / goal).clamp(0.0, 1.0);

    final selectedKey = DateTimeUtil.dateKey(state.selectedDay);
    final selectedFeeds = state.weekMap[selectedKey] ?? const [];

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        color: AppColors.sky400,
        backgroundColor: AppColors.bgWhite,
        onRefresh: () async {
          await controller.refresh();
          await controller.loadLast5Weeks();
        },
        child: ListView(
          children: [
            const SizedBox(height: 12),

            // ✅ 이번주 목표(날짜 기준)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _WeeklyGoalCard(
                goal: goal,
                doneDays: done,
                progress: progress,
              ),
            ),
            const SizedBox(height: 12),

            // ✅ 달력(파란점 = 그날 오운완 존재)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _WeekCalendarRow(
                days: days,
                selectedDay: state.selectedDay,
                hasOowByDay: (day) =>
                (state.weekMap[DateTimeUtil.dateKey(day)]?.isNotEmpty ?? false),
                onTapDay: controller.selectDay,
              ),
            ),
            const SizedBox(height: 12),

            // ✅ 최근 5주 차트 섹션 (여기 추가)



            // ✅ 선택 날짜 피드 리스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${state.selectedDay.month}월 ${state.selectedDay.day}일 오운완',
                style: AppTextStyle.titleSmallBoldStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),
            ),
            const SizedBox(height: 10),

            if (selectedFeeds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EmptyDayBox(),
              )
            else
              ...selectedFeeds.map(
                    (f) => Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: FeedCard(feed: f),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Last5WeeksChartCard(
                weeks: state.last5Weeks,
                target: goal,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({
    required this.goal,
    required this.doneDays,
    required this.progress,
  });

  final int goal;
  final int doneDays;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('이번주 목표', style: AppTextStyle.titleSmallBoldStyle),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${doneDays}회',
                style: AppTextStyle.headlineSmallBoldStyle.copyWith(
                  color: AppColors.textDefault,
                ),
              ),
              Text(
                ' / ${goal}회',
                style: AppTextStyle.titleMediumStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                goal <= 0 ? '목표 없음' : '${(progress * 100).round()}%',
                style: AppTextStyle.labelMediumStyle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal <= 0 ? 0 : progress,
              minHeight: 10,
              backgroundColor: AppColors.bgSecondary,
              valueColor: const AlwaysStoppedAnimation(AppColors.sky400),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '※ 하루에 오운완을 여러 개 올려도, 그 날은 1회로만 계산돼요',
            style: AppTextStyle.labelSmallStyle.copyWith(
              color: AppColors.textTeritary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCalendarRow extends StatelessWidget {
  const _WeekCalendarRow({
    required this.days,
    required this.selectedDay,
    required this.hasOowByDay,
    required this.onTapDay,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final bool Function(DateTime day) hasOowByDay;
  final void Function(DateTime day) onTapDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: _DayCell(
                day: d,
                selected: _sameDay(d, selectedDay),
                hasOow: hasOowByDay(d),
                onTap: () => onTapDay(d),
              ),
            ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.hasOow,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool hasOow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.btnPrimary.withOpacity(0.12) : AppColors.bgSecondary;
    final border = selected ? AppColors.borderPrimary : AppColors.borderSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Text(
              _weekdayKor(day.weekday),
              style: AppTextStyle.labelSmallStyle.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '${day.day}',
              style: AppTextStyle.titleSmallBoldStyle.copyWith(color: AppColors.textDefault),
            ),
            const SizedBox(height: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasOow ? AppColors.sky400 : Colors.transparent,
                border: hasOow ? null : Border.all(color: AppColors.borderSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayKor(int w) {
    switch (w) {
      case DateTime.monday:
        return '월';
      case DateTime.tuesday:
        return '화';
      case DateTime.wednesday:
        return '수';
      case DateTime.thursday:
        return '목';
      case DateTime.friday:
        return '금';
      case DateTime.saturday:
        return '토';
      default:
        return '일';
    }
  }
}

class _Last5WeeksChartCard extends StatelessWidget {
  const _Last5WeeksChartCard({
    required this.weeks,
    required this.target,
  });

  final List<WeekOowStat> weeks;
  final int target;

  @override
  Widget build(BuildContext context) {
    final hasData = weeks.isNotEmpty && target > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('최근 5주 기록', style: AppTextStyle.titleSmallBoldStyle),
              const Spacer(),
              Text(
                target <= 0 ? '목표 없음' : '목표 ${target}회/주',
                style: AppTextStyle.labelSmallStyle.copyWith(
                  color: AppColors.textTeritary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!hasData)
            _Last5WeeksEmpty()
          else
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _calcMaxY(weeks, target),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.borderSecondary,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          // 0,1,2...만 표시
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              value.toInt().toString(),
                              style: AppTextStyle.labelXSmallStyle.copyWith(
                                color: AppColors.textTeritary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= weeks.length) return const SizedBox.shrink();
                          final w = weeks[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weekLabel(w.weekStartMonday),
                              style: AppTextStyle.labelXSmallStyle.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: target.toDouble(),
                        color: AppColors.borderPrimary,
                        strokeWidth: 1,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 4, bottom: 2),
                          style: AppTextStyle.labelXSmallStyle.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          labelResolver: (_) => '목표',
                        ),
                      ),
                    ],
                  ),
                  barGroups: List.generate(weeks.length, (i) {
                    final w = weeks[i];
                    final achieved = w.achieved;
                    final v = w.doneDays.toDouble();

                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: v,
                          width: 16,
                          borderRadius: BorderRadius.circular(6),
                          color: achieved
                              ? AppColors.sky400
                              : AppColors.gray200, // ✅ 목표 미달은 연하게
                        ),
                      ],
                    );
                  }),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.all(10),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final w = weeks[group.x.toInt()];
                        final text = '${_weekRangeText(w.weekStartMonday)}\n'
                            '${w.doneDays}일 운동'
                            '${w.achieved ? ' (달성)' : ' (미달)'}';
                        return BarTooltipItem(
                          text,
                          AppTextStyle.labelSmallStyle.copyWith(
                            color: AppColors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
          Text(
            '※ “오운완 피드가 1개라도 있던 날짜”를 1일로 계산해요',
            style: AppTextStyle.labelSmallStyle.copyWith(
              color: AppColors.textTeritary,
            ),
          ),
        ],
      ),
    );
  }

  double _calcMaxY(List<WeekOowStat> weeks, int target) {
    final maxDone = weeks.map((e) => e.doneDays).fold<int>(0, (p, c) => c > p ? c : p);
    final base = (maxDone > target ? maxDone : target);
    // 조금 여유
    return (base + 1).toDouble().clamp(3, 14);
  }

  String _weekLabel(DateTime mon) => '${mon.month}/${mon.day}';

  String _weekRangeText(DateTime mon) {
    final sun = mon.add(const Duration(days: 6));
    return '${mon.month}/${mon.day}~${sun.month}/${sun.day}';
  }
}

class _Last5WeeksEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            const Icon(Icons.insights, size: 34, color: AppColors.icDisabled),
            const SizedBox(height: 10),
            Text(
              '최근 5주 기록을 만들고 있어요',
              style: AppTextStyle.titleSmallBoldStyle.copyWith(
                color: AppColors.textDefault,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '오운완을 올리면 주간 기록이 여기에 표시돼요 🙂',
              textAlign: TextAlign.center,
              style: AppTextStyle.bodySmallStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDayBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      child: Column(
        children: [
          const Icon(Icons.fitness_center, size: 40, color: AppColors.icDisabled),
          const SizedBox(height: 10),
          Text(
            '이 날은 오운완이 없어요',
            style: AppTextStyle.titleSmallBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '오운완 피드를 올리면 여기에 표시돼요 🙂',
            style: AppTextStyle.bodySmallStyle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}