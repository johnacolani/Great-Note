import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../data/search_local_datasource.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchLocalDataSource searchDataSource;

  SearchBloc(this.searchDataSource) : super(const SearchInitial()) {
    // Handle search all event
    on<SearchAll>((event, emit) async {
      if (event.query.trim().isEmpty) {
        emit(const SearchInitial());
        return;
      }

      emit(const SearchLoading());
      
      try {
        final results = await searchDataSource.searchAll(event.query.trim());
        
        emit(SearchLoaded(
          folders: results['folders'] ?? [],
          notes: results['notes'] ?? [],
          query: event.query.trim(),
        ));
        
        debugPrint('Global search for "${event.query}" found ${results['folders']?.length ?? 0} folders and ${results['notes']?.length ?? 0} notes');
      } catch (e, stackTrace) {
        debugPrint('Error during global search: $e');
        debugPrint('Stack trace: $stackTrace');
        emit(const SearchError(message: 'Failed to search. Please try again.'));
      }
    });

    // Handle clear search event
    on<ClearSearch>((event, emit) {
      emit(const SearchInitial());
    });

    // Handle search folders only
    on<SearchFoldersOnly>((event, emit) async {
      if (event.query.trim().isEmpty) {
        emit(const SearchInitial());
        return;
      }

      emit(const SearchLoading());
      
      try {
        final folders = await searchDataSource.searchFolders(event.query.trim());
        
        emit(SearchLoaded(
          folders: folders,
          notes: [],
          query: event.query.trim(),
        ));
        
        debugPrint('Folder search for "${event.query}" found ${folders.length} folders');
      } catch (e, stackTrace) {
        debugPrint('Error during folder search: $e');
        debugPrint('Stack trace: $stackTrace');
        emit(const SearchError(message: 'Failed to search folders. Please try again.'));
      }
    });

    // Handle search notes only
    on<SearchNotesOnly>((event, emit) async {
      if (event.query.trim().isEmpty) {
        emit(const SearchInitial());
        return;
      }

      emit(const SearchLoading());
      
      try {
        final notes = await searchDataSource.searchNotes(event.query.trim());
        
        emit(SearchLoaded(
          folders: [],
          notes: notes,
          query: event.query.trim(),
        ));
        
        debugPrint('Note search for "${event.query}" found ${notes.length} notes');
      } catch (e, stackTrace) {
        debugPrint('Error during note search: $e');
        debugPrint('Stack trace: $stackTrace');
        emit(const SearchError(message: 'Failed to search notes. Please try again.'));
      }
    });
  }
}