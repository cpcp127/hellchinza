import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hellchinza/common/common_home_app_bar.dart';
import 'package:hellchinza/feed/create_feed/create_feed_view.dart';
import 'package:hellchinza/feed/feed_list/feed_list_view.dart';
import 'package:hellchinza/meet/meet_create/meet_create_view.dart';
import 'package:hellchinza/meet/meet_home/meet_home_view.dart';
import 'package:hellchinza/meet/meet_list/meet_list_view.dart';
import 'package:hellchinza/oow_step/presentation/oow_step_view.dart';
import 'package:hellchinza/profile/profile_view.dart';
import 'package:hellchinza/ranking/ranking_view.dart';

import '../chat/chat_list/chat_list_view.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_style.dart';
import '../notification/notification_list_view.dart';
import '../setting/setting_view.dart';
import 'home_controller.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  int _navIndex = 0; // BottomNavigationBar 선택 인덱스 (0~4)
  int _pageIndex = 0; // 실제 화면 인덱스 (0~3)
  List<String> title = ['오운완', '피드', '모임', '프로필'];

  @override
  Widget build(BuildContext context) {
    final initAsync = ref.watch(homeInitProvider);
    final hasUnreadAsync = ref.watch(hasUnreadNotificationProvider);
    final controller = ref.read(homeControllerProvider.notifier);
    final unreadAsync = ref.watch(unreadChatCountProvider);

    return initAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Home init error: $e'))),
      data: (ok) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Android
            statusBarBrightness: Brightness.light, // iOS -> 검정 글자
          ),
          child: Scaffold(
            appBar: CommonHomeAppbar(
              title: title[_pageIndex],

              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RankingView()),
                    );
                  },
                  icon: SvgPicture.asset(
                    'assets/svg/crown.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationListView(),
                          ),
                        );
                      },
                      icon: SvgPicture.asset(
                        'assets/svg/bell.svg',
                        width: 24,
                        height: 24,
                      ),
                    ),
                    if (hasUnreadAsync.value == true)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.red100,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),

                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatListView(),
                      ),
                    );
                  },
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SvgPicture.asset(
                        'assets/svg/chat.svg',
                        width: 24,
                        height: 24,
                      ),

                      unreadAsync.when(
                        data: (count) {
                          if (count == 0) return const SizedBox();

                          return Positioned(
                            right: -4,
                            top: -4,
                            child: ChatBadge(count: count),
                          );
                        },
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
                _pageIndex != 3
                    ? Container()
                    : IconButton(
                        icon: const Icon(
                          Icons.settings_outlined,
                          size: 24,
                          color: AppColors.icDefault,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return SettingView();
                              },
                            ),
                          );
                        },
                      ),
              ],
            ),
            bottomNavigationBar: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory, // ⭐ 핵심
              ),
              child: BottomNavigationBar(
                showSelectedLabels: false,
                showUnselectedLabels: false,

                onTap: (index) {
                  if (index == 2) {
                    controller.showCreateActionSheet(
                      context: context,
                      onCreateFeed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            fullscreenDialog: true,
                            builder: (context) {
                              return CreateFeedView();
                            },
                          ),
                        );
                      },
                      onCreateMeeting: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            fullscreenDialog: true,
                            builder: (context) {
                              return MeetCreateStepperView();
                            },
                          ),
                        );
                      },
                    );
                    return;
                  } else {
                    setState(() {
                      _navIndex = index;
                      _pageIndex = index > 2 ? index - 1 : index;
                    });
                  }
                },
                type: BottomNavigationBarType.fixed,

                elevation: 0,
                backgroundColor: Colors.white,
                selectedItemColor: AppColors.btnPrimary,
                unselectedItemColor: Colors.grey,
                currentIndex: _navIndex,
                items: [
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/svg/gym.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        _pageIndex == 0
                            ? AppColors.icPrimary
                            : AppColors.gray200,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/svg/document.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        _pageIndex == 1
                            ? AppColors.icPrimary
                            : AppColors.gray200,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(icon: Icon(Icons.add), label: ''),
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/svg/meet.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        _pageIndex == 2
                            ? AppColors.icPrimary
                            : AppColors.gray200,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: '',
                  ),

                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/svg/user.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        _pageIndex == 3
                            ? AppColors.icPrimary
                            : AppColors.gray200,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: '',
                  ),
                ],
              ),
            ),

            body: IndexedStack(
              index: _pageIndex,
              children: [
                OowStepView(uid: FirebaseAuth.instance.currentUser!.uid),
                FeedListView(),
                MeetHomeView(),

                FirebaseAuth.instance.currentUser == null
                    ? Container()
                    : ProfileView(
                        uid: FirebaseAuth.instance.currentUser!.uid,
                        fromHomeTab: true,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
  }
}

class ChatBadge extends StatelessWidget {
  final int count;

  const ChatBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: const BoxDecoration(
        color: AppColors.red100,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Center(
        child: Text(
          text,
          style: AppTextStyle.labelXSmallStyle.copyWith(
            color: AppColors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}
