import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:greate_note_app/core/storage/note_image_storage.dart';
import 'package:greate_note_app/core/widgets/glossy_app_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../bloc/note_bloc.dart';

class NoteEditPage extends StatefulWidget {
  final int folderId;
  final int noteId;
  final String initialTitle;
  final String initialDescription; // This should be the Quill Delta JSON string
  final double initialScrollOffset;

  const NoteEditPage({
    super.key,
    required this.folderId,
    required this.noteId,
    required this.initialTitle,
    required this.initialDescription,
    this.initialScrollOffset = 0,
  });

  @override
  _NoteEditPageState createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  late TextEditingController _titleController;
  late ScrollController _scrollController;
  late FocusNode _editorFocusNode;

  QuillController _quillController = QuillController.basic();
  bool _isImagesPreviewExpanded = true; // Track if images preview is expanded

  // Autosave state.
  NoteBloc? _noteBloc;
  Timer? _autosaveTimer;
  bool _isDirty = false;
  late String _lastSavedJson;
  late String _lastSavedTitle;

  @override
  void initState() {
    super.initState();
    _scrollController =
        ScrollController(initialScrollOffset: widget.initialScrollOffset);
    _editorFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Now safe to interact with the widget
    });
    _titleController = TextEditingController(text: widget.initialTitle);

    // Load the initialDescription from Quill JSON if available
    if (widget.initialDescription.isNotEmpty) {
      try {
        final List<dynamic> content =
            jsonDecode(widget.initialDescription) as List<dynamic>;
        final doc = quill.Document.fromJson(
            content); // Initialize document from decoded content
        _quillController = quill.QuillController(
            document: doc, selection: const TextSelection.collapsed(offset: 0));
      } catch (e) {
        debugPrint("Error decoding Quill JSON: $e");
        _quillController = quill.QuillController
            .basic(); // Fallback to empty document if decoding fails
      }
    } else {
      _quillController = quill.QuillController.basic();
    }

    // Capture the bloc so autosave can run during dispose (context is gone by
    // then). NoteBloc lives at the app level, so it stays alive across pages.
    _noteBloc = context.read<NoteBloc>();
    _lastSavedJson =
        jsonEncode(_quillController.document.toDelta().toJson());
    _lastSavedTitle = widget.initialTitle.trim();

    // Autosave whenever the title or note body changes.
    _titleController.addListener(_scheduleAutosave);
    _quillController.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    // Flush any pending changes before tearing the page down.
    _autosaveTimer?.cancel();
    _titleController.removeListener(_scheduleAutosave);
    _quillController.removeListener(_scheduleAutosave);
    if (_isDirty) _performAutosave();

    _titleController.dispose();
    _quillController.dispose();
    _scrollController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  // Debounce: save ~0.9s after the user stops typing.
  void _scheduleAutosave() {
    _isDirty = true;
    _autosaveTimer?.cancel();
    _autosaveTimer =
        Timer(const Duration(milliseconds: 900), _performAutosave);
  }

  // Persist the current title + body without leaving the page.
  void _performAutosave() {
    final title = _titleController.text.trim();
    // Don't autosave a note with no title (avoids wiping the title while typing).
    if (title.isEmpty) return;

    final json = jsonEncode(_quillController.document.toDelta().toJson());
    // Skip redundant writes (e.g. cursor-only movements with no real change).
    if (json == _lastSavedJson && title == _lastSavedTitle) return;

    _noteBloc?.add(
      UpdateNote(
        noteId: widget.noteId,
        folderId: widget.folderId,
        title: title,
        description: json,
      ),
    );
    _lastSavedJson = json;
    _lastSavedTitle = title;
    _isDirty = false;
  }

  // Image picker methods
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _insertImageToNote(image);
      }
    } catch (e) {
      debugPrint("Error picking image from gallery: $e");
      _showSnackBar("Failed to pick image from gallery");
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        await _insertImageToNote(image);
      }
    } catch (e) {
      debugPrint("Error picking image from camera: $e");
      _showSnackBar("Failed to take photo");
    }
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  ImageProvider? _imageProviderFromSource(BuildContext context, String imageSource) {
    return NoteImageStorage.providerFor(context, imageSource);
  }

  Future<void> _insertImageToNote(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final mimeType = image.mimeType ?? _guessMimeType(image.name);
      // Store the image as a file and embed a lightweight reference instead of
      // a large base64 blob (keeps the note/DB small and backup-friendly).
      final imageRef = await NoteImageStorage.saveImage(
        bytes,
        mimeType: mimeType,
        nameHint: image.name,
      );

      final selection = _quillController.selection;
      final index = selection.baseOffset < 0
          ? _quillController.document.length
          : selection.baseOffset;
      final length = selection.extentOffset - selection.baseOffset;

      _quillController.replaceText(
        index,
        length < 0 ? 0 : length,
        quill.BlockEmbed.image(imageRef),
        null,
      );

      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + 1),
        ChangeSource.local,
      );

      _showSnackBar('Image inserted');
    } catch (e) {
      debugPrint("Error inserting image: $e");
      _showSnackBar("Failed to add image: ${e.toString()}");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Get full image path from filename
  Future<String?> _getImagePath(String fileName) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/$fileName';
    } catch (e) {
      return null;
    }
  }

  // Show image gallery with all images in the note
  void _showImageGallery() async {
    final text = _quillController.document.toPlainText();
    final imagePattern = RegExp(r'ðŸ“· ([^\n]+)');
    final matches = imagePattern.allMatches(text);

    if (matches.isEmpty) {
      _showSnackBar("No images found in this note");
      return;
    }

    final imageFiles = <String>[];
    for (final match in matches) {
      final fileName = match.group(1)?.trim();
      if (fileName != null) {
        final imagePath = await _getImagePath(fileName);
        if (imagePath != null && File(imagePath).existsSync()) {
          imageFiles.add(imagePath);
        }
      }
    }

    if (imageFiles.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageGalleryScreen(
            imagePaths: imageFiles,
          ),
        ),
      );
    } else {
      _showSnackBar("No valid images found");
    }
  }

  // Build custom editor that shows both text and images
  Widget _buildCustomEditor() {
    return quill.QuillEditor.basic(
      controller: _quillController,
      scrollController: _scrollController,
      focusNode: _editorFocusNode,
      config: quill.QuillEditorConfig(
        expands: true,
        padding: EdgeInsets.zero,
        scrollBottomInset: MediaQuery.of(context).viewInsets.bottom + 24,
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
    );
  }

  // Build images preview section with collapse/expand
  Widget _buildImagesPreview() {
    final plainText = _quillController.document.toPlainText();
    final imagePattern = RegExp(r'ðŸ“· ([^\n]+)');
    final matches = imagePattern.allMatches(plainText);

    final imageFiles = <String>[];
    for (final match in matches) {
      final fileName = match.group(1)?.trim();
      if (fileName != null) {
        imageFiles.add(fileName);
      }
    }

    if (imageFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isImagesPreviewExpanded ? 220 : 50,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.grey.shade100,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: _isImagesPreviewExpanded
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with collapse button (down arrow)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Images in this note:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isImagesPreviewExpanded = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Theme.of(context).iconTheme.color,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: imageFiles.length,
                      itemBuilder: (context, index) {
                        return _buildImageWidgetInEditor(imageFiles[index]);
                      },
                    ),
                  ),
                ),
              ],
            )
          : Center(
              // Collapsed state - show expand button (up arrow)
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isImagesPreviewExpanded = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Images in this note (${imageFiles.length})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: Theme.of(context).iconTheme.color,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Build image widget for editor with delete button
  Widget _buildImageWidgetInEditor(String fileName) {
    return FutureBuilder<String?>(
      future: _getImagePath(fileName),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final imagePath = snapshot.data!;
          if (File(imagePath).existsSync()) {
            return Container(
              width: 200,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 50),
                          ),
                        );
                      },
                    ),
                  ),
                  // Delete button - positioned on top right corner
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        debugPrint("Delete button tapped for image: $fileName");
                        _deleteImage(fileName);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Delete image from document
  void _deleteImage(String fileName) {
    try {
      debugPrint("Attempting to delete image: $fileName");

      // Escape special regex characters in fileName
      final escapedFileName = fileName.replaceAllMapped(
        RegExp(r'[.*+?^${}()|[\]\\]'),
        (match) => '\\${match.group(0)}',
      );

      // Try different patterns to find the image reference
      final patterns = [
        RegExp('\\nðŸ“· $escapedFileName\\n'), // With newlines
        RegExp('ðŸ“· $escapedFileName\\n'), // With trailing newline
        RegExp('\\nðŸ“· $escapedFileName'), // With leading newline
        RegExp('ðŸ“· $escapedFileName'), // Without newlines
      ];

      final plainText = _quillController.document.toPlainText();
      debugPrint("Document plain text length: ${plainText.length}");
      debugPrint("Looking for: ðŸ“· $fileName");

      RegExp? matchingPattern;
      for (final pattern in patterns) {
        if (pattern.hasMatch(plainText)) {
          matchingPattern = pattern;
          debugPrint("Found image with pattern: ${pattern.pattern}");
          break;
        }
      }

      if (matchingPattern == null) {
        _showSnackBar("Image not found in document");
        debugPrint("Image pattern not found in document");
        return;
      }

      // Find and remove the image reference from document operations
      final delta = _quillController.document.toDelta();
      final operations = List<Map<String, dynamic>>.from(delta.toJson());
      final newOperations = <Map<String, dynamic>>[];
      bool found = false;

      for (final op in operations) {
        final insert = op['insert'];
        if (insert is String && !found) {
          // Check if this string contains the image reference
          final textMatch = matchingPattern.firstMatch(insert);

          if (textMatch != null) {
            // Found the image reference, remove it
            final beforeText = insert.substring(0, textMatch.start);
            final afterText = insert.substring(textMatch.end);
            final newText = beforeText + afterText;

            debugPrint(
                "Removing image reference from text: ${textMatch.group(0)}");

            // Only add if there's text left
            if (newText.isNotEmpty) {
              final newOp = <String, dynamic>{'insert': newText};
              if (op.containsKey('attributes')) {
                newOp['attributes'] = op['attributes'];
              }
              newOperations.add(newOp);
            }
            found = true;
          } else {
            // Keep the operation as-is
            newOperations.add(Map<String, dynamic>.from(op));
          }
        } else {
          // Keep non-text operations
          newOperations.add(Map<String, dynamic>.from(op));
        }
      }

      if (found) {
        // Rebuild document without the image reference
        final newDoc = quill.Document.fromJson(newOperations);
        final currentSelection = _quillController.selection;

        // Dispose old controller
        _quillController.dispose();

        // Create new controller
        _quillController = quill.QuillController(
          document: newDoc,
          selection: currentSelection.baseOffset > newDoc.length
              ? const TextSelection.collapsed(offset: 0)
              : currentSelection,
        );

        setState(() {}); // Rebuild to update UI
        _showSnackBar("Image removed from note");
        debugPrint("Image successfully removed from document");

        // Delete the file from storage
        _getImagePath(fileName).then((imagePath) {
          if (imagePath != null && File(imagePath).existsSync()) {
            try {
              File(imagePath).deleteSync();
              debugPrint("Image file deleted from storage: $imagePath");
            } catch (e) {
              debugPrint("Error deleting image file: $e");
            }
          }
        });
      } else {
        _showSnackBar("Image reference not found in document");
        debugPrint("Image reference not found in operations");
      }
    } catch (e, stackTrace) {
      debugPrint("Error deleting image: $e");
      debugPrint("Stack trace: $stackTrace");
      _showSnackBar("Failed to delete image: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: GlossyAppBar(
        title: 'Edit Note',
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
            tooltip: 'Save Note',
          ),
        ],
        backgroundColor: isDarkMode
            ? Colors.blueGrey.withValues(alpha: 0.3)
            : Colors.blue.withValues(alpha: 0.3),
        elevation: 0,
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Title input with improved styling
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: TextFormField(
                controller: _titleController,
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: theme.textTheme.bodyMedium,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                ),
              ),
            ),
            // Editor area
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: _buildCustomEditor(),
              ),
            ),
            // Rich Text Toolbar with improved design
            Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      quill.QuillToolbarHistoryButton(
                        isUndo: true,
                        controller: _quillController,
                        options: const QuillToolbarHistoryButtonOptions(
                          iconData: Icons.undo,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarHistoryButton(
                        isUndo: false,
                        controller: _quillController,
                        options: const QuillToolbarHistoryButtonOptions(
                          iconData: Icons.redo,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.bold,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.format_bold,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.italic,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.format_italic,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.underline,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.format_underline,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarClearFormatButton(
                        controller: _quillController,
                        options: const QuillToolbarClearFormatButtonOptions(
                          iconData: Icons.format_clear,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarColorButton(
                        controller: _quillController,
                        isBackground: false,
                        options: const QuillToolbarColorButtonOptions(
                          iconData: Icons.color_lens,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarColorButton(
                        controller: _quillController,
                        isBackground: true,
                        options: const QuillToolbarColorButtonOptions(
                          iconData: Icons.format_color_fill,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarSelectHeaderStyleDropdownButton(
                        controller: _quillController,
                        options:
                            const QuillToolbarSelectHeaderStyleDropdownButtonOptions(
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarFontSizeButton(
                        controller: _quillController,
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.ol,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.format_list_numbered,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.ul,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.format_list_bulleted,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.leftAlignment,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.format_align_left,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.centerAlignment,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.format_align_center,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.rightAlignment,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.format_align_right,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.justifyAlignment,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.format_align_justify,
                          iconSize: 22,
                        ),
                      ),
                      quill.QuillToolbarToggleStyleButton(
                        attribute: quill.Attribute.codeBlock,
                        controller: _quillController,
                        options: const QuillToolbarToggleStyleButtonOptions(
                          iconData: Icons.code,
                          iconSize: 22,
                        ),
                      ),
                      IconButton(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library, size: 22),
                        tooltip: 'Add image from gallery',
                      ),
                      IconButton(
                        onPressed: _pickImageFromCamera,
                        icon: const Icon(Icons.camera_alt, size: 22),
                        tooltip: 'Take photo with camera',
                      ),
                      IconButton(
                        onPressed: () {
                          _editorFocusNode.requestFocus();
                          _showSnackBar('Images are now embedded in the note');
                        },
                        icon: const Icon(Icons.image, size: 22),
                        tooltip: 'Images are embedded directly in the note',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Method to save the updated note
  void _saveNote() {
    final updatedTitle = _titleController.text.trim();

    // Serialize the Quill document into JSON (Delta format)
    final updatedDescription =
        jsonEncode(_quillController.document.toDelta().toJson());

    if (updatedTitle.isNotEmpty && updatedDescription.isNotEmpty) {
      context.read<NoteBloc>().add(
            UpdateNote(
              noteId: widget.noteId,
              folderId: widget.folderId,
              title: updatedTitle,
              description:
                  updatedDescription, // Save Quill JSON format as a string
            ),
          );
      // Mark clean so dispose() doesn't fire a duplicate autosave.
      _lastSavedJson = updatedDescription;
      _lastSavedTitle = updatedTitle;
      _isDirty = false;
      Navigator.of(context).pop(); // Go back after saving
    }
  }
}

// Image Viewer Screen
class ImageViewerScreen extends StatelessWidget {
  final String imagePath;
  final String fileName;

  const ImageViewerScreen({
    super.key,
    required this.imagePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          fileName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              _showDeleteDialog(context);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 100, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Image not found',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: const Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                try {
                  File(imagePath).deleteSync();
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close image viewer
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image deleted successfully')),
                  );
                } catch (e) {
                  Navigator.of(context).pop(); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete image')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

// Image Gallery Screen
class ImageGalleryScreen extends StatefulWidget {
  final List<String> imagePaths;

  const ImageGalleryScreen({
    super.key,
    required this.imagePaths,
  });

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Image ${_currentIndex + 1} of ${widget.imagePaths.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              _showDeleteDialog(context);
            },
          ),
        ],
      ),
      body: PageView.builder(
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.imagePaths.length,
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              child: Image.file(
                File(widget.imagePaths[index]),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image,
                            size: 100, color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Image not found',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: const Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                try {
                  File(widget.imagePaths[_currentIndex]).deleteSync();
                  Navigator.of(context).pop(); // Close dialog

                  // Remove from list
                  setState(() {
                    widget.imagePaths.removeAt(_currentIndex);
                    if (_currentIndex >= widget.imagePaths.length) {
                      _currentIndex = widget.imagePaths.length - 1;
                    }
                  });

                  // If no images left, go back
                  if (widget.imagePaths.isEmpty) {
                    Navigator.of(context).pop();
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image deleted successfully')),
                  );
                } catch (e) {
                  Navigator.of(context).pop(); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete image')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}


