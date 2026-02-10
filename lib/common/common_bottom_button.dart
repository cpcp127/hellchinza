import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CommonBottomButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final bool enabled;
  final bool loading;

  const CommonBottomButton({
    super.key,
    required this.title,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = !enabled || loading;

    final Color bgColor = isDisabled
        ? Colors.grey.shade200 // ✅ 비활성(연한 회색)
        : Colors.lightBlue.shade100; // ✅ 활성(연한 하늘색)

    final Color textColor = isDisabled ? Colors.grey.shade500 : Colors.black87;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: bgColor,
        ),
        child: Center(
          child: loading
              ? const CupertinoActivityIndicator()
              : Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
