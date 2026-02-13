import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/auth/presentation/auth_controller.dart';
import 'package:hellchinza/auth/presentation/auth_view.dart';
import 'package:hellchinza/auth/presentation/extra_info/extra_info_controller.dart';
import 'package:hellchinza/auth/presentation/extra_info/extra_info_state.dart';
import 'package:hellchinza/common/common_back_appbar.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/common/common_fade_widget.dart';
import 'package:hellchinza/constants/app_constants.dart';
import 'package:hellchinza/constants/app_text_style.dart';

import '../../../common/common_bottom_button.dart';
import '../../../common/common_text_field.dart';
import '../../../constants/app_border_radius.dart';
import '../../../constants/app_colors.dart';

final _nicknameFormKey = GlobalKey<FormState>();

class ExtraInfoView extends ConsumerStatefulWidget {
  const ExtraInfoView({super.key});

  @override
  ConsumerState createState() => _ExtraInfoViewState();
}

class _ExtraInfoViewState extends ConsumerState<ExtraInfoView> {
  TextEditingController nickController = TextEditingController();


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
          title: Text('회원가입'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: (){
              controller.back();
            },
          ),
        ),
        body: SafeArea(
          child: state.currentIndex == 0
              ? buildNickNameInputView(controller, state)
              : state.currentIndex == 1
              ? buildSelectGenderView(controller, state) // ✅ 추가
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
          SizedBox(height: 12),
          CommonFadeWidget(
            delay: Duration(milliseconds: 800),
            child: Text(
              '최대 8자로 띄어쓰기 없이 알려주세요',
              style: AppTextStyle.bodyMediumStyle,
            ),
          ),
          SizedBox(height: 16),
          CommonFadeWidget(
            delay: Duration(milliseconds: 1200),
            child: Form(
              key: _nicknameFormKey,
              child: CommonTextField(
                hintText: '닉네임을 입력하세요',
                maxLength: 8,
                controller: nickController,
                onChanged: (str) {
                  controller.onChangeNickname(str);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    controller.onChangeNicknameErrorText('닉네임을 입력해주세요');
                    return '';
                    //return '닉네임을 입력해주세요';
                  } else if (RegExp(r'\s').hasMatch(value)) {
                    controller.onChangeNicknameErrorText(
                      '닉네임에는 띄어쓰기를 사용할 수 없어요',
                    );
                    //return '닉네임에는 띄어쓰기를 사용할 수 없어요';
                    return '';
                  }
                  return null;
                },
              ),
            ),
          ),
          state.nicknameErrorText == null
              ? Container()
              : Text(state.nicknameErrorText!,style: AppTextStyle.labelSmallStyle,),
          Expanded(child: SizedBox()),
          CommonBottomButton(
            title: '다음',
            enabled: true, // false면 회색 + 클릭불가
            loading: false, // true면 로딩 + 클릭불가
            onTap: () {
              controller.submitNickname(_nicknameFormKey);
            },
          ),
          SizedBox(height: 16),
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
              '매칭/추천에 활용돼요',
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

          Expanded(child: const SizedBox()),

          CommonBottomButton(
            title: '다음',
            enabled: state.gender != null,
            loading: false,
            onTap: () {
              controller.submitGender();
            },
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
          SizedBox(height: 12),
          CommonFadeWidget(
            delay: Duration(milliseconds: 800),
            child: Text(
              '요즘 하고 있거나 관심있는 운동을 1개 이상 선택 해 주세요',
              style: AppTextStyle.bodyMediumStyle,
            ),
          ),
          SizedBox(height: 16),
          CommonFadeWidget(
            delay: Duration(milliseconds: 1200),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: personalityChip(),
            ),
          ),
          state.nicknameErrorText == null
              ? Container()
              : Text(state.nicknameErrorText!),
          Expanded(child: SizedBox()),
          CommonBottomButton(
            title: '가입 완료',
            enabled:
                state.selectedCategory != null &&
                state.selectedCategory!.isNotEmpty,
            loading: false,

            onTap: () {
              controller.completeSignup();
            },
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> personalityChip() {
    final state = ref.watch(extraInfoControllerProvider);
    final controller = ref.read(extraInfoControllerProvider.notifier);

    List<Widget> chips = [];

    for (var item in workList) {
      final bool isSelected = state.selectedCategory?.contains(item) ?? false;

      chips.add(
        GestureDetector(
          onTap: () => controller.toggleCategory(item),
          child: CommonChip(label: item, selected: isSelected),
        ),
      );
    }

    return chips;
  }
}
