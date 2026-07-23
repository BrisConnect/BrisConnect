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
  bool _handledDenied = false;
  late final Future<bool> _roleFuture =
      RoleAccessService.hasAnyRole(widget.allowedRoles);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allowed = snapshot.data ?? false;
        if (allowed) {
          return widget.child;
        }

        if (!_handledDenied) {
          _handledDenied = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.deniedMessage)),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
              (route) => false,
            );
          });
        }

        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
