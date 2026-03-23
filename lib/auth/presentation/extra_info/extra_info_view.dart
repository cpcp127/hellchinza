import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/auth/providers/auth_provider.dart';
import 'package:hellchinza/auth/presentation/extra_info/extra_info_controller.dart';
import 'package:hellchinza/auth/presentation/extra_info/extra_info_state.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/common/common_fade_widget.dart';
import 'package:hellchinza/common/common_bottom_button.dart';
import 'package:hellchinza/common/common_text_field.dart';
import 'package:hellchinza/constants/app_constants.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_text_style.dart';

final _nicknameFormKey = GlobalKey<FormState>();

class ExtraInfoView extends ConsumerStatefulWidget {
  const ExtraInfoView({super.key});

  @override
  ConsumerState createState() => _ExtraInfoViewState();
}

class _ExtraInfoViewState extends ConsumerState<ExtraInfoView> {
  final TextEditingController nickController = TextEditingController();

  @override
  void dispose() {
    nickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(extraInfoControllerProvider.notifier);
    final state = ref.watch(extraInfoControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        controller.back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('회원가입'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: controller.back,
          ),
        ),
        body: SafeArea(
          child: state.currentIndex == 0
              ? buildNickNameInputView(controller, state)
              : state.currentIndex == 1
              ? buildSelectGenderView(controller, state)
              : buildSelectCategoryView(controller, state),
        ),
      ),
    );
  }

  Padding buildNickNameInputView(
      ExtraInfoController controller,
      ExtraInfoState state,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonFadeWidget(
            duration: const Duration(milliseconds: 400),
            child: Text(
              '닉네임을 알려주세요',
              style: AppTextStyle.headlineMediumBoldStyle,
            ),
          ),
          const SizedBox(height: 12),
          CommonFadeWidget(
            delay: const Duration(milliseconds: 800),
            child: Text(
              '최대 8자로 띄어쓰기 없이 알려주세요',
              style: AppTextStyle.bodyMediumStyle,
            ),
          ),
          const SizedBox(height: 16),
          CommonFadeWidget(
            delay: const Duration(milliseconds: 1200),
            child: Form(
              key: _nicknameFormKey,
              child: CommonTextField(
                hintText: '닉네임을 입력하세요',
                maxLength: 8,
                controller: nickController,
                onChanged: controller.onChangeNickname,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    controller.onChangeNicknameErrorText('닉네임을 입력해주세요');
                    return '';
                  } else if (RegExp(r'\s').hasMatch(value)) {
                    controller.onChangeNicknameErrorText(
                      '닉네임에는 띄어쓰기를 사용할 수 없어요',
                    );
                    return '';
                  }
                  return null;
                },
              ),
            ),
          ),
          if (state.nicknameErrorText != null &&
              state.nicknameErrorText!.isNotEmpty)
            Text(
              state.nicknameErrorText!,
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.red100,
              ),
            ),
          const Spacer(),
          CommonBottomButton(
            title: '다음',
            enabled: !state.isLoading,
            loading: state.isLoading,
            onTap: () {
              controller.submitNickname(_nicknameFormKey);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Padding buildSelectGenderView(
      ExtraInfoController controller,
      ExtraInfoState state,
      ) {
    Widget genderChip(String label) {
      final selected = state.gender == label;
      return Expanded(
        child: GestureDetector(
          onTap: () => controller.onSelectGender(label),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.sky50 : AppColors.bgWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.sky400 : AppColors.borderSecondary,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyle.labelLargeStyle.copyWith(
                color: selected ? AppColors.textPrimary : AppColors.textDefault,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonFadeWidget(
            duration: const Duration(milliseconds: 400),
            child: Text(
              '성별을 선택해주세요',
              style: AppTextStyle.headlineMediumBoldStyle,
            ),
          ),
          const SizedBox(height: 12),
          CommonFadeWidget(
            delay: const Duration(milliseconds: 800),
            child: Text(
              '남성인가요? 여성인가요?',
              style: AppTextStyle.bodyMediumStyle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          CommonFadeWidget(
            delay: const Duration(milliseconds: 1100),
            child: Row(
              children: [
                genderChip('남성'),
                const SizedBox(width: 10),
                genderChip('여성'),
              ],
            ),
          ),
          const Spacer(),
          CommonBottomButton(
            title: '다음',
            enabled: state.gender != null && !state.isLoading,
            loading: state.isLoading,
            onTap: controller.submitGender,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Padding buildSelectCategoryView(
      ExtraInfoController controller,
      ExtraInfoState state,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonFadeWidget(
            duration: const Duration(milliseconds: 400),
            child: Text(
              '관심있는 운동을 선택해주세요',
              style: AppTextStyle.headlineMediumBoldStyle,
            ),
          ),
          const SizedBox(height: 12),
          CommonFadeWidget(
            delay: const Duration(milliseconds: 800),
            child: Text(
              '요즘 하고 있거나 관심있는 운동을 1개 이상 선택 해 주세요',
              style: AppTextStyle.bodyMediumStyle,
            ),
          ),
          const SizedBox(height: 16),
          CommonFadeWidget(
            delay: const Duration(milliseconds: 1200),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: personalityChip(),
            ),
          ),
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: AppTextStyle.labelSmallStyle.copyWith(
                color: AppColors.red100,
              ),
            ),
          ],
          const Spacer(),
          CommonBottomButton(
            title: '가입 완료',
            enabled: state.selectedCategory.isNotEmpty && !state.isLoading,
            loading: state.isLoading,
            onTap: controller.completeSignup,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> personalityChip() {
    final state = ref.watch(extraInfoControllerProvider);
    final controller = ref.read(extraInfoControllerProvider.notifier);

    return workList.map((item) {
      final isSelected = state.selectedCategory.contains(item);

      return GestureDetector(
        onTap: () => controller.toggleCategory(item),
        child: CommonChip(label: item, selected: isSelected),
      );
    }).toList();
  }
}