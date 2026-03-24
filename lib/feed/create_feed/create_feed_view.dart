import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_fade_widget.dart';
import 'package:hellchinza/feed/create_feed/create_feed_controller.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/common_back_appbar.dart';
import '../../common/common_chip.dart';
import '../../common/common_location_serach_view.dart';
import '../../common/common_network_image.dart';
import '../../common/common_poll_builder.dart';
import '../../common/common_text_field.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_style.dart';
import '../domain/feed_model.dart' hide FeedMainType;
import '../domain/feed_place.dart';
import '../providers/feed_provider.dart';
import 'create_feed_state.dart';

class CreateFeedView extends ConsumerStatefulWidget {
  const CreateFeedView({
    super.key,
    this.mode = 'create',
    this.feed,
    this.meetId,
    this.isOowEntry = false,
  });

  final String mode;
  final FeedModel? feed;
  final String? meetId;
  final bool isOowEntry;

  @override
  ConsumerState<CreateFeedView> createState() => _CreateFeedViewState();
}

class _CreateFeedViewState extends ConsumerState<CreateFeedView> {
  final PageController pageController = PageController();
  final TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.mode == 'update' && widget.feed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(createFeedControllerProvider.notifier)
            .initForEdit(widget.feed!);
        textEditingController.text = widget.feed!.contents ?? '';
      });
    }
    // ✅ 오운완 진입 시
    if (widget.isOowEntry && widget.mode == 'create') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(createFeedControllerProvider.notifier).initForOowEntry();
      });
    }

  }

  @override
  void dispose() {
    pageController.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createFeedControllerProvider);
    final controller = ref.read(createFeedControllerProvider.notifier);

    final hasImage =
        state.existingImageUrls.isNotEmpty || state.newImageFiles.isNotEmpty;
    final hasText = state.contents.trim().isNotEmpty;
    final isOow = state.selectMainType == '오운완';

    final isSubmitEnabled = isOow
        ? (hasImage && hasText)
        : (hasImage || hasText);

    final hasMainType =
        state.selectMainType != null && state.selectMainType!.isNotEmpty;
    final hasSubType =
        state.selectSubType != null && state.selectSubType!.isNotEmpty;

    final isCreate = widget.mode == 'create';
    final showEmptyImage =
        state.existingImageUrls.isEmpty && state.newImageFiles.isEmpty;

    final canGoNext = switch (state.pageIndex) {
      0 => hasMainType,
      1 => hasSubType,
      _ => false,
    };

    return Scaffold(
      appBar: _buildAppBar(
        context: context,
        state: state,
        controller: controller,
        canGoNext: canGoNext,
        isSubmitEnabled: isSubmitEnabled,
        isCreate: isCreate,
      ),
      body: SafeArea(
        child: state.pageIndex == 2
            ? SingleChildScrollView(
                child: CommonFadeWidget(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '사진',
                              style: AppTextStyle.titleSmallBoldStyle.copyWith(
                                color: AppColors.textDefault,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                await controller.pickMultiImage(context);
                              },
                              behavior: HitTestBehavior.translucent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.sky50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 18,
                                      color: AppColors.icPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '추가',
                                      style: AppTextStyle.labelMediumStyle
                                          .copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      showEmptyImage
                          ? GestureDetector(
                              onTap: () async {
                                await controller.pickMultiImage(context);
                              },
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.photo_outlined,
                                        size: 36,
                                        color: AppColors.icSecondary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '사진을 추가해보세요',
                                        style: AppTextStyle.labelMediumStyle
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '최대 10장까지 업로드할 수 있어요',
                                        style: AppTextStyle.labelSmallStyle
                                            .copyWith(
                                              color: AppColors.textTeritary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : _buildImagePageView(controller),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '기록 남기기',
                          style: AppTextStyle.titleSmallBoldStyle.copyWith(
                            color: AppColors.textDefault,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CommonTextField(
                          controller: textEditingController,
                          hintText: '운동기록을 남겨보세요',
                          maxLength: 200,
                          minLines: 6,
                          maxLines: 10,
                          scrollPadding: 300,
                          onChanged: controller.onChangeText,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (state.selectMainType == '질문')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '투표 만들기',
                                style: AppTextStyle.titleSmallBoldStyle
                                    .copyWith(color: AppColors.textDefault),
                              ),
                              const SizedBox(height: 10),
                              PollBuilder(
                                options: state.pollOptions,
                                onAdd: controller.addPollOption,
                                onRemove: controller.removePollOptionAt,
                                onChange: controller.changePollOption,
                              ),
                            ],
                          ),
                        ),
                      _buildPlaceButton(),
                      const SizedBox(height: 16),
                      if (widget.meetId == null) ...[
                        _buildVisibilitySection(),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              )
            : _buildTypeStepBody(state, controller),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required BuildContext context,
    required CreateFeedState state,
    required CreateFeedController controller,
    required bool canGoNext,
    required bool isSubmitEnabled,
    required bool isCreate,
  }) {
    // ✅ 오운완 진입 + 첫 페이지(서브타입)
    if (widget.isOowEntry && state.pageIndex == 1) {
      return CommonCloseAppbar(
        //title: '피드 작성하기',
      );
    }

    if (state.pageIndex == 0) {
      return CommonCloseAppbar(
        //title: '피드 작성하기',
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 8),
        //     child: GestureDetector(
        //       onTap: canGoNext ? controller.onTapNext : null,
        //       behavior: HitTestBehavior.translucent,
        //       child: Text(
        //         '다음',
        //         style: AppTextStyle.titleSmallBoldStyle.copyWith(
        //           color: canGoNext
        //               ? AppColors.textPrimary
        //               : AppColors.textTeritary,
        //         ),
        //       ),
        //     ),
        //   ),
        // ],
      );
    }

    if (state.pageIndex == 1) {
      return CommonBackAppbar(
        // title: '피드 작성하기',
        onBack:  () {
        controller.onTapBack(
          context,
          isOowEntry: widget.isOowEntry,
        );
      },
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 8),
        //     child: GestureDetector(
        //       onTap: canGoNext ? controller.onTapNext : null,
        //       behavior: HitTestBehavior.translucent,
        //       child: Text(
        //         '다음',
        //         style: AppTextStyle.titleSmallBoldStyle.copyWith(
        //           color: canGoNext
        //               ? AppColors.textPrimary
        //               : AppColors.textTeritary,
        //         ),
        //       ),
        //     ),
        //   ),
        // ],
      );
    }

    return CommonBackAppbar(
     // title: '피드 작성하기',
      onBack: () {
        controller.onTapBack(
          context,
          isOowEntry: widget.isOowEntry,
        );
      },
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: isSubmitEnabled
                ? () async {
              if (isCreate) {
                await controller.submitFeed(context, widget.meetId);
              } else if (widget.feed != null) {
                await controller.updateFeed(
                  context,
                  feedId: widget.feed!.id,
                  meetId: widget.meetId,
                );
              }
            }
                : null,
            behavior: HitTestBehavior.translucent,
            child: Text(
              isCreate ? '완료' : '수정',
              style: AppTextStyle.titleSmallBoldStyle.copyWith(
                color: isSubmitEnabled
                    ? AppColors.textPrimary
                    : AppColors.textTeritary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeStepBody(
    CreateFeedState state,
    CreateFeedController controller,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Transform.translate(
              offset: const Offset(0, -40),
              child: Center(
                child: state.pageIndex == 0
                    ? _buildMainTypeSelectView(state, controller)
                    : _buildSubTypeSelectView(state, controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainTypeSelectView(
    CreateFeedState state,
    CreateFeedController controller,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CommonFadeWidget(
          delay: Duration(milliseconds: 300),
          child: Text(
            '피드 유형',
            style: AppTextStyle.headlineLargeStyle,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        CommonFadeWidget(
          delay: Duration(milliseconds: 600),
          child: Text(
            '어떤 피드를 작성할지 선택해주세요',
            style: AppTextStyle.titleMediumStyle.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        CommonFadeWidget(
          delay: Duration(milliseconds: 900),
          child: Row(
            children: FeedMainType.values.map((type) {
              final isSelected = state.selectMainType == type.label;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: type == FeedMainType.values.last ? 0 : 8,
                  ),
                  child: _MainTypeButton(
                    label: type.label,
                    selected: isSelected,
                    onTap: state.isStepTransitioning
                        ? () {}
                        : () async {
                            await controller.selectMainTypeAndGoNext(
                              type.label,
                            );
                          },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTypeSelectView(
    CreateFeedState state,
    CreateFeedController controller,
  ) {
    return CommonFadeWidget(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommonFadeWidget(
            delay: Duration(milliseconds: 300),
            child: Text(
              '운동 종목',
              style: AppTextStyle.headlineLargeStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          CommonFadeWidget(
            delay: Duration(milliseconds: 600),
            child: Text(
              '피드에 표시할 운동 종목을 선택해주세요',
              style: AppTextStyle.titleMediumStyle.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          CommonFadeWidget(
            delay: Duration(milliseconds: 900),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: workList.map((w) {
                return CommonChip(
                  label: w,
                  selected: state.selectSubType == w,
                  onTap: state.isStepTransitioning
                      ? () {}
                      : () async {
                          await controller.selectSubTypeAndGoNext(w);
                        },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilitySection() {
    final state = ref.watch(createFeedControllerProvider);
    final controller = ref.read(createFeedControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '공개 범위',
            style: AppTextStyle.titleSmallBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CommonChip(
                label: '모두에게 공개',
                selected: state.visibility == FeedVisibility.public,
                onTap: () {
                  controller.onChangeVisibility(FeedVisibility.public);
                },
              ),
              CommonChip(
                label: '친구에게만 공개',
                selected: state.visibility == FeedVisibility.friends,
                onTap: () {
                  controller.onChangeVisibility(FeedVisibility.friends);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Padding _buildPlaceButton() {
    final controller = ref.read(createFeedControllerProvider.notifier);
    final state = ref.watch(createFeedControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '장소',
            style: AppTextStyle.titleSmallBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              final FeedPlace? place = await Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => const CommonLocationSearchView(),
                ),
              );
              if (place != null) {
                controller.onSelectPlace(place);
              }
            },
            child: state.selectedPlace == null
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.location_solid,
                          color: AppColors.icSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '장소를 선택해주세요',
                            style: AppTextStyle.bodyMediumStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.icSecondary,
                        ),
                      ],
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.map_pin_ellipse,
                          color: AppColors.icPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.selectedPlace!.title,
                                style: AppTextStyle.titleSmallBoldStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state.selectedPlace!.address,
                                style: AppTextStyle.bodySmallStyle.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.icSecondary,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  AspectRatio _buildImagePageView(CreateFeedController controller) {
    final state = ref.watch(createFeedControllerProvider);
    final allImages = <Object>[
      ...state.existingImageUrls,
      ...state.newImageFiles,
    ];

    return AspectRatio(
      aspectRatio: 1,
      child: PageView.builder(
        controller: pageController,
        itemCount: allImages.length,
        onPageChanged: controller.onChangeImageIndex,
        itemBuilder: (context, index) {
          final item = allImages[index];

          return Stack(
            children: [
              Positioned.fill(
                child: item is String
                    ? CommonNetworkImage(imageUrl: item, fit: BoxFit.cover)
                    : Image.file(File((item as XFile).path), fit: BoxFit.cover),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    controller.removeImageAt(index);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bgWhite.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.icDefault,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${index + 1} / ${allImages.length}',
                    style: AppTextStyle.labelSmallStyle.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MainTypeButton extends StatelessWidget {
  const _MainTypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 56,
        decoration: BoxDecoration(
          color: selected ? AppColors.btnPrimary : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyle.titleMediumBoldStyle.copyWith(
            color: selected ? AppColors.white : AppColors.textDefault,
          ),
        ),
      ),
    );
  }
}
