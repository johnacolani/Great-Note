import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:greate_note_app/core/theme/theme_bloc.dart';
import 'package:greate_note_app/core/widgets/custom_floating_action_button.dart';
import 'package:greate_note_app/core/widgets/glossy_app_bar.dart';
import 'package:greate_note_app/features/app_background/bloc/background_bloc.dart';
import 'package:intl/intl.dart';
import '../../../app_background/app_background.dart';
import '../../../notes/data/data_sources/note_local_datasource.dart';
import '../../../search/presentation/bloc/search_bloc.dart';
import '../../../search/presentation/bloc/search_event.dart';
import '../../../search/presentation/screens/search_results_page.dart';
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
        ],
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow
      ),
      body: Stack(
        children: [
          const AppBackground(),
          Container(
            color: isDarkMode
                ? Colors.black.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height * 0.11,
              left: MediaQuery.of(context).size.width * 0.03,
              right: MediaQuery.of(context).size.width * 0.03,
            ),
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
                                  folderName: folder['name']),
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
                                      color: Colors.white.withOpacity(
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
                        ? Colors.white.withOpacity(0.1) // Dark mode color
                        : Colors.white.withOpacity(0.4), // Light mode color
                    borderRadius:
                        BorderRadius.circular(10.0), // Rounded corners
                    border: Border.all(
                      color: Colors.white.withOpacity(0.7), // Subtle border
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
                    ),
                    onChanged: (query) {},
                    onSubmitted: (query) {
                      final trimmed = query.trim();
                      if (trimmed.isEmpty) return;
                      context.read<SearchBloc>().add(SearchNotesOnly(query: trimmed));
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SearchResultsPage(
                            query: trimmed,
                            noteLocalDataSource: widget.noteLocalDataSource,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
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

  Stack buildCard(Map<String, dynamic> folder, BuildContext context) {
    final createdAt = folder['createdAt'] as DateTime; // Extract timestamp
    final formattedDate = DateFormat.yMMMd().add_jm().format(createdAt);

    return Stack(
      children: [
        Card(
          color: Color(int.parse(folder['color']))
              .withOpacity(0.5), // Semi-transparent folder color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title, date, and delete button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            folder['name'],
                            maxLines: 1, // Ensures the title is on one line
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () async {
                            await _confirmAndDeleteFolder(
                                context, folder['id'], folder['name']);
                          },
                        ),
                      ],
                    ),
                    // const SizedBox(height: 4),
                    Text(
                      formattedDate, // Display formatted timestamp
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                          0.2), // More transparency for the note container
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: FutureBuilder<List<Map<String, dynamic>>>(
                              future: widget.noteLocalDataSource
                                  .getNotesForFolder(folder['id']),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Align(
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      height: 30,
                                      width: 30,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return const Text('Error loading notes');
                                } else if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'ADD NOTE',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  );
                                  } else {
                                  final notes = snapshot.data!;
                                  return ListView.builder(
                                    primary: false,
                                    physics: const ClampingScrollPhysics(),
                                    itemCount: notes.length,
                                    padding: EdgeInsets.zero,
                                    itemBuilder: (context, index) {
                                      final note = notes[index];
                                      return Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.7),
                                              borderRadius:
                                                  BorderRadius.circular(4.0)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text(
                                              note['title'],
                                              style: const TextStyle(
                                                  color: Colors.black),
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  // Method to confirm and delete the folder if empty
  Future<void> _confirmAndDeleteFolder(
      BuildContext context, int folderId, String folderName) async {
    // First check if the folder contains any notes
    final hasNotes =
        await widget.noteLocalDataSource.hasNotesInFolder(folderId);

    if (hasNotes) {
      // If the folder contains notes, show a message and prevent deletion
      _showAlertDialog(context, 'Cannot Delete',
          'This folder contains notes and cannot be deleted.');
      return;
    }

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
      context.read<FolderBloc>().add(DeleteFolder(id: folderId));
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
              backgroundColor: Colors.white30.withOpacity(0.8),
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
                              color: selectedColor.value
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
