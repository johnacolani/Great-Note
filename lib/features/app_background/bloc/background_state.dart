part of 'background_bloc.dart';


abstract class BackgroundState {}

class BackgroundInitial extends BackgroundState {}

class BackgroundLoaded extends BackgroundState {
  final String imageSource; // File path on mobile/desktop, data URI on web

  BackgroundLoaded(this.imageSource);
}

class BackgroundError extends BackgroundState {
  final String message;

  BackgroundError(this.message);
}
