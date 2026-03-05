import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hellchinza/common/common_chip.dart';
import 'package:hellchinza/constants/app_constants.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_style.dart';

class FeedFilterSheet extends StatefulWidget {
  const FeedFilterSheet({
    super.key,
    required this.initialMainType,
    required this.initialSubType,
    required this.initialOnlyFriends,
    required this.onApply,
  });

  final String initialMainType;
  final String initialSubType;
  final bool initialOnlyFriends;

  final void Function(String main, String sub, bool onlyFriends) onApply;

  @override
  State<FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends State<FeedFilterSheet> {
  late String _main;
  late String _sub;
  late bool _onlyFriends;

  // ✅ 너 앱의 실제 타입 리스트로 바꿔서 쓰면 됨
  final List<String> mainTypes = ['전체', '오운완', '식단', '질문', '후기'];
  final Map<String, List<String>> subTypesByMain = {
    '전체': ['전체', ...workList],
    '오운완': ['전체', ...workList],
    '식단': ['전체'], // 식단은 서브타입 없다고 했던 룰 유지
    '질문':['전체', ...workList],
    '후기':['전체', ...workList],
  };

  @override
  void initState() {
    super.initState();
    _main = widget.initialMainType;
    _sub = widget.initialSubType;
    _onlyFriends = widget.initialOnlyFriends;
  }

  @override
  Widget build(BuildContext context) {
    final subList = subTypesByMain[_main] ?? ['전체'];

    // 메인이 식단이면 서브는 강제로 전체
    if (_main == '식단' && _sub != '전체') {
      _sub = '전체';
    }
    // 메인 바뀌었는데 현재 sub가 목록에 없으면 reset
    if (!subList.contains(_sub)) _sub = subList.first;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.borderSecondary),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSecondary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '필터',
                      style: AppTextStyle.titleMediumBoldStyle.copyWith(
                        color: AppColors.textDefault,
                      ),
                    ),


                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _SectionTitle('메인 타입'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: mainTypes.map((t) {
                        final selected = _main == t;
                        return CommonChip(
                          label: t,
                          selected: selected,
                          onTap: () => setState(() => _main = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    _SectionTitle('서브 타입'),
                    const SizedBox(height: 10),
                    if (_main == '식단')
                      Text(
                        '식단은 서브 타입이 없어요',
                        style: AppTextStyle.bodySmallStyle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: subList.map((t) {
                          final selected = _sub == t;
                          return CommonChip(
                            label: t,
                            selected: selected,
                            onTap: () => setState(() => _sub = t),
                          );
                        }).toList(),
                      ),

                    // const SizedBox(height: 18),
                    // _SectionTitle('친구 피드만 보기'),
                    // const SizedBox(height: 10),
                    // Container(
                    //   padding: const EdgeInsets.all(14),
                    //   decoration: BoxDecoration(
                    //     color: AppColors.bgSecondary,
                    //     borderRadius: BorderRadius.circular(16),
                    //     border: Border.all(color: AppColors.borderSecondary),
                    //   ),
                    //   child: Row(
                    //     children: [
                    //       Expanded(
                    //         child: Text(
                    //           '친구의 피드만 보기',
                    //           style: AppTextStyle.bodyMediumStyle.copyWith(
                    //             color: AppColors.textDefault,
                    //             fontWeight: FontWeight.w700,
                    //           ),
                    //         ),
                    //       ),
                    //       CupertinoSwitch(
                    //         value: _onlyFriends,
                    //         onChanged: (v) => setState(() => _onlyFriends = v),
                    //         activeColor: AppColors.btnPrimary,
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ),

              // ✅ 하단 적용 버튼
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(_main, _sub, _onlyFriends);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.btnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '적용하기',
                        style: AppTextStyle.labelLargeStyle.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyle.titleSmallBoldStyle.copyWith(
        color: AppColors.textDefault,
      ),
    );
  }
}

