import 'package:flutter/material.dart';

import '../../common/common_network_image.dart';
import '../../constants/app_colors.dart';

class MeetThumb extends StatelessWidget {
  const MeetThumb({required this.url});

  final List<dynamic>? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSecondary),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url!.isEmpty)
          ? const Icon(Icons.image_outlined, color: AppColors.icDisabled)
          : CommonNetworkImage(imageUrl: url!.first, fit: BoxFit.cover),
      //: Image.network(url!, fit: BoxFit.cover),
    );
  }
}