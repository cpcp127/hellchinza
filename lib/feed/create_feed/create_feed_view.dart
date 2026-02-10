import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_back_appbar.dart';
import 'package:hellchinza/common/common_bottom_button.dart';
import 'package:hellchinza/common/common_location_serach_view.dart';
import 'package:hellchinza/common/common_text_field.dart';
import 'package:hellchinza/feed/create_feed/create_feed_controller.dart';
import 'package:hellchinza/feed/domain/naver_place_model.dart';
import 'package:hellchinza/services/image_service.dart';

import '../../common/common_chip.dart';
import '../../common/common_network_image.dart';
import '../../common/common_poll_builder.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_style.dart';
import 'package:hellchinza/feed/create_feed/create_feed_state.dart';

import '../domain/feed_model.dart';

class CreateFeedView extends ConsumerStatefulWidget {
  final String mode;
  final FeedModel? feed; // edit일 때만 필요
  final String? meetId;

  const CreateFeedView({
    super.key,
    this.mode = 'create',
    this.feed,
    this.meetId,
  });

  @override
  ConsumerState createState() => _CreateFeedViewState();
}

class _CreateFeedViewState extends ConsumerState<CreateFeedView> {
  PageController pageController = PageController();
  TextEditingController textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createFeedControllerProvider);
    final controller = ref.read(createFeedControllerProvider.notifier);
    final bool hasImage =
        (state.existingImageUrls?.isNotEmpty ?? false) ||
        (state.newImageFiles?.isNotEmpty ?? false);

    final bool hasText = (state.contents ?? '').trim().isNotEmpty;

    final bool isSubmitEnabled = hasImage || hasText;
    final bool hasMainType =
        state.selectMainType != null && state.selectMainType!.isNotEmpty;
    final bool hasSubType =
        state.selectSubType != null && state.selectSubType!.isNotEmpty;

    final isNextEnabled = hasMainType && hasSubType;
    final bool isCreate = widget.mode == 'create';
    final bool isEdit = widget.mode == 'update';
    final bool showEmptyImage = isCreate
        ? (state.newImageFiles?.isEmpty ?? true)
        : ((state.existingImageUrls?.isEmpty ?? true) &&
              (state.newImageFiles?.isEmpty ?? true));
    return Scaffold(
      appBar: state.pageIndex == 0
          ? CommonCloseAppbar(
              title: '피드 작성하기',
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: isNextEnabled
                        ? () {
                            controller.onTapNext();
                          }
                        : null,
                    behavior: HitTestBehavior.translucent,
                    child: Text(
                      '다음',
                      style: AppTextStyle.titleSmallBoldStyle.copyWith(
                        color: isNextEnabled
                            ? AppColors
                                  .textPrimary // sky400
                            : AppColors.textDisabled, // gray100
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
                            if (widget.mode == 'create') {
                              controller.submitFeed(context, widget.meetId);
                            } else {
                              //편집 로직
                              controller.updateFeed(
                                context,
                                feedId: widget.feed!.id,
                              );
                            }
                          }
                        : null,
                    behavior: HitTestBehavior.translucent,
                    child: state.isUploading == false
                        ? Text(
                            '완료',
                            style: AppTextStyle.titleSmallBoldStyle.copyWith(
                              color: isSubmitEnabled
                                  ? AppColors
                                        .textPrimary // sky400
                                  : AppColors.textDisabled, // gray100
                            ),
                          )
                        : CupertinoActivityIndicator(),
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
                              // TODO: 사진 추가 로직
                              await controller.pickMultiImage();
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
                    SizedBox(height: 10),
                    showEmptyImage
                        ? GestureDetector(
                            onTap: () async {
                              await controller.pickMultiImage();
                            },
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
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
                    SizedBox(height: 10),
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
                        onChanged: (str) {
                          controller.onChangeText(str);
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    state.selectMainType == '질문'
                        ? Padding(
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
                                  options:
                                      state.pollOptions ??
                                      const [], // List<String>
                                  onAdd: controller.addPollOption,
                                  onRemove: controller.removePollOptionAt,
                                  onChange: controller.changePollOption,
                                ),
                              ],
                            ),
                          )
                        : Container(),
                    if (state.selectMainType == '후기') _buildPlaceButton(),
                  ],
                ),
              )
            : _buildSelectTypeView(state, controller),
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
            '후기 장소',
            style: AppTextStyle.titleSmallBoldStyle.copyWith(
              color: AppColors.textDefault,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final FeedPlace? selected = await Navigator.push(
                context,
                CupertinoPageRoute(
                  fullscreenDialog: true,
                  builder: (context) {
                    return CommonLocationSearchView();
                  },
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
                            '어디에 대한 후기인가요?',
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

  AspectRatio _buildImagePageView(CreateFeedController controller) {
    final state = ref.watch(createFeedControllerProvider);
    final existingUrls = state.existingImageUrls ?? const <String>[];
    final newFiles = state.newImageFiles ?? const <XFile>[];

    // ✅ PageView에서 보여줄 통합 리스트 (String or XFile)
    final allImages = <Object>[...existingUrls, ...newFiles];

    return AspectRatio(
      aspectRatio: 1,
      child: PageView.builder(
        controller: pageController,
        itemCount: allImages.length,
        onPageChanged: (i) {
          controller.onChangeImageIndex(i);
        },
        itemBuilder: (context, index) {
          final item = allImages[index];

          return Stack(
            children: [
              // ✅ 이미지 (기존: URL / 신규: File)
              Positioned.fill(
                child: item is String
                    ? CommonNetworkImage(
                        // ✅ 너가 만든 cached 공통 위젯
                        imageUrl: item,
                        fit: BoxFit.cover,
                      )
                    : Image.file(File((item as XFile).path), fit: BoxFit.cover),
              ),

              // ❌ 삭제 버튼 (오른쪽 상단)
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

              // 📄 페이지 인덱스 표시 (좌하단)
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
