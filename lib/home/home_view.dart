import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/common/common_home_app_bar.dart';
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
          appBar: CommonHomeAppbar(
            title: title[pageIndex],

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
                } else {
                  setState(() {
                    if (index == 0 || index == 1) {
                      pageIndex = index;
                    } else {
                      pageIndex = index - 1;
                    }
                  });
                }
              },
              type: BottomNavigationBarType.fixed,

              elevation: 0,
              backgroundColor: Colors.white,
              selectedItemColor: AppColors.btnPrimary,
              unselectedItemColor: Colors.grey,
              currentIndex: pageIndex,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.feed), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: ''),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_box_outlined),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble),
                  label: '',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
              ],
            ),
          ),

          body: IndexedStack(
            index: pageIndex,
            children: [
              FeedListView(),
              MeetListView(),
              ChatListView(),
              ProfileView(
                uid: FirebaseAuth.instance.currentUser!.uid,
                fromHomeTab: true,
              ),
            ],
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
