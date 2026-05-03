import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/local_portal_screen.dart';
import 'package:brisconnect/screens/visitor_portal_screen.dart';

class LogoAppBarTitle extends StatelessWidget {
  final String title;
  final bool enableHomeNavigation;
  final WidgetBuilder? visitorHomeBuilder;
  final WidgetBuilder? localHomeBuilder;

  const LogoAppBarTitle(
    this.title, {
    super.key,
    this.enableHomeNavigation = true,
    this.visitorHomeBuilder,
    this.localHomeBuilder,
  });

  void _handleLogoTap(BuildContext context) {
    if (!enableHomeNavigation) {
      return;
    }

    try {
      if (VisitorAuth.isVisitorLoggedIn) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: visitorHomeBuilder ?? (_) => const VisitorPortalScreen(),
          ),
          (_) => false,
        );
        return;
      }

      if (LocalAuth.isLocalLoggedIn) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: localHomeBuilder ?? (_) => const LocalPortalScreen(),
          ),
          (_) => false,
        );
      }
    } catch (_) {
      // Keep this tap handler fail-safe to prevent app crashes from navigation edge cases.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _handleLogoTap(context),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              'assets/logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}