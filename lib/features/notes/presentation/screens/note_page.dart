import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:greate_note_app/core/storage/note_image_storage.dart';
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
  final String? folderColor;
  final String? initialSearchQuery;
  final int? initialExpandedNoteId;

  const NotePage({
    super.key,
    required this.folderId,
    required this.folderName,
    this.folderColor,
    this.initialSearchQuery,
    this.initialExpandedNoteId,
  });

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late String _folderName;
  String? _folderColor;
  late String _searchHighlightQuery;
  final Set<int> _expandedNotes = {};
  final Map<int, int> _activeSearchMatchIndexByNote = {};
  final Map<String, GlobalKey> _searchMatchKeys = {};
  final Set<String> _centeredSearchMatchTargets = {};
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredNotes = [];
  List<Map<String, dynamic>> _allNotes = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _folderName = widget.folderName;
    _folderColor = widget.folderColor;
    _searchHighlightQuery = widget.initialSearchQuery?.trim() ?? '';
    if (widget.initialExpandedNoteId != null) {
      _expandedNotes.add(widget.initialExpandedNoteId!);
    }
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

  // Build read-only note content, rendering embedded images (file refs or
  // legacy base64) via the shared image provider so it matches the editor.
  Widget _buildNoteContent(String description, ThemeData theme) {
    try {
      final List<dynamic> content = jsonDecode(description) as List<dynamic>;
      final doc = quill.Document.fromJson(content);
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
                      imageProviderBuilder: NoteImageStorage.providerFor,
                    ),
                  )
                : FlutterQuillEmbeds.editorBuilders(
                    imageEmbedConfig: QuillEditorImageEmbedConfig(
                      imageProviderBuilder: NoteImageStorage.providerFor,
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
                ? Colors.black.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
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
                                        _confirmDeleteNote(context, note);
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
                                          if (_searchHighlightQuery.isNotEmpty)
                                            _buildSearchMatchNavigator(
                                              noteId: note['id'] as int,
                                              description:
                                                  note['description'] ?? '',
                                              theme: theme,
                                            )
                                          else if (note['description'] != null &&
                                              note['description'].isNotEmpty)
                                            _buildNoteContent(
                                              note['description'],
                                              theme,
                                            )
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
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
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

  Widget _buildSearchMatchNavigator({
    required int noteId,
    required String description,
    required ThemeData theme,
  }) {
    final query = _searchHighlightQuery.trim();
    if (query.isEmpty) return const SizedBox.shrink();

    final plainText = parseDescription(description);
    final matches = _findSearchMatches(plainText, query);
    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeIndex =
        (_activeSearchMatchIndexByNote[noteId] ?? 0).clamp(0, matches.length - 1);
    final activeTargetKey = '$noteId:$activeIndex:$query';
    final activeMatchKey = _searchMatchKeyFor(activeTargetKey);

    if (!_centeredSearchMatchTargets.contains(activeTargetKey)) {
      _centeredSearchMatchTargets.add(activeTargetKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final targetContext = activeMatchKey.currentContext;
        if (targetContext == null) return;
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.45,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: activeIndex > 0
                  ? () {
                      final nextIndex = activeIndex - 1;
                      setState(() {
                        _activeSearchMatchIndexByNote[noteId] = nextIndex;
                      });
                      _scrollToSearchMatch(noteId, nextIndex, query);
                    }
                  : null,
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: 'Previous match',
            ),
            Text(
              'Match ${activeIndex + 1}/${matches.length}',
              style: theme.textTheme.titleSmall,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: activeIndex < matches.length - 1
                  ? () {
                      final nextIndex = activeIndex + 1;
                      setState(() {
                        _activeSearchMatchIndexByNote[noteId] = nextIndex;
                      });
                      _scrollToSearchMatch(noteId, nextIndex, query);
                    }
                  : null,
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Next match',
            ),
          ],
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          child: RichText(
            textAlign: TextAlign.start,
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
                height: 1.45,
              ),
              children: _buildHighlightedFullTextSpans(
                text: _descriptionToPlainText(description),
                query: query,
                activeMatchIndex: activeIndex,
                activeMatchKey: activeMatchKey,
                baseStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  GlobalKey _searchMatchKeyFor(String targetKey) {
    return _searchMatchKeys.putIfAbsent(targetKey, () => GlobalKey());
  }

  void _scrollToSearchMatch(int noteId, int matchIndex, String query) {
    final targetKey = '$noteId:$matchIndex:$query';
    final targetMatchKey = _searchMatchKeyFor(targetKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = targetMatchKey.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.45,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    });
  }

  List<String> _findSearchMatches(String text, String query) {
    if (text.isEmpty || query.isEmpty) return const [];

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matches = <String>[];
    var start = 0;
    const contextLength = 60;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) break;

      final snippetStart = (index - contextLength).clamp(0, text.length);
      final snippetEnd =
          (index + lowerQuery.length + contextLength).clamp(0, text.length);
      matches.add(text.substring(snippetStart, snippetEnd).trim());
      start = index + lowerQuery.length;
    }

    return matches;
  }

  List<InlineSpan> _buildHighlightedFullTextSpans({
    required String text,
    required String query,
    required int activeMatchIndex,
    required GlobalKey activeMatchKey,
    required TextStyle baseStyle,
  }) {
    if (query.trim().isEmpty || text.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;
    var matchIndex = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
        ));
      }

      final matchText = text.substring(index, index + query.length);
      final isActiveMatch = matchIndex == activeMatchIndex;
      final matchStyle = baseStyle.copyWith(
        backgroundColor: isActiveMatch
            ? Colors.amber.withValues(alpha: 0.6)
            : Colors.yellow.withValues(alpha: 0.35),
        fontWeight: FontWeight.w700,
      );

      if (isActiveMatch) {
        spans.add(
          WidgetSpan(
            child: Container(
              key: activeMatchKey,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                matchText,
                style: matchStyle,
              ),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: matchText,
            style: matchStyle,
          ),
        );
      }

      start = index + query.length;
      matchIndex++;
    }

    return spans;
  }

  String _descriptionToPlainText(String? description) {
    if (description == null || description.isEmpty) {
      return '';
    }

    try {
      if (description.startsWith('{') || description.startsWith('[')) {
        final decoded = jsonDecode(description);

        if (decoded is List<dynamic>) {
          return decoded.map((op) => op['insert']?.toString() ?? '').join();
        } else if (decoded is Map<String, dynamic> && decoded['ops'] is List) {
          return (decoded['ops'] as List<dynamic>)
              .map((op) => op['insert']?.toString() ?? '')
              .join();
        }
      }
      return description;
    } catch (e) {
      debugPrint('Error parsing plain text description: $e');
      return description;
    }
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

  // Available folder color swatches (kept in sync with the Add Folder dialog)
  static const List<Color> _folderColorOptions = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.brown,
    Colors.cyan,
    Colors.indigo,
  ];

  // Method to show a dialog for editing the folder name and color
  void _showEditFolderDialog(BuildContext context) {
    final folderNameController = TextEditingController(text: _folderName);

    // Parse the current color, falling back to blue if it's missing/invalid.
    Color selectedColor = Colors.blue;
    if (_folderColor != null) {
      final parsed = int.tryParse(_folderColor!);
      if (parsed != null) {
        selectedColor = Color(parsed);
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFDEFEEEA),
              title: const Text('Edit Folder'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: folderNameController,
                    decoration: const InputDecoration(labelText: 'Folder Name'),
                  ),
                  const SizedBox(height: 20),
                  const Text('Folder Color:'),
                  const SizedBox(height: 8),
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
                          children: [
                            for (final color in _folderColorOptions) ...[
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedColor = color;
                                  });
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                    border: selectedColor.value == color.value
                                        ? Border.all(
                                            color: Colors.black, width: 3)
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
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
                  child: const Text('Save'),
                  onPressed: () {
                    String newFolderName = folderNameController.text.trim();
                    if (newFolderName.isEmpty) return;

                    // Capitalize the first letter of the folder name
                    newFolderName = newFolderName[0].toUpperCase() +
                        newFolderName.substring(1);

                    final newColor = selectedColor.value.toString();

                    // Update the folder name in the Bloc
                    context.read<FolderBloc>().add(UpdateFolderName(
                          folderId: widget.folderId,
                          newName: newFolderName,
                        ));
                    // Update the folder color in the Bloc
                    context.read<FolderBloc>().add(UpdateFolderColor(
                          folderId: widget.folderId,
                          newColor: newColor,
                        ));

                    setState(() {
                      _folderName = newFolderName; // Update locally
                      _folderColor = newColor;
                    });
                    Navigator.of(context).pop(); // Close the dialog
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteNote(
      BuildContext context, Map<String, dynamic> note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete note?'),
          content: Text(
            'Delete "${(note['title'] ?? 'Untitled Note').toString()}"? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final noteBloc = context.read<NoteBloc>();

    // Capture the note data so it can be restored.
    final title = (note['title'] ?? '').toString();
    final description = (note['description'] ?? '').toString();

    noteBloc.add(DeleteNote(noteId: note['id'], folderId: widget.folderId));

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${title.isEmpty ? 'note' : title}"'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            noteBloc.add(AddNote(
              folderId: widget.folderId,
              title: title,
              description: description,
            ));
          },
        ),
      ),
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
