import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:greate_note_app/core/theme/theme_bloc.dart';
import 'package:greate_note_app/features/app_background/bloc/background_bloc.dart';
import 'package:greate_note_app/features/app_background/data/data_source/background_local_data_source.dart';
import 'package:greate_note_app/features/search/data/search_local_datasource.dart';
import 'package:greate_note_app/features/search/presentation/bloc/search_bloc.dart';
import 'package:greate_note_app/features/splash_feature/presentation/screens/bloc/splash_bloc.dart';
import 'package:greate_note_app/features/splash_feature/presentation/screens/splash_screen.dart';
import 'package:sqflite/sqflite.dart';

import 'core/database/app_database.dart';
import 'core/storage/app_paths.dart';
import 'features/folders/presentation/bloc/folder_bloc.dart';
import 'features/folders/presentation/bloc/folder_event.dart';
import 'features/notes/data/data_sources/note_local_datasource.dart';
import 'features/notes/presentation/bloc/note_bloc.dart';
import 'features/folders/data/datasources/folder_local_datasource.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    await MobileAds.instance.initialize();
  }

  // Cache storage paths (documents dir + note images folder) for sync access.
  await AppPaths.init();

  try {
    // Initialize the database
    final Database db = await AppDatabase().database;

    // Create the data sources
    final FolderLocalDataSource folderLocalDataSource =
        FolderLocalDataSource(db);
    final NoteLocalDataSource noteLocalDataSource = NoteLocalDataSource(db);
    final SearchLocalDataSource searchLocalDataSource =
        SearchLocalDataSource(db);
    final backgroundLocalDataSource = BackgroundLocalDataSource(db);

    // Create the background bloc instance once
    final backgroundBloc = BackgroundBloc(backgroundLocalDataSource);

    runApp(BlocProvider.value(
      value: backgroundBloc,
      child: MyApp(
        folderLocalDataSource: folderLocalDataSource,
        noteLocalDataSource: noteLocalDataSource,
        searchLocalDataSource: searchLocalDataSource,
        backgroundLocalDataSource: backgroundLocalDataSource,
        backgroundBloc: backgroundBloc,
      ),
    ));
  } catch (e) {
    debugPrint("Error initializing app: $e");
    // Show error screen if initialization fails
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to initialize app'),
                const SizedBox(height: 8),
                Text('Error: $e', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final FolderLocalDataSource folderLocalDataSource;
  final NoteLocalDataSource noteLocalDataSource;
  final SearchLocalDataSource searchLocalDataSource;
  final BackgroundLocalDataSource backgroundLocalDataSource;
  final BackgroundBloc backgroundBloc;

  MyApp({
    super.key,
    required this.folderLocalDataSource,
    required this.noteLocalDataSource,
    required this.searchLocalDataSource,
    required this.backgroundLocalDataSource,
    required this.backgroundBloc,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ThemeBloc(),
        ),
        BlocProvider(
          create: (context) => SplashBloc(),
        ),
        BlocProvider(
          create: (context) =>
              FolderBloc(folderLocalDataSource)..add(LoadFolders()),
        ),
        BlocProvider(
          create: (context) => NoteBloc(noteLocalDataSource),
        ),
        BlocProvider(
          create: (context) => SearchBloc(searchLocalDataSource),
        ),
        BlocProvider.value(
          value: backgroundBloc,
        ),
      ],
      child: Builder(
        builder: (context) {
          // Trigger background loading when the app starts
          backgroundBloc.add(LoadBackgroundEvent());

          return BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Folder and Notes App',
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: state.themeMode,
                localizationsDelegates: const [
                  ...FlutterQuillLocalizations.localizationsDelegates,
                ],
                supportedLocales: FlutterQuillLocalizations.supportedLocales,
                home: SplashScreen(noteLocalDataSource: noteLocalDataSource),
              );
            },
          );
        },
      ),
    );
  }

  final ThemeData lightTheme = ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.blueGrey.shade500),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.black),
        bodyLarge: TextStyle(color: Colors.black),
      ),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          iconTheme: IconThemeData(color: Colors.white)));

  final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blueGrey,
    scaffoldBackgroundColor: Colors.black,
    iconTheme: const IconThemeData(color: Colors.blueGrey),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
      bodyLarge: TextStyle(color: Colors.white),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      iconTheme: IconThemeData(color: Colors.white),
    ),
  );
}
