import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}