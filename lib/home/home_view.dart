import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hellchinza/feed/create_feed/create_feed_view.dart';
import 'package:hellchinza/feed/feed_list/feed_list_view.dart';
import 'package:hellchinza/meet/meet_create/meet_create_view.dart';
import 'package:hellchinza/meet/meet_list/meet_list_view.dart';
import 'package:hellchinza/profile/profile_view.dart';

import '../auth/domain/user_model.dart';
import '../chat/chat_list_view.dart';
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
  List<String> title = ['피드', '모임', '프로필', '프로필'];

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
              if (pageIndex == 3) ...[
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

                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 24,
                    color: AppColors.icDefault,
                  ),
                  onPressed: () {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatListView(), // 채팅 리스트 화면
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey, // 테두리 색
                  width: 1, // 두께
                ),
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory, // ⭐ 핵심
              ),
              child: BottomNavigationBar(
                onTap: (index) {
                  setState(() {
                    pageIndex = index;
                  });
                },
                type: BottomNavigationBarType.fixed,

                elevation: 0,
                backgroundColor: Colors.white,
                selectedItemColor: Colors.black,
                unselectedItemColor: Colors.grey,
                currentIndex: pageIndex,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.feed), label: '피드'),
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: '모음'),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: '프로필',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: '프로필',
                  ),
                ],
              ),
            ),
          ),
          body: IndexedStack(
            index: pageIndex,
            children: [
              FeedListView(),
              MeetListView(),
              Container(),
              ProfileView(uid: FirebaseAuth.instance.currentUser!.uid,),
            ],
          ),
        );
      },
    );
  }
}
