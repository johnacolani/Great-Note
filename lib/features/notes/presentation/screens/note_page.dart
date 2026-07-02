import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:greate_note_app/core/widgets/glossy_app_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../app_background/app_background.dart';
import '../../../folders/presentation/bloc/folder_bloc.dart';
import '../../../folders/presentation/bloc/folder_event.dart';
import '../../../../core/widgets/custom_floating_action_button.dart';
import '../bloc/note_bloc.dart';
import 'note_edit_page.dart';
import 'package:pdf/widgets.dart' as pw;

class NotePage extends StatefulWidget {
  final int folderId;
  final String folderName;

  const NotePage({super.key, required this.folderId, required this.folderName});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late String _folderName;
  final Set<int> _expandedNotes = {};
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredNotes = [];
  List<Map<String, dynamic>> _allNotes = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _folderName = widget.folderName;
    // FIXED: Load notes once in initState instead of in build()
    context.read<NoteBloc>().add(LoadNotes(folderId: widget.folderId));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterNotes(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredNotes = _allNotes;
      });
      return;
    }

    setState(() {
      _filteredNotes = _allNotes.where((note) {
        final title = (note['title'] ?? '').toString().toLowerCase();
        final description = parseDescription(note['description']).toLowerCase();
        final searchQuery = query.toLowerCase();

        return title.contains(searchQuery) || description.contains(searchQuery);
      }).toList();
    });
  }

  void shareAsText(BuildContext context, String title, String description) {
    final contentToShare = "Title: $title\n\nDescription:\n$description";
    Share.share(contentToShare, subject: title);
  }

  Future<void> shareAsPdf(
      BuildContext context, String title, String description) async {
    try {
      final pdf = pw.Document();

      // Add content to PDF
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Title: $title",
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Text("Description:",
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text(description, style: pw.TextStyle(fontSize: 12)),
              ],
            );
          },
        ),
      );

      // Save the PDF to a temporary directory
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/note.pdf");
      await file.writeAsBytes(await pdf.save());

      // Add Print Option in Share as PDF
      Printing.sharePdf(
        bytes: await pdf.save(),
        filename: "note.pdf",
      );
    } catch (e) {
      debugPrint("Error creating or sharing PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to share the note as a PDF.")),
      );
    }
  }

  void showShareOptions(
      BuildContext context, String title, String description) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Share as Text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.text_fields, size: 30),
                      onPressed: () {
                        Navigator.pop(context); // Close the modal
                        shareAsText(context, title, description);
                      },
                    ),
                    const Text('Share as Text'),
                  ],
                ),
                // Share as PDF
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, size: 30),
                      onPressed: () {
                        Navigator.pop(context); // Close the modal
                        shareAsPdf(context, title, description);
                      },
                    ),
                    const Text('Share as PDF'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> printNote(
      BuildContext context, String title, String description) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final pdf = pw.Document();

          // Add content to the PDF
          pdf.addPage(
            pw.Page(
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Title: $title",
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 16),
                    pw.Text("Description:",
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text(description, style: pw.TextStyle(fontSize: 12)),
                  ],
                );
              },
            ),
          );

          // Return the PDF as bytes
          return pdf.save();
        },
      );
    } catch (e) {
      debugPrint("Error during printing: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Unable to print the note. Please try again.")),
      );
    }
  }

  ImageProvider? _imageProviderFromSource(BuildContext context, String imageSource) {
    final source = imageSource.trim();
    if (source.startsWith('data:') && source.contains(',')) {
      final base64Part = source.split(',').last;
      return MemoryImage(base64Decode(base64Part));
    }
    return null;
  }

  // Build note content with embedded images and formatting
  Widget _buildNoteContent(String description, ThemeData theme) {
    try {
      final decoded = jsonDecode(description);
      if (decoded is! List) {
        throw const FormatException('Note content is not a Quill delta');
      }

      final doc = quill.Document.fromJson(List<dynamic>.from(decoded));
      final controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      controller.readOnly = true;

      return IgnorePointer(
        child: quill.QuillEditor.basic(
          controller: controller,
          config: quill.QuillEditorConfig(
            scrollable: false,
            expands: false,
            padding: EdgeInsets.zero,
            enableInteractiveSelection: false,
            embedBuilders: kIsWeb
                ? FlutterQuillEmbeds.editorWebBuilders(
                    imageEmbedConfig: QuillEditorImageEmbedConfig(
                      imageProviderBuilder: _imageProviderFromSource,
                    ),
                  )
                : FlutterQuillEmbeds.editorBuilders(
                    imageEmbedConfig: QuillEditorImageEmbedConfig(
                      imageProviderBuilder: _imageProviderFromSource,
                    ),
                  ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error parsing note description: $e");
      return Text(
        description,
        style: theme.textTheme.bodyMedium,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: GlossyAppBar(
        backgroundColor: Colors.transparent,
        title: _folderName,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterNotes('');
                }
              });
            },
            tooltip: _isSearching ? 'Close Search' : 'Search Notes',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _showEditFolderDialog(context);
            },
            tooltip: 'Edit Folder Name',
          ),
        ],
        elevation: 0,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          Container(
            color: isDarkMode
                ? Colors.black.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
          BlocBuilder<NoteBloc, NoteState>(
            builder: (context, state) {
              if (state is NoteLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is NotesLoaded) {
                // Update notes lists
                if (_allNotes != state.notes) {
                  _allNotes = state.notes;
                  _filteredNotes = _searchController.text.isEmpty
                      ? state.notes
                      : _filteredNotes;
                }

                final notesToDisplay = _searchController.text.isEmpty
                    ? state.notes
                    : _filteredNotes;

                if (notesToDisplay.isEmpty) {
                  return SafeArea(
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No notes yet'
                                : 'No matching notes found',
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
                            _searchController.text.isEmpty
                                ? 'Tap + to add your first note'
                                : 'Try a different search term',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SafeArea(
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      top: _isSearching ? 80 : 8,
                      bottom: 16,
                      left: 8,
                      right: 8,
                    ),
                    itemCount: notesToDisplay.length,
                    itemBuilder: (context, index) {
                      final ScrollController noteScrollController =
                          ScrollController();

                      final note = notesToDisplay[index];
                      final isExpanded = _expandedNotes.contains(note['id']);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Card(
                          color: theme.cardColor,
                          elevation: 10,
                          child: Column(
                            children: [
                              ListTile(
                                title: Text(
                                  note['title'],
                                  style: theme.textTheme.bodyLarge,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isExpanded)
                                      IconButton(
                                        icon: Icon(Icons.edit,
                                            color: theme.iconTheme.color),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  NoteEditPage(
                                                folderId: widget.folderId,
                                                noteId: note['id'],
                                                initialTitle: note['title'],
                                                initialDescription:
                                                    note['description'],
                                                initialScrollOffset:
                                                    noteScrollController
                                                            .hasClients
                                                        ? noteScrollController
                                                                .offset -
                                                            30
                                                        : 0.0,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: theme.iconTheme.color,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (isExpanded) {
                                            _expandedNotes.remove(note['id']);
                                          } else {
                                            _expandedNotes.add(note['id']);
                                          }
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete,
                                          color: theme.iconTheme.color),
                                      onPressed: () {
                                        _showDeleteConfirmationDialog(
                                            context, note['id']);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Theme.of(context).platform ==
                                                TargetPlatform.iOS
                                            ? CupertinoIcons.share
                                            : Icons.share,
                                        color: theme.iconTheme.color,
                                      ),
                                      onPressed: () {
                                        final noteTitle =
                                            note['title'] ?? "Untitled Note";
                                        final noteDescription =
                                            parseDescription(
                                                note['description']);

                                        // Trigger the sharing options modal
                                        showShareOptions(context, noteTitle,
                                            noteDescription);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (isExpanded)
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.8,
                                  child: SingleChildScrollView(
                                    controller: noteScrollController,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Description:",
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          if (note['description'] != null &&
                                              note['description'].isNotEmpty)
                                            _buildNoteContent(
                                                note['description'], theme)
                                          else
                                            Text(
                                              'No description available.',
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              } else if (state is NoteError) {
                return Center(
                  child: Text(state.message, style: theme.textTheme.bodyLarge),
                );
              } else {
                return const Center(child: Text('No notes found'));
              }
            },
          ),
          // Search bar - only visible when _isSearching is true
          if (_isSearching)
            Positioned(
              top: 10,
              left: MediaQuery.of(context).size.width * 0.03,
              right: MediaQuery.of(context).size.width * 0.03,
              child: SafeArea(
                child: Container(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.7),
                          width: 1.0,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        cursorColor: Colors.grey.shade400,
                        decoration: InputDecoration(
                          hintText: 'Search notes by title or content...',
                          hintStyle: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterNotes('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (query) {
                          _filterNotes(query);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: GlossyRectangularButton(
        onPressed: () {
          _showAddNoteDialog(context);
        },
        icon: Icons.add,
      ),
    );
  }

  String parseDescription(String? description) {
    if (description == null || description.isEmpty) {
      return "No description available.";
    }

    try {
      // Check if the description starts as a JSON object
      if (description.startsWith('{') || description.startsWith('[')) {
        final decoded = jsonDecode(description);

        if (decoded is List<dynamic>) {
          return decoded
              .map((op) => op['insert']?.toString().trim() ?? "")
              .join()
              .trim();
        } else if (decoded is Map<String, dynamic> && decoded['ops'] is List) {
          return (decoded['ops'] as List<dynamic>)
              .map((op) => op['insert']?.toString().trim() ?? "")
              .join()
              .trim();
        } else {
          return "Invalid description format.";
        }
      } else {
        // Treat as plain text if not JSON
        return description.trim();
      }
    } catch (e) {
      debugPrint("Error parsing description: $e");
      return "Error parsing description.";
    }
  }

  // Method to show a dialog for editing the folder name
  void _showEditFolderDialog(BuildContext context) {
    final folderNameController = TextEditingController(text: _folderName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFDEFEEEA),
          title: const Text('Edit Folder Name'),
          content: TextFormField(
            controller: folderNameController,
            decoration: const InputDecoration(labelText: 'Folder Name'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                String newFolderName = folderNameController.text.trim();
                if (newFolderName.isNotEmpty) {
                  // Capitalize the first letter of the folder name
                  newFolderName = newFolderName[0].toUpperCase() +
                      newFolderName.substring(1);
                  // Update the folder name in the Bloc
                  context.read<FolderBloc>().add(UpdateFolderName(
                        folderId: widget.folderId,
                        newName: newFolderName,
                      ));
                  setState(() {
                    _folderName =
                        newFolderName; // Update the folder name locally
                  });
                  Navigator.of(context).pop(); // Close the dialog
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmationDialog(BuildContext context, int noteId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Note'),
          content: const Text('Are you sure you want to delete this note?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              onPressed: () {
                context.read<NoteBloc>().add(DeleteNote(
                      noteId: noteId,
                      folderId: widget.folderId,
                    ));
                Navigator.of(context).pop(); // Close dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Show dialog to add a new note
  void _showAddNoteDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFDEFEEEA),
          title: const Text(
            'Add Note',
            style: TextStyle(color: Colors.blueGrey),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Colors.grey, width: 2.0),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Colors.blueGrey, width: 2.0),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.grey.shade500)),
              ),
              // TextFormField(
              //   controller: descriptionController,
              //   decoration: const InputDecoration(labelText: 'Description'),
              // ),
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
                String title = titleController.text.trim();

                // FIXED: Validate title before accessing first character
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a note title'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                // Capitalize first letter
                title = title[0].toUpperCase() + title.substring(1);
                final description = descriptionController.text.trim();

                context.read<NoteBloc>().add(
                      AddNote(
                        folderId: widget.folderId,
                        title: title,
                        description: description,
                      ),
                    );
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }
}

