import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Sync status banner shown when offline or pending writes exist
class SyncStatusBanner extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;

  const SyncStatusBanner({
    super.key,
    required this.isOnline,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline && pendingCount == 0) return const SizedBox.shrink();

    final isOffline = !isOnline;
    final hasPending = pendingCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isOffline ? AppColors.warning.withValues(alpha: 0.15) : AppColors.info.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: isOffline ? AppColors.warning.withValues(alpha: 0.3) : AppColors.info.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.cloud_off_rounded : Icons.sync_rounded,
            size: 18,
            color: isOffline ? AppColors.warning : AppColors.info,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOffline
                  ? 'You\'re offline. Changes will sync when connected.'
                  : '$pendingCount change${pendingCount > 1 ? 's' : ''} pending sync...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isOffline ? AppColors.warning : AppColors.info,
              ),
            ),
          ),
          if (hasPending && !isOffline)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
              ),
            ),
        ],
      ),
    );
  }
}
