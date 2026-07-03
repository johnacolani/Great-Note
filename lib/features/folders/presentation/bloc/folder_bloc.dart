import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:greate_note_app/features/folders/data/datasources/folder_local_datasource.dart';

import 'folder_event.dart';

part 'folder_state.dart';

class FolderBloc extends Bloc<FolderEvent, FolderState> {
  final FolderLocalDataSource localDataSource;
  final List<Map<String, dynamic>> _allFolders =
      []; // Keep all folders for search

  FolderBloc(this.localDataSource) : super(FolderLoading()) {
    // Event to load folders
    on<LoadFolders>((event, emit) async {
      emit(FolderLoading());
      try {
        // Fetch folders from the local data source
        final folders = await localDataSource.getFolders();

        // Make a mutable copy of the folders list
        final sortedFolders = List<Map<String, dynamic>>.from(folders);

        // Sort the folders alphabetically by name with null safety
        sortedFolders.sort((a, b) {
          final nameA = (a['name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });

        // Emit the sorted folders
        emit(FolderLoaded(sortedFolders));
      } catch (e) {
        debugPrint('Error in FolderBloc loading folders: $e');
        emit(const FolderError('Failed to load folders'));
      }
    });

    // Event to add a folder
    on<AddFolder>((event, emit) async {
      try {
        await localDataSource.insertFolder({
          'name': event.name,
          'color': event.color,
          'createdAt':
              event.createdAt.toIso8601String(), // Format timestamp as string
        });
        add(LoadFolders()); // Trigger a reload of the folders
      } catch (e, stacktrace) {
        debugPrint('Error adding folder: $e');
        debugPrint('Stacktrace: $stacktrace');
        emit(const FolderError('Failed to add folder'));
      }
    });
    // Event to delete a folder
    on<DeleteFolder>((event, emit) async {
      try {
        await localDataSource.deleteFolder(event.id);
        // After deleting, reload the folders
        add(LoadFolders());
      } catch (e) {
        emit(const FolderError('Failed to delete folder'));
      }
    });
    on<UpdateFolderName>((event, emit) async {
      try {
        await localDataSource.updateFolderName(event.folderId, event.newName);
        // Reload folders after updating the folder name
        add(LoadFolders());
      } catch (e) {
        emit(const FolderError('Failed to update folder name'));
      }
    });
    on<UpdateFolderColor>((event, emit) async {
      try {
        await localDataSource.updateFolderColor(event.folderId, event.newColor);
        // Reload folders after updating the folder color
        add(LoadFolders());
      } catch (e) {
        emit(const FolderError('Failed to update folder color'));
      }
    });
    // Event to search folders
    on<SearchFolders>((event, emit) {
      if (event.query.isEmpty) {
        // Restore the original list if the search query is empty
        emit(FolderLoaded(_allFolders));
      } else {
        // Filter the list based on the query
        final filteredFolders = _allFolders.where((folder) {
          final name = folder['name'].toLowerCase();
          return name.contains(event.query.toLowerCase());
        }).toList();
        emit(FolderLoaded(filteredFolders));
      }
    });
  }
}
