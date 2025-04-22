import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';

enum AccessStatus { granted, denied, processing }

class AccessStatusAnimation extends StatelessWidget {
  final AccessStatus status;
  final double size;
  final String? message;
  final VoidCallback? onAnimationComplete;

  const AccessStatusAnimation({
    Key? key,
    required this.status,
    this.size = 200,
    this.message,
    this.onAnimationComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String animationAsset;
    Color backgroundColor;
    String defaultMessage;

    switch (status) {
      case AccessStatus.granted:
        animationAsset = 'assets/animations/access_granted.json';
        backgroundColor = AppTheme.successColor.withOpacity(0.1);
        defaultMessage = 'Access Granted';
        break;
      case AccessStatus.denied:
        animationAsset = 'assets/animations/access_denied.json';
        backgroundColor = AppTheme.errorColor.withOpacity(0.1);
        defaultMessage = 'Access Denied';
        break;
      case AccessStatus.processing:
        animationAsset = 'assets/animations/processing.json';
        backgroundColor = AppTheme.primaryColor.withOpacity(0.1);
        defaultMessage = 'Processing...';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // In a real app, you would use actual Lottie animations
          // For now, we'll use a placeholder
          SizedBox(
            width: size,
            height: size,
            child: status == AccessStatus.processing
                ? const CircularProgressIndicator()
                : Icon(
                    status == AccessStatus.granted ? Icons.check_circle : Icons.cancel,
                    size: size * 0.7,
                    color: status == AccessStatus.granted
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            message ?? defaultMessage,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: status == AccessStatus.granted
                  ? AppTheme.successColor
                  : status == AccessStatus.denied
                      ? AppTheme.errorColor
                      : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
