import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

/// The app's one branded loading treatment -- a spinner centered inside a
/// soft tinted circle, same visual language as [EmptyState]'s icon circle,
/// instead of a bare `CircularProgressIndicator` floating on blank white.
/// Used everywhere a screen needs a full-area "loading" placeholder.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppGradients.tint(context.colors.primary),
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            valueColor: AlwaysStoppedAnimation(context.colors.primary),
          ),
        ),
      ),
    );
  }
}
