import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'common_network_image.dart';

class CommonProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const CommonProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: imageUrl == null
            ? _DefaultAvatar(size: size)
            : CommonNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
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
        size: size * 0.5,
        color: AppColors.icSecondary,
      ),
    );
  }
}
