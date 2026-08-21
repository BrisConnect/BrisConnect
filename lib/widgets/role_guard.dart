import 'dart:async';

import 'package:flutter/material.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/services/role_access_service.dart';

class RoleGuard extends StatefulWidget {
  final Set<AppUserRole> allowedRoles;
  final Widget child;
  final String deniedMessage;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.deniedMessage = 'Access denied.',
  });

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  late Future<bool> _checkFuture;

  @override
  void initState() {
    super.initState();
    _checkFuture = _checkRole();
  }

  Future<bool> _checkRole() async {
    try {
      final allowed = await RoleAccessService.hasAnyRole(widget.allowedRoles)
          .timeout(const Duration(seconds: 3));
      if (allowed) return true;

      // On a page refresh the Flutter app restarts and Firebase Auth restores
      // the cached user asynchronously from IndexedDB. Keep polling so the user
      // stays on the current URL instead of being bounced back to a login screen.
      // TODO: Optimize role check - currently can hang on Firestore queries
      const maxAttempts = 10; // Reduced from 60 for faster failure
      for (var i = 0; i < maxAttempts; i++) {
        final delayMs = 500 + (i * 150).clamp(0, 1000);
        await Future.delayed(Duration(milliseconds: delayMs));
        try {
          final retry = await RoleAccessService.hasAnyRole(widget.allowedRoles)
              .timeout(const Duration(seconds: 2));
          if (retry) return true;
        } on TimeoutException {
          continue; // Try next attempt
        }
      }
      return false;
    } on TimeoutException {
      return false;
    }
  }

  void _retry() {
    setState(() {
      _checkFuture = _checkRole();
    });
  }

  void _goToWelcome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkFuture,
      builder: (context, snapshot) {
        final allowed = snapshot.data ?? false;
        if (allowed) {
          return widget.child;
        }

        // Still checking or polling: show a loading state on the current route.
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Session could not be restored. Stay on this URL and show a manual
        // recovery screen instead of auto-redirecting to the old login page.
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Session expired',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We could not restore your session after refreshing. '
                      'Please log in again to continue.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _goToWelcome,
                          child: const Text('Log in'),
                        ),
                        OutlinedButton(
                          onPressed: _retry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
