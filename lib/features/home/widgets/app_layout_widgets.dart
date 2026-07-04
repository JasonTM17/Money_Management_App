import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class AppScrollView extends StatelessWidget {
  const AppScrollView({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom +
            AppTheme.bottomNavigationHeight +
            24,
      ),
      children: children,
    );
  }
}
