import 'package:flutter/material.dart';

class GlossyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final bool centerTitle;

  const GlossyAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.centerTitle = true, required Color backgroundColor, required int elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // BackdropFilter to apply the blur effect
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
           // bottom: Radius.circular(16), // Rounded bottom corners
          ),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3), // Glossy effect with opacity
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(0), // Same rounded corners
              ),

            ),
          ),
        ),
        // The actual AppBar content
        AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff3a3932) // Dark mode background
              :  const Color(0xff989586), // Light mode background
          elevation: 0, // No shadow
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.6), // Adjust text color based on theme
            ),
          ),
          actions: actions,
          centerTitle: centerTitle,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
