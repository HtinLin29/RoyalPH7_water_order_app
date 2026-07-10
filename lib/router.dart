import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/order.dart';
import 'models/verify_email_args.dart';
import 'providers/auth_provider.dart';
import 'router/page_transitions.dart';
import 'screens/admin/admin_chat_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/customer/address_screen.dart';
import 'screens/customer/cart_screen.dart';
import 'screens/customer/chat_screen.dart';
import 'screens/customer/home_screen.dart';
import 'screens/customer/order_confirmation_screen.dart';
import 'screens/customer/order_detail_screen.dart';
import 'screens/customer/order_history_screen.dart';
import 'screens/customer/order_tracking_screen.dart';
import 'screens/customer/product_detail_screen.dart';
import 'screens/customer/profile_screen.dart';
import 'screens/driver/driver_history_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/driver_order_detail_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/customer_shell.dart';
import 'widgets/driver_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _customerShellKey = GlobalKey<NavigatorState>();
final _driverShellKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' ||
          location == '/register' ||
          location == '/verify-email';
      final isSplash = location == '/splash';

      if (isSplash) return null;

      if (session == null) {
        return isAuthRoute ? null : '/login';
      }

      if (isAuthRoute) {
        if (location == '/register' || location == '/verify-email') {
          return null;
        }
        return _homeRouteForRole(authProvider.currentProfile?.role);
      }

      if (authProvider.isLoading) return null;

      final profile = authProvider.currentProfile;
      if (profile == null) return '/login';

      final roleHome = _homeRouteForRole(profile.role);
      if (roleHome == null) return '/login';

      if (!_isRouteAllowedForRole(location, profile.role)) {
        return roleHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            fadeSlidePage(child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            fadeSlidePage(child: const RegisterScreen()),
      ),
      GoRoute(
        path: '/verify-email',
        pageBuilder: (context, state) {
          final args = state.extra as VerifyEmailArgs?;
          if (args == null) {
            return fadeSlidePage(child: const LoginScreen());
          }
          return fadeSlidePage(
            child: VerifyEmailScreen(
              email: args.email,
              fullName: args.fullName,
              phone: args.phone,
            ),
          );
        },
      ),
      ShellRoute(
        navigatorKey: _customerShellKey,
        builder: (context, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(
            path: '/customer/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/customer/orders',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrderHistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/customer/chat',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CustomerChatScreen(),
            ),
          ),
          GoRoute(
            path: '/customer/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/product/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return fadeSlidePage(child: ProductDetailScreen(productId: id));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/cart',
        pageBuilder: (context, state) =>
            fadeSlidePage(child: const CartScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/addresses',
        pageBuilder: (context, state) =>
            fadeSlidePage(child: const AddressScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/orders/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return fadeSlidePage(child: OrderDetailScreen(orderId: id));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/confirmation',
        pageBuilder: (context, state) {
          final order = state.extra as Order;
          return fadeSlidePage(child: OrderConfirmationScreen(order: order));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/tracking/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return fadeSlidePage(child: OrderTrackingScreen(orderId: id));
        },
      ),
      ShellRoute(
        navigatorKey: _driverShellKey,
        builder: (context, state, child) => DriverShell(child: child),
        routes: [
          GoRoute(
            path: '/driver/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DriverHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/driver/history',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DriverHistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/driver/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/driver/orders/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return fadeSlidePage(child: DriverOrderDetailScreen(orderId: id));
        },
      ),
      GoRoute(
        path: '/admin/panel',
        pageBuilder: (context, state) =>
            fadeSlidePage(child: const AdminPanelScreen()),
      ),
      GoRoute(
        path: '/admin/chat/:customerId',
        pageBuilder: (context, state) {
          final customerId = state.pathParameters['customerId']!;
          return fadeSlidePage(
            child: AdminChatScreen(customerId: customerId),
          );
        },
      ),
      GoRoute(
        path: '/admin/profile',
        pageBuilder: (context, state) =>
            fadeSlidePage(child: const ProfileScreen()),
      ),
    ],
  );
}

String? _homeRouteForRole(String? role) {
  switch (role) {
    case 'customer':
      return '/customer/home';
    case 'driver':
      return '/driver/home';
    case 'admin':
      return '/admin/panel';
    default:
      return null;
  }
}

bool _isRouteAllowedForRole(String location, String role) {
  switch (role) {
    case 'customer':
      return location.startsWith('/customer');
    case 'driver':
      return location.startsWith('/driver');
    case 'admin':
      return location.startsWith('/admin');
    default:
      return false;
  }
}
