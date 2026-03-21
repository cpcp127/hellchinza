import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/common_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';
import '../../meet/domain/meet_model.dart';
import '../meet_detail/meat_detail_view.dart';
import '../meet_list/meet_list_view.dart';
import 'meet_home_controller.dart';
import 'meet_home_state.dart';

final meetMemberCountProvider = FutureProvider.family<int, String>((
  ref,
  meetId,
) async {
  final snap = await FirebaseFirestore.instance
      .collection('meets')
      .doc(meetId)
      .collection('members')
      .count()
      .get();

  return snap.count ?? 0;
});

class MeetHomeView extends ConsumerStatefulWidget {
  const MeetHomeView({super.key});

  @override
  ConsumerState<MeetHomeView> createState() => _MeetHomeViewState();
}

class _MeetHomeViewState extends ConsumerState<MeetHomeView> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(meetHomeControllerProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meetHomeControllerProvider);
    final controller = ref.read(meetHomeControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          color: AppColors.sky400,
          onRefresh: controller.refresh,
          child: state.isLoading && state.heroItems.isEmpty
              ? const Center(child: CircularProgressIndicator.adaptive())
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // SliverToBoxAdapter(
                    //   child: Padding(
                    //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    //     child: _HomeHeader(
                    //       onTapAll: () {
                    //         // 전체보기 페이지로 push
                    //       },
                    //     ),
                    //   ),
                    // ),
                    const SliverToBoxAdapter(child: SizedBox(height: 18)),

                    if (state.heroItems.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _MeetHeroSection(items: state.heroItems),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 28)),

                    _SectionBlock(
                      title: '방금 활동한 모임',
                      subTitle: '최근 채팅이 오간 살아있는 모임',
                      items: state.recentActiveMeets,
                    ),
                    _SectionBlock(
                      title: '인원이 많은 모임',
                      subTitle: '사람들이 많이 모이는 인기 모임',
                      items: state.popularMeets,
                    ),
                    _SectionBlock(
                      title: '최근 생성된 모임',
                      subTitle: '새로 올라온 모임을 빠르게 확인',
                      items: state.newestMeets,
                    ),
                    _SectionBlock(
                      title: '내 관심사 모임',
                      subTitle: '내 운동 카테고리에 맞춘 추천',
                      items: state.interestMeets,
                    ),
                    _SectionBlock(
                      title: '번개 활발한 모임',
                      subTitle: '최근 번개가 자주 열리는 모임',
                      items: state.lightningHotMeets,
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    if (state.errorMessage != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            state.errorMessage!,
                            style: AppTextStyle.bodyMediumStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: _BrowseAllMeetButton(
                          onTap: (){
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => const MeetListView(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
        ),
      ),
    );
  }
}


class _MeetHeroSection extends StatefulWidget {
  const _MeetHeroSection({required this.items});

  final List<MeetHeroItem> items;

  @override
  State<_MeetHeroSection> createState() => _MeetHeroSectionState();
}

class _MeetHeroSectionState extends State<_MeetHeroSection> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 520,
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          double page = 0;
          if (_pageController.hasClients) {
            page =
                _pageController.page ?? _pageController.initialPage.toDouble();
          }

          return Column(
            children: [
              SizedBox(
                height: 470,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final offset = page - index;

                    return _MeetHeroCard(
                      item: item,
                      offset: offset,
                      onTapDetail: () {
                        final meet = item.meet;


                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => MeetDetailView(
                              meetId: meet.id,

                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _HeroDots(count: widget.items.length, page: page),
            ],
          );
        },
      ),
    );
  }
}

class _MeetHeroCard extends ConsumerWidget {
  const _MeetHeroCard({
    required this.item,
    required this.offset,
    required this.onTapDetail,
  });

  final MeetHeroItem item;
  final double offset;
  final VoidCallback onTapDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meet = item.meet;
    final heroTag = 'meet_home_hero_${meet.id}';
    final imageUrl = meet.imageUrls.isNotEmpty ? meet.imageUrls.first : '';
    final imageTranslate = offset * -32;
    final contentTranslate = offset * 18;
    final scale = (1 - (offset.abs() * 0.06)).clamp(0.92, 1.0);
    final countAsync = ref.watch(meetMemberCountProvider(meet.id));

    return Transform.scale(
      scale: scale,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                Transform.translate(
                  offset: Offset(imageTranslate, 0),
                  child: Hero(
                    tag: heroTag,
                    child: CommonNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(color: AppColors.bgSecondary),

              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x22000000),
                      Color(0x44000000),
                      Color(0xCC000000),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: 20,
                left: 20,
                child: _HeroBadge(text: item.badge),
              ),

              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: countAsync.when(
                    data: (count) {
                      return Text(
                        '$count/${meet.maxMembers}',
                        style: AppTextStyle.labelSmallStyle.copyWith(
                          color: AppColors.white,
                        ),
                      );
                    },
                    loading: () => Text(
                      '?/${meet.maxMembers}',
                      style: AppTextStyle.labelSmallStyle.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    error: (_, __) => Text(
                      '?/${meet.maxMembers}',
                      style: AppTextStyle.labelSmallStyle.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 24 + contentTranslate,
                right: 24,
                bottom: 24,
                child: _HeroContent(meet: meet, onTapDetail: onTapDetail),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroContent extends ConsumerWidget {
  const _HeroContent({required this.meet, required this.onTapDetail});

  final MeetModel meet;
  final VoidCallback onTapDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionText = meet.regions.isNotEmpty
        ? meet.regions.first.fullName
        : '지역 미정';
    final countAsync = ref.watch(meetMemberCountProvider(meet.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          meet.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.headlineMediumBoldStyle.copyWith(
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          meet.intro,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.bodyMediumStyle.copyWith(
            color: AppColors.white.withOpacity(0.82),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaChip(icon: CupertinoIcons.location_solid, label: regionText),
            countAsync.when(
              data: (count) {
                return _MetaChip(
                  icon: CupertinoIcons.person_2_fill,
                  label: '$count명 참여중',
                );
              },
              loading: () => const _MetaChip(
                icon: CupertinoIcons.person_2_fill,
                label: '?명 참여중',
              ),
              error: (_, __) => const _MetaChip(
                icon: CupertinoIcons.person_2_fill,
                label: '?명 참여중',
              ),
            ),
            _MetaChip(icon: CupertinoIcons.tag_fill, label: meet.category),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTapDetail,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '상세 보기',
                        style: AppTextStyle.titleSmallBoldStyle.copyWith(
                          color: AppColors.textDefault,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // const SizedBox(width: 10),
            // Container(
            //   width: 48,
            //   height: 48,
            //   decoration: BoxDecoration(
            //     color: Colors.white.withOpacity(0.16),
            //     borderRadius: BorderRadius.circular(16),
            //     border: Border.all(color: Colors.white.withOpacity(0.18)),
            //   ),
            //   child: const Icon(CupertinoIcons.heart, color: AppColors.white),
            // ),
          ],
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.sky400.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyle.labelMediumStyle.copyWith(color: AppColors.white),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyle.labelSmallStyle.copyWith(
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final diff = (page - index).abs();
        final selectedness = (1 - diff).clamp(0.0, 1.0);
        final width = lerpDouble(8, 22, selectedness)!;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: width,
          height: 8,
          decoration: BoxDecoration(
            color: selectedness > 0.5 ? AppColors.sky400 : AppColors.gray200,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.subTitle,
    required this.items,
  });

  final String title;
  final String subTitle;
  final List<MeetModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyle.titleMediumBoldStyle.copyWith(
                      color: AppColors.textDefault,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subTitle,
                    style: AppTextStyle.bodySmallStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 230,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _MeetMiniCard(meet: items[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetMiniCard extends ConsumerWidget {
  const _MeetMiniCard({required this.meet});

  final MeetModel meet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(meetMemberCountProvider(meet.id));

    final imageUrl = meet.imageUrls.isNotEmpty ? meet.imageUrls.first : '';

    final regionText = meet.regions.isNotEmpty
        ? meet.regions.first.fullName
        : '지역 미정';

    return GestureDetector(
      onTap: () {
        // 상세 이동
        Navigator.push(
          context,
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => MeetDetailView(meetId: meet.id),
          ),
        );
      },
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderSecondary),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 132,
              width: double.infinity,
              child: imageUrl.isNotEmpty
                  ? CommonNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,enableViewer: false,)
                  : Container(color: AppColors.bgSecondary),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meet.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.titleSmallBoldStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meet.intro,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.bodySmallStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.location_solid,
                          size: 14,
                          color: AppColors.icSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            regionText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.person_2_fill,
                          size: 14,
                          color: AppColors.icSecondary,
                        ),
                        const SizedBox(width: 4),
                        countAsync.when(
                          data: (count) {
                            return Text(
                              '$count',
                              style: AppTextStyle.labelSmallStyle.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                          loading: () => Text(
                            '0',
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          error: (_, __) => Text(
                            '0',
                            style: AppTextStyle.labelSmallStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _BrowseAllMeetButton extends StatelessWidget {
  const _BrowseAllMeetButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSecondary),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  CupertinoIcons.square_grid_2x2,
                  size: 20,
                  color: AppColors.icDefault,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '전체 모임 둘러보기',
                      style: AppTextStyle.titleSmallBoldStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '추천 말고 모든 모임을 리스트로 볼 수 있어요',
                      style: AppTextStyle.bodySmallStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: AppColors.icSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}