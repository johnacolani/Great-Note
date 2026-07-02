import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:greate_note_app/core/widgets/glossy_app_bar.dart';
import 'package:greate_note_app/features/app_background/app_background.dart';
import 'package:greate_note_app/features/notes/presentation/screens/note_edit_page.dart';
import 'package:greate_note_app/features/notes/data/data_sources/note_local_datasource.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_state.dart';

class SearchResultsPage extends StatelessWidget {
  final String query;
  final NoteLocalDataSource noteLocalDataSource;

  const SearchResultsPage({
    super.key,
    required this.query,
    required this.noteLocalDataSource,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlossyAppBar(
        title: 'Search Results',
        backgroundColor: Colors.transparent,
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
          BlocBuilder<SearchBloc, SearchState>(
            builder: (context, state) {
              if (state is SearchLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is SearchLoaded) {
                return _buildSearchResults(context, state, isDarkMode);
              } else if (state is SearchError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              } else {
                return const Center(
                  child: Text('Start searching to see results'),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, SearchLoaded state, bool isDarkMode) {
    if (state.notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No notes found for "${state.query}"',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search: "${state.query}"',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.notes.length} notes found',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Notes section
        if (state.notes.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Notes (${state.notes.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final note = state.notes[index];
                return _buildNoteItem(context, note, isDarkMode);
              },
              childCount: state.notes.length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoteItem(BuildContext context, Map<String, dynamic> note, bool isDarkMode) {
    final description = _parseDescription(note['description'] ?? '');
    final truncatedDescription = description.length > 100 
        ? '${description.substring(0, 100)}...' 
        : description;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        elevation: 2,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue,
            child: const Icon(Icons.note, color: Colors.white),
          ),
          title: Text(
            note['title'] ?? 'Untitled',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'In folder: ${note['folder_name']}',
                style: TextStyle(
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[600],
                  fontSize: 12,
                ),
              ),
              if (truncatedDescription.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  truncatedDescription,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            size: 16,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteEditPage(
                  folderId: note['folder_id'],
                  noteId: note['id'],
                  initialTitle: note['title'] ?? '',
                  initialDescription: note['description'] ?? '',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _parseDescription(String description) {
    if (description.isEmpty) return '';
    
    try {
      // Try to parse as Quill JSON
      final parsed = jsonDecode(description);
      if (parsed is List) {
        final buffer = StringBuffer();
        for (final op in parsed) {
          if (op['insert'] != null) {
            buffer.write(op['insert'].toString());
          }
        }
        return buffer.toString().trim();
      } else {
        return description.trim();
      }
    } catch (e) {
      // If not JSON, treat as plain text
      return description.trim();
    }
  }
}
