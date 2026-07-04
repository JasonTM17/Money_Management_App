import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class AppScrollView extends StatelessWidget {
  const AppScrollView({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 700 ? 28.0 : 20.0;
    final bottomPadding =
        MediaQuery.of(context).padding.bottom +
        AppTheme.bottomNavigationHeight +
        24;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        12,
        horizontalPadding,
        bottomPadding,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: children[index],
        ),
      ),
    );
  }
}
