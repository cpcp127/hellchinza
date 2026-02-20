import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../profile/profile_view.dart';
import 'common_network_image.dart';

class CommonProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String uid;
  final String? gender;

  const CommonProfileAvatar({
    super.key,
    required this.imageUrl,
     this.gender,
    this.size = 40,
    required this.uid,
  });

  Color get _borderColor {
    if (gender == '남성') return AppColors.sky400; // 파랑
    if (gender == '여성') return AppColors.pink400; // 핑크/레드
    return AppColors.borderSecondary; // 선택안함/기타
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileView(uid: uid)),
        );
      },
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2), // ✅ 테두리 두께
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
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
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
