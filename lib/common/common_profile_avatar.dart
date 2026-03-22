import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../profile/profile_view.dart';
import 'common_network_image.dart';

class CommonProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String uid;
  final String? gender;
  final int? lastWeeklyRank;

  const CommonProfileAvatar({
    super.key,
    required this.imageUrl,
    this.gender,
    this.size = 40,
    required this.uid,
    this.lastWeeklyRank,
  });

  Color get _borderColor {
    if (gender == '남성') return AppColors.sky400;
    if (gender == '여성') return AppColors.pink400;
    return AppColors.borderSecondary;
  }

  bool get _showRankBadge =>
      lastWeeklyRank != null &&
          lastWeeklyRank! >= 1 &&
          lastWeeklyRank! <= 3;

  Color get _rankBadgeColor {
    switch (lastWeeklyRank) {
      case 1:
        return const Color(0xFFFFC83D); // gold
      case 2:
        return const Color(0xFFC9D1D9); // silver
      case 3:
        return const Color(0xFFD98B5F); // bronze
      default:
        return AppColors.borderSecondary;
    }
  }

  IconData get _rankBadgeIcon {
    switch (lastWeeklyRank) {
      case 1:
        return Icons.looks_one_rounded;
      case 2:
        return Icons.looks_two_rounded;
      case 3:
        return Icons.looks_3_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * 0.4;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileView(uid: uid)),
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _borderColor,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: (imageUrl == null || imageUrl!.isEmpty)
                    ? _DefaultAvatar(size: size)
                    : CommonNetworkImage(
                  imageUrl: imageUrl!,
                  enableViewer: false,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            if (_showRankBadge)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _rankBadgeColor,
                    border: Border.all(
                      color: AppColors.bgWhite,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withOpacity(0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _rankBadgeIcon,
                    size: badgeSize * 0.56,
                    color: AppColors.bgWhite,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  final double size;

  const _DefaultAvatar({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.gray100,
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: size * 0.7,
        color: AppColors.icSecondary,
      ),
    );
  }
}
