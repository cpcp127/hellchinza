import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/feed/create_feed/create_feed_controller.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common/common_back_appbar.dart';
import '../../../common/common_chip.dart';
import '../../../common/common_location_serach_view.dart';
import '../../../common/common_network_image.dart';
import '../../../common/common_poll_builder.dart';
import '../../../common/common_text_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_style.dart';

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
  });

  final String mode;
  final FeedModel? feed;
  final String? meetId;

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
    final isSubmitEnabled = hasImage || hasText;
    final hasMainType =
        state.selectMainType != null && state.selectMainType!.isNotEmpty;
    final hasSubType =
        state.selectSubType != null && state.selectSubType!.isNotEmpty;
    final isNextEnabled = hasMainType && hasSubType;
    final isCreate = widget.mode == 'create';

    final showEmptyImage =
        state.existingImageUrls.isEmpty && state.newImageFiles.isEmpty;

    return Scaffold(
      appBar: state.pageIndex == 0
          ? CommonCloseAppbar(
              title: '피드 작성하기',
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: isNextEnabled ? controller.onTapNext : null,
                    behavior: HitTestBehavior.translucent,
                    child: Text(
                      '다음',
                      style: AppTextStyle.titleSmallBoldStyle.copyWith(
                        color: isNextEnabled
                            ? AppColors.textPrimary
                            : AppColors.textDisabled,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : CommonBackAppbar(
              onBack: () {
                textEditingController.clear();
                controller.onTapBack();
              },
              title: '피드 작성하기',
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: isSubmitEnabled
                        ? () {
                            if (isCreate) {
                              controller.submitFeed(context, widget.meetId);
                            } else {
                              controller.updateFeed(
                                context,
                                feedId: widget.feed!.id,
                                meetId: widget.meetId,
                              );
                            }
                          }
                        : null,
                    behavior: HitTestBehavior.translucent,
                    child: state.isUploading
                        ? const CupertinoActivityIndicator()
                        : Text(
                            '완료',
                            style: AppTextStyle.titleSmallBoldStyle.copyWith(
                              color: isSubmitEnabled
                                  ? AppColors.textPrimary
                                  : AppColors.textDisabled,
                            ),
                          ),
                  ),
                ),
              ],
            ),
      body: SafeArea(
        child: state.pageIndex == 1
            ? SingleChildScrollView(
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
                                        .copyWith(color: AppColors.textPrimary),
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
                              style: AppTextStyle.titleSmallBoldStyle.copyWith(
                                color: AppColors.textDefault,
                              ),
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
              )
            : _buildSelectTypeView(state, controller),
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
              final FeedPlace? selected = await Navigator.push(
                context,
                CupertinoPageRoute(
                  fullscreenDialog: true,
                  builder: (context) => CommonLocationSearchView(),
                ),
              );

              if (selected == null) return;
              controller.onSelectPlace(selected);
            },
            child: state.selectedPlace == null
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSecondary),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 20,
                          color: AppColors.icSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '장소를 추가해보세요~',
                            style: AppTextStyle.bodyMediumStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.icSecondary,
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSecondary),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: AppColors.icSecondary,
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

  Padding _buildSelectTypeView(
    CreateFeedState state,
    CreateFeedController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '피드 유형',
            style: AppTextStyle.titleSmallBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...FeedMainType.values.map((w) {
                return CommonChip(
                  label: w.label,
                  selected: state.selectMainType == w.label,
                  onTap: () {
                    controller.onChangeMainType(w.label);
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '운동 종목',
            style: AppTextStyle.titleSmallBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...workList.map((w) {
                return CommonChip(
                  label: w,
                  selected: state.selectSubType == w,
                  onTap: () {
                    controller.onChangeSubType(w);
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
