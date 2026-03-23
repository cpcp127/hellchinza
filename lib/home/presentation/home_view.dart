import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hellchinza/chat/providers/chat_provider.dart';
import 'package:hellchinza/common/common_home_app_bar.dart';
import 'package:hellchinza/constants/app_colors.dart';
import 'package:hellchinza/constants/app_text_style.dart';

import 'package:hellchinza/home/presentation/home_controller.dart';
import 'package:hellchinza/home/providers/home_provider.dart';

import 'package:hellchinza/notification/notification_list_view.dart';
import 'package:hellchinza/oow_step/presentation/oow_step_view.dart';
import 'package:hellchinza/profile/profile_view.dart';
import 'package:hellchinza/ranking/ranking_view.dart';
import 'package:hellchinza/setting/setting_view.dart';

import '../../chat/chat_list/chat_list_view.dart';
import '../../feed/create_feed/create_feed_view.dart';
import '../../feed/feed_list/feed_list_view.dart';
import '../../meet/meet_create/meet_create_view.dart';
import '../../meet/meet_home/meet_home_view.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initAsync = ref.watch(homeInitProvider);
    final hasUnreadAsync = ref.watch(hasUnreadNotificationProvider);
    final unreadAsync = ref.watch(unreadChatCountProvider);
    final homeState = ref.watch(homeControllerProvider);
    final homeController = ref.read(homeControllerProvider.notifier);
    final currentUid = ref.watch(homeCurrentUidProvider);

    return initAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Home init error: $e'))),
      data: (_) {
        final title = HomeController.pageTitles[homeState.pageIndex];

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: Scaffold(
            appBar: CommonHomeAppbar(
              title: title,
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RankingView()),
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
                      MaterialPageRoute(builder: (_) => const ChatListView()),
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
                if (homeState.pageIndex == 3)
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 24,
                      color: AppColors.icDefault,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingView()),
                      );
                    },
                  ),
              ],
            ),
            bottomNavigationBar: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              child: BottomNavigationBar(
                showSelectedLabels: false,
                showUnselectedLabels: false,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                backgroundColor: Colors.white,
                selectedItemColor: AppColors.btnPrimary,
                unselectedItemColor: Colors.grey,
                currentIndex: homeState.navIndex,
                onTap: (index) {
                  if (index == 2) {
                    homeController.showCreateActionSheet(
                      context: context,
                      onCreateFeed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const CreateFeedView(),
                          ),
                        );
                      },
                      onCreateMeeting: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const MeetCreateStepperView(),
                          ),
                        );
                      },
                    );
                    return;
                  }

                  homeController.onTapBottomNav(index);
                },
                items: [
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/svg/gym.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        homeState.pageIndex == 0
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
                        homeState.pageIndex == 1
                            ? AppColors.icPrimary
                            : AppColors.gray200,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: '',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.add),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/svg/meet.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        homeState.pageIndex == 2
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
                        homeState.pageIndex == 3
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
              index: homeState.pageIndex,
              children: [
                currentUid == null
                    ? const SizedBox()
                    : OowStepView(uid: currentUid),
                const FeedListView(),
                const MeetHomeView(),
                currentUid == null
                    ? const SizedBox()
                    : ProfileView(uid: currentUid, fromHomeTab: true),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChatBadge extends StatelessWidget {
  const ChatBadge({super.key, required this.count});

  final int count;

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
