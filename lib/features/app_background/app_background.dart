import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/background_bloc.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackgroundBloc, BackgroundState>(
      builder: (context, state) {
        if (state is BackgroundLoaded) {
          final source = state.imageSource;
          if (source.startsWith('data:') && source.contains(',')) {
            final bytes = base64Decode(source.split(',').last);
            return Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: MemoryImage(bytes),
                  fit: BoxFit.cover,
                ),
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: kIsWeb ? NetworkImage(source) : FileImage(File(source)),
                fit: BoxFit.cover,
              ),
            ),
          );
        } else {
          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/pure_background.png'),
                fit: BoxFit.cover,
              ),
            ),
          );
        }
      },
    );
  }
}
