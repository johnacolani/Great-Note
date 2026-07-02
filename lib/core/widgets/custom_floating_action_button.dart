import 'dart:ui';
import 'package:flutter/material.dart';

class GlossyRectangularButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon; // Icon for the button

  const GlossyRectangularButton({
    required this.onPressed,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // BackdropFilter for blur effect behind the button
        ClipRRect(
          borderRadius: BorderRadius.circular(16), // Rounded corners for the blur effect
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // Blurry effect
            child: Container(
              width: 60, // Custom width for the rectangular button
              height: 60, // Custom height for the rectangular button
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2), // Semi-transparent overlay
                borderRadius: BorderRadius.circular(16), // Match the border radius of the blur
                border: Border.all(
                  color: Colors.white, // White border
                  width: 2.0, // Border width
                ),
              ),
            ),
          ),
        ),
        // The custom button content
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 70, // Same size as the backdrop container
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3), // Glossy color effect
              borderRadius: BorderRadius.circular(16), // Rounded corners for the button
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2), // Soft shadow effect
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4), // Slight shadow below the button
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white,size: 32,), // Custom icon inside the button
          ),
        ),
      ],
    );
  }
}
