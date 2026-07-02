import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../data/data_source/background_local_data_source.dart';

part 'background_event.dart';
part 'background_state.dart';

class BackgroundBloc extends Bloc<BackgroundEvent, BackgroundState> {
  final BackgroundLocalDataSource backgroundDataSource;

  BackgroundBloc(this.backgroundDataSource) : super(BackgroundInitial()) {
    on<ChangeBackgroundEvent>((event, emit) async {
      // This event now shows a dialog to choose between camera and gallery
      // The actual implementation will be handled in the UI layer
    });

    on<ChangeBackgroundFromGalleryEvent>((event, emit) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        try {
          final imageSource = await _normalizeImageSource(pickedFile);
          await backgroundDataSource.saveBackgroundImage(imageSource);
          emit(BackgroundLoaded(imageSource));
        } catch (e) {
          emit(BackgroundError('Failed to save background: ${e.toString()}'));
        }
      } else {
        emit(BackgroundError('No image selected'));
      }
    });

    on<ChangeBackgroundFromCameraEvent>((event, emit) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        try {
          final imageSource = await _normalizeImageSource(pickedFile);
          await backgroundDataSource.saveBackgroundImage(imageSource);
          emit(BackgroundLoaded(imageSource));
        } catch (e) {
          emit(BackgroundError('Failed to take photo: ${e.toString()}'));
        }
      } else {
        emit(BackgroundError('No photo taken'));
      }
    });

    on<LoadBackgroundEvent>((event, emit) async {
      try {
        final imagePath = await backgroundDataSource.getBackgroundImage();
        if (imagePath != null) {
          emit(BackgroundLoaded(imagePath));
        } else {
          emit(BackgroundInitial());
        }
      } catch (e) {
        emit(BackgroundError('Failed to load background: ${e.toString()}'));
      }
    });
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  Future<String> _normalizeImageSource(XFile pickedFile) async {
    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      final mimeType = pickedFile.mimeType ?? _guessMimeType(pickedFile.name);
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }

    return pickedFile.path;
  }
}
