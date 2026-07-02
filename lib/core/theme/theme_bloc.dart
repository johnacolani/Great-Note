import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(ThemeState(themeMode: _getInitialTheme())) {
    on<ToggleThemeEvent>((event, emit) {
      final isLight = state.themeMode == ThemeMode.light;
      emit(ThemeState(themeMode: isLight ? ThemeMode.dark : ThemeMode.light));
    });
  }
// Method to get initial theme based on current time
  static ThemeMode _getInitialTheme() {
    final hour = TimeOfDay.now().hour;
    return (hour >= 6 && hour < 18) ? ThemeMode.light : ThemeMode.dark;
  }
}
