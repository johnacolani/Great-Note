import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:greate_note_app/core/backup/backup_service.dart';
import 'package:greate_note_app/core/theme/theme_bloc.dart';
import 'package:greate_note_app/core/widgets/custom_floating_action_button.dart';
import 'package:greate_note_app/core/widgets/glossy_app_bar.dart';
import 'package:greate_note_app/features/app_background/bloc/background_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app_background/app_background.dart';
import '../../../notes/data/data_sources/note_local_datasource.dart';
import '../../../search/presentation/bloc/search_bloc.dart';
import '../../../search/presentation/bloc/search_event.dart';
import '../../../search/presentation/bloc/search_state.dart';
import '../../../notes/presentation/bloc/note_bloc.dart';
import '../../../notes/presentation/screens/note_page.dart';
import '../bloc/folder_bloc.dart';
import '../bloc/folder_event.dart';

class FolderPage extends StatefulWidget {
  final NoteLocalDataSource
      noteLocalDataSource; // Pass the data source to check notes
  const FolderPage({super.key, required this.noteLocalDataSource});

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  final TextEditingController _searchController = TextEditingController();

  // BannerAd? _bannerAd;
  // bool _isAdLoaded = false;
  // final String adUnitId = Platform.isAndroid
  //     ? 'ca-app-pub-7380986533735423/1251591272' // Test ad unit for Android
  //     : 'ca-app-pub-7380986533735423/8992675455'; // Test ad unit for iOS

  @override
  void initState() {
    // _loadBannerAd();
    super.initState();
  }

  // void _loadBannerAd() {
  //   _bannerAd = BannerAd(
  //     adUnitId: adUnitId,
  //     size: AdSize.banner,
  //     request: const AdRequest(),
  //     listener: BannerAdListener(
  //       onAdLoaded: (ad) {
  //         setState(() {
  //           _isAdLoaded = true; // Ad successfully loaded
  //         });
  //         debugPrint('Banner ad loaded successfully.');
  //       },
  //       onAdFailedToLoad: (ad, error) {
  //         debugPrint('Failed to load banner ad: ${error.responseInfo}');
  //         ad.dispose(); // Dispose of the ad object
  //         // Retry loading the ad after a delay
  //         Future.delayed(const Duration(seconds: 10), () {
  //           _loadBannerAd();
  //         });
  //       },
  //     ),
  //   )..load(); // Load the banner ad
  // }

  @override
  void dispose() {
    // _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlossyAppBar(
        title: 'Folder Page',
//'Folder Page $screenWidth',

        actions: [
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              // Show moon icon for dark mode and sun icon for light mode
              return IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    state.themeMode == ThemeMode.dark
                        ? Icons.nights_stay_outlined // Moon icon for dark mode
                        : Icons.wb_sunny, // Sun icon for light mode
                    key: ValueKey(state.themeMode),
                  ),
                ),
                onPressed: () {
                  // Toggle the theme when the button is pressed
                  context.read<ThemeBloc>().add(ToggleThemeEvent());
                },
              );
            },
          ),
          IconButton(
              onPressed: () {
                _showBackgroundSelectionDialog(context);
              },
              icon: const Icon(Icons.image)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Backup & Restore',
            onSelected: (value) {
              if (value == 'export') {
                _exportBackup(context);
              } else if (value == 'export_notes') {
                _exportNotesZip(context);
              } else if (value == 'save') {
                _saveBackupFile(context);
              } else if (value == 'import') {
                _importBackup(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.backup_outlined),
                  title: Text('Backup (export ZIP)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'save',
                child: ListTile(
                  leading: Icon(Icons.save_alt),
                  title: Text('Save backup file'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'export_notes',
                child: ListTile(
                  leading: Icon(Icons.note_alt_outlined),
                  title: Text('Export notes as ZIP'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('Restore (import ZIP)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow
      ),
      body: Stack(
        children: [
          const AppBackground(),
          Container(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height * 0.11,
              left: MediaQuery.of(context).size.width * 0.03,
              right: MediaQuery.of(context).size.width * 0.03,
            ),
            child: BlocListener<NoteBloc, NoteState>(
              listenWhen: (previous, current) =>
                  current is NotesLoaded || current is NoteError,
              listener: (context, state) {
                if (mounted) {
                  setState(() {});
                }
              },
              child: BlocBuilder<FolderBloc, FolderState>(
                builder: (context, state) {
                if (state is FolderLoading) {
                  // Shimmer loading effect
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: getCrossAxisCount(screenWidth),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    itemCount: 6, // Show 6 skeleton cards
                    itemBuilder: (context, index) {
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey.withValues(alpha: 0.3),
                                Colors.grey.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else if (state is FolderLoaded) {
                  // Show empty state if no folders
                  if (state.folders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 80,
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No folders yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to create your first folder',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: getCrossAxisCount(screenWidth),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16),
                    itemCount: state.folders.length,
                    itemBuilder: (context, index) {
                      final folder = state.folders[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => NotePage(
                                  folderId: folder['id'],
                                  folderName: folder['name'],
                                  folderColor: folder['color']?.toString()),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            // BackdropFilter to apply the blur effect
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  16), // Same border radius as the container
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 15.0,
                                    sigmaY: 15.0), // Blurry effect
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                      color: Colors.white.withValues(
                                          alpha:
                                              0.2), // Semi-transparent color overlay
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // The actual folder card content

                            buildCard(folder, context),
                          ],
                        ),
                      );
                    },
                  );
                } else if (state is FolderError) {
                  return Center(child: Text(state.message));
                } else {
                  return const Center(child: Text('No folders found'));
                }
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.01,
                left: MediaQuery.of(context).size.width * 0.03,
                right: MediaQuery.of(context).size.width * 0.03,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    10.0), // Rounded corners for the effect
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.1) // Dark mode color
                        : Colors.white
                            .withValues(alpha: 0.4), // Light mode color
                    borderRadius:
                        BorderRadius.circular(10.0), // Rounded corners
                    border: Border.all(
                      color:
                          Colors.white.withValues(alpha: 0.7), // Subtle border
                      width: 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black, // Adjust text color for theme
                    ),
                    cursorColor: Colors.grey.shade400,
                    decoration: InputDecoration(
                      hintText: 'Search notes across all folders...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade300
                            : Colors
                                .grey.shade700, // Adjust hint color for theme
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade300
                            : Colors
                                .grey.shade700, // Adjust icon color for theme
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none, // No visible border
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Cancel search',
                              icon: const Icon(Icons.cancel),
                              onPressed: () {
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                                context.read<SearchBloc>().add(const ClearSearch());
                                setState(() {});
                                context.read<FolderBloc>().add(LoadFolders());
                              },
                            )
                          : null,
                    ),
                    onChanged: (query) {
                      final trimmed = query.trim();
                      if (trimmed.isEmpty) {
                        context.read<SearchBloc>().add(const ClearSearch());
                        context.read<FolderBloc>().add(LoadFolders());
                      } else {
                        context.read<SearchBloc>().add(
                              SearchNotesOnly(query: trimmed),
                            );
                      }
                      setState(() {});
                    },
                    onSubmitted: (query) {
                      final trimmed = query.trim();
                      if (trimmed.isEmpty) {
                        context.read<SearchBloc>().add(const ClearSearch());
                        context.read<FolderBloc>().add(LoadFolders());
                        return;
                      }
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_searchController.text.trim().isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.11 + 68,
              left: MediaQuery.of(context).size.width * 0.03,
              right: MediaQuery.of(context).size.width * 0.03,
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  return _buildLiveSearchPanel(context, state, isDarkMode);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: Row(
        children: [
          Expanded(
            flex: 3,
            child: Visibility(
              // visible: _isAdLoaded,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Container(
                height: 60,
                decoration: const BoxDecoration(
                    // color: Colors.yellow.withOpacity(0.5),
                    borderRadius:
                        BorderRadius.only(topRight: Radius.circular(24))),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 60,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: GlossyRectangularButton(
              onPressed: () {
                _showAddFolderDialog(context);
              },
              icon: Icons.add,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCard(Map<String, dynamic> folder, BuildContext context) {
    final createdAt = folder['createdAt'] as DateTime; // Extract timestamp
    final formattedDate = DateFormat.yMMMd().add_jm().format(createdAt);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          color: Color(int.parse(folder['color']))
              .withValues(alpha: 0.5), // Semi-transparent folder color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          folder['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkResponse(
                        onTap: () async {
                          await _confirmAndDeleteFolder(context, folder);
                        },
                        radius: 20,
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: widget.noteLocalDataSource
                              .getNotesForFolder(folder['id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            } else if (snapshot.hasError) {
                              return const Center(
                                child: Text(
                                  'Error loading notes',
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            } else if (!snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              return const Center(
                                child: Text(
                                  'ADD NOTE',
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            } else {
                              final notes = snapshot.data!;
                              return ListView.builder(
                                primary: false,
                                physics: const ClampingScrollPhysics(),
                                itemCount: notes.length,
                                itemBuilder: (context, index) {
                                  final note = notes[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.7),
                                        borderRadius:
                                            BorderRadius.circular(4.0),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Text(
                                          note['title']?.toString() ??
                                              'Untitled',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveSearchPanel(
    BuildContext context,
    SearchState state,
    bool isDarkMode,
  ) {
    final query = _searchController.text.trim();

    Widget child;
    if (state is SearchLoading) {
      child = const Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (state is SearchLoaded && state.query == query) {
      if (state.notes.isEmpty) {
        child = const Center(
          child: Text('No matching notes found'),
        );
      } else {
        child = ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: state.notes.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: isDarkMode ? Colors.white12 : Colors.black12,
          ),
          itemBuilder: (context, index) {
            final note = state.notes[index];
            return ListTile(
              dense: true,
              leading: Icon(
                Icons.note_alt_outlined,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              title: Text(
                note['title']?.toString() ?? 'Untitled',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                note['folder_name']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NotePage(
                      folderId: note['folder_id'],
                      folderName: note['folder_name']?.toString() ?? 'Folder',
                      initialSearchQuery: query,
                      initialExpandedNoteId: note['id'],
                    ),
                  ),
                );
              },
            );
          },
        );
      }
    } else {
      child = const Center(
        child: Text('Type to search notes'),
      );
    }

    return Material(
      elevation: 12,
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.35,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: child,
          ),
        ),
      ),
    );
  }

  int getCrossAxisCount(double screenWidth) {
    if (screenWidth >= 1200) {
      return 4; // For very large screens (e.g., large tablets or desktop)
    } else if (screenWidth >= 700) {
      return 3; // For tablets and larger phones in landscape
    } else if (screenWidth >= 300) {
      return 2; // For regular phones in portrait or smaller tablets
    } else {
      return 1; // For small devices
    }
  }

  // Export all folders, notes, images and background as a ZIP and share it.
  Future<void> _exportBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing backup…')),
    );
    try {
      final service = BackupService(widget.noteLocalDataSource.db);
      final result = await service.exportBackup();

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              result.bytes,
              name: result.fileName,
              mimeType: 'application/zip',
            ),
          ],
          fileNameOverrides: [result.fileName],
          subject: 'Great Note backup',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  Future<void> _saveBackupFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing backup file…')),
    );
    try {
      final service = BackupService(widget.noteLocalDataSource.db);
      final result = await service.exportBackup();

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save Great Note backup',
        fileName: result.fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: result.bytes,
      );

      if (!context.mounted) return;
      if (savedPath == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Backup save cancelled.')),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Backup saved to: $savedPath')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _exportNotesZip(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing notes export ZIP…')),
    );
    try {
      final service = BackupService(widget.noteLocalDataSource.db);
      final result = await service.exportNotesZip();

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save notes export ZIP',
        fileName: result.fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: result.bytes,
      );

      if (!context.mounted) return;
      if (savedPath == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Notes export cancelled.')),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Notes exported to: $savedPath')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Notes export failed: $e')),
      );
    }
  }

  // Pick a backup ZIP and (after confirmation) replace all local data with it.
  Future<void> _importBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final bytes = picked.files.first.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will REPLACE all current folders, notes, images and the '
          'background with the contents of the backup. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Blocking loader while restoring.
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = BackupService(widget.noteLocalDataSource.db);
      await service.importBackupReplace(bytes);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loader

      // Reload folders and background from the restored data.
      context.read<FolderBloc>().add(LoadFolders());
      context.read<BackgroundBloc>().add(LoadBackgroundEvent());

      messenger.showSnackBar(
        const SnackBar(content: Text('Backup restored successfully.')),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop(); // dismiss loader
      messenger.showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  // Method to confirm and delete the folder if empty
  Future<void> _confirmAndDeleteFolder(
      BuildContext context, Map<String, dynamic> folder) async {
    final folderId = folder['id'] as int;
    final folderName = (folder['name'] ?? '').toString();

    // First check if the folder contains any notes
    final hasNotes =
        await widget.noteLocalDataSource.hasNotesInFolder(folderId);

    if (!context.mounted) return;
    if (hasNotes) {
      // If the folder contains notes, show a message and prevent deletion
      _showAlertDialog(context, 'Cannot Delete',
          'This folder contains notes and cannot be deleted.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final folderBloc = context.read<FolderBloc>();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Folder'),
          content:
              Text('Are you sure you want to delete the folder "$folderName"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Cancel the deletion
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(true); // Confirm the deletion
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Proceed to delete the folder if confirmed
      folderBloc.add(DeleteFolder(id: folderId));

      // Offer an Undo (re-creates the empty folder with its colour + date).
      final color = (folder['color'] ?? '').toString();
      final createdAt = folder['createdAt'];
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted folder "$folderName"'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              folderBloc.add(AddFolder(
                name: folderName,
                color: color,
                createdAt: createdAt is DateTime ? createdAt : null,
              ));
            },
          ),
        ),
      );
    }
  }

  // Helper method to show an alert dialog
  void _showAlertDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }
}

// Method to show the Add Folder dialog
void _showAddFolderDialog(BuildContext context) {
  final folderNameController = TextEditingController();
  Color selectedColor = Colors.blue; // Default color

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white30.withValues(alpha: 0.8),
              title: const Text('Add Folder'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: folderNameController,
                    maxLines: 1,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(
                            color: Colors.blue, // Border color when not focused
                            width: 2.0,
                          ),
                        ),
                        labelText: 'Folder Name',
                        labelStyle: const TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Select Color:'),
                  // Scrollable color options
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(width: 2, color: Colors.grey),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 4.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _colorOption(Colors.red, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.red;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.green, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.green;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.blue, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.blue;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.yellow, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.yellow;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.purple, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.purple;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.orange, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.orange;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.pink, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.pink;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.teal, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.teal;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.brown, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.brown;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.cyan, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.cyan;
                              });
                            }),
                            const SizedBox(
                              width: 6,
                            ),
                            _colorOption(Colors.indigo, selectedColor, () {
                              setState(() {
                                selectedColor = Colors.indigo;
                              });
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Add'),
                  onPressed: () {
                    String folderName = folderNameController.text.trim();
                    if (folderName.isNotEmpty) {
                      // Capitalize the first letter of the folder name
                      folderName =
                          folderName[0].toUpperCase() + folderName.substring(1);

                      // Store the color as an integer value
                      context.read<FolderBloc>().add(
                            AddFolder(
                              name: folderName,
                              color: selectedColor
                                  .toARGB32()
                                  .toString(), // Store color as int value string
                            ),
                          );
                      Navigator.of(context)
                          .pop(); // Close dialog after adding folder
                    }
                  },
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

// Widget to display color options
Widget _colorOption(Color color, Color selectedColor, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: selectedColor == color
            ? Border.all(color: Colors.black, width: 3)
            : null,
      ),
    ),
  );
}

// Show dialog to choose between camera and gallery for background
void _showBackgroundSelectionDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Change Background'),
        content: const Text('Choose how you want to set your background:'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context
                  .read<BackgroundBloc>()
                  .add(ChangeBackgroundFromGalleryEvent());
            },
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context
                  .read<BackgroundBloc>()
                  .add(ChangeBackgroundFromCameraEvent());
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}
