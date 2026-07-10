import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../providers/connectivity_provider.dart';

class ConnectivityBanner extends StatelessWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: connectivity.bannerState ==
                      ConnectivityBannerState.hidden
                  ? 0
                  : null,
              child: connectivity.bannerState ==
                      ConnectivityBannerState.hidden
                  ? const SizedBox.shrink()
                  : _BannerContent(state: connectivity.bannerState),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _BannerContent extends StatelessWidget {
  final ConnectivityBannerState state;

  const _BannerContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final isOffline = state == ConnectivityBannerState.offline;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      color: isOffline ? AppColors.error : AppColors.success,
      padding: EdgeInsets.fromLTRB(8, topPadding + 6, 8, 6),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.wifi_off : Icons.wifi,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isOffline ? 'No internet connection' : 'Connected',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          if (isOffline) ...[
            const Spacer(),
            Text(
              'Reconnecting...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
