import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/feed/create_feed/create_feed_view.dart';
import 'package:hellchinza/feed/feed_list/feed_list_view.dart';
import 'package:hellchinza/meet/meet_create/meet_create_view.dart';
import 'package:hellchinza/meet/meet_list/meet_list_view.dart';
import 'package:hellchinza/profile/profile_view.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../auth/domain/user_model.dart';
import '../chat/chat_list/chat_list_view.dart';
import '../constants/app_colors.dart';
import '../services/snackbar_service.dart';
import '../setting/setting_view.dart';
import 'home_controller.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  int pageIndex = 0;
  List<String> title = ['피드', '모임', '채팅', '프로필'];
  late final PersistentTabController _tabCtrl;

  @override
  Widget build(BuildContext context) {
    final initAsync = ref.watch(homeInitProvider);
    final controller = ref.read(homeControllerProvider.notifier);
    return initAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Home init error: $e'))),
      data: (ok) {
        return Scaffold(
          appBar: AppBar(
            title: Text(title[pageIndex]),

            actions: [
              IconButton(
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

              if (pageIndex != 3) ...[
                IconButton(
                  icon: const Icon(
                    Icons.add_box_outlined,
                    size: 24,
                    color: AppColors.icDefault,
                  ),
                  onPressed: () {
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
                  },
                ),
              ],
            ],
          ),
          // bottomNavigationBar: Container(
          //   decoration: const BoxDecoration(
          //     border: Border(
          //       top: BorderSide(
          //         color: Colors.grey, // 테두리 색
          //         width: 1, // 두께
          //       ),
          //     ),
          //   ),
          //   child: Theme(
          //     data: Theme.of(context).copyWith(
          //       splashColor: Colors.transparent,
          //       highlightColor: Colors.transparent,
          //       splashFactory: NoSplash.splashFactory, // ⭐ 핵심
          //     ),
          //     child: BottomNavigationBar(
          //       onTap: (index) {
          //         setState(() {
          //           pageIndex = index;
          //         });
          //       },
          //       type: BottomNavigationBarType.fixed,
          //
          //       elevation: 0,
          //       backgroundColor: Colors.white,
          //       selectedItemColor: Colors.black,
          //       unselectedItemColor: Colors.grey,
          //       currentIndex: pageIndex,
          //       items: const [
          //         BottomNavigationBarItem(icon: Icon(Icons.feed), label: '피드'),
          //         BottomNavigationBarItem(icon: Icon(Icons.home), label: '모음'),
          //         BottomNavigationBarItem(
          //           icon: Icon(Icons.chat_bubble),
          //           label: '채팅',
          //         ),
          //         BottomNavigationBarItem(
          //           icon: Icon(Icons.person),
          //           label: '프로필',
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          // body: IndexedStack(
          //   index: pageIndex,
          //   children: [
          //     FeedListView(),
          //     MeetListView(),
          //     ChatListView(),
          //     ProfileView(
          //       uid: FirebaseAuth.instance.currentUser!.uid,
          //       fromHomeTab: true,
          //     ),
          //   ],
          // ),
          body: PersistentTabView(
            controller: _tabCtrl,
            tabs: _buildTabs(),
            onTabChanged: (index) {
              setState(() {
                pageIndex = index;
              });
            },
            // ✅ 네비 스타일은 원하는 Style로 바꿔도 됨
            navBarBuilder: (navBarConfig) => Style1BottomNavBar(
              navBarConfig: navBarConfig,
              navBarDecoration: NavBarDecoration(color: AppColors.bgWhite),
            ),

            // ✅ 가운데 추가 버튼
            floatingActionButton: _CenterAddButton(
              onTap: () => {
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
                ),
              },
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.miniCenterDocked,

            // (선택) 키보드 올라올 때 화면 밀림 제어
            resizeToAvoidBottomInset: true,
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = PersistentTabController(initialIndex: 0);
  }

  List<PersistentTabConfig> _buildTabs() {
    return [
      PersistentTabConfig(
        screen: const FeedListView(),
        item: ItemConfig(
          icon: const Icon(Icons.view_list_outlined),
          title: '피드',
          activeForegroundColor: AppColors.icPrimary,
          inactiveForegroundColor: AppColors.icSecondary,
        ),
      ),
      PersistentTabConfig(
        screen: const MeetListView(),
        item: ItemConfig(
          icon: const Icon(Icons.groups_outlined),
          title: '모임',
          activeForegroundColor: AppColors.icPrimary,
          inactiveForegroundColor: AppColors.icSecondary,
        ),
      ),
      PersistentTabConfig(
        screen: const ChatListView(),
        item: ItemConfig(
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          title: '채팅',
          activeForegroundColor: AppColors.icPrimary,
          inactiveForegroundColor: AppColors.icSecondary,
        ),
      ),
      PersistentTabConfig(
        screen: ProfileView(
          uid: FirebaseAuth.instance.currentUser!.uid,
          fromHomeTab: true,
        ),
        item: ItemConfig(
          icon: const Icon(Icons.person_outline),
          title: '프로필',
          activeForegroundColor: AppColors.icPrimary,
          inactiveForegroundColor: AppColors.icSecondary,
        ),
      ),
    ];
  }
}

class _CenterAddButton extends StatelessWidget {
  const _CenterAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: AppColors.btnPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add, color: AppColors.white, size: 26),
      ),
    );
  }
}
