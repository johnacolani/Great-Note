import 'package:equatable/equatable.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object> get props => [];
}

// Initial state
class SearchInitial extends SearchState {
  const SearchInitial();
}

// Loading state
class SearchLoading extends SearchState {
  const SearchLoading();
}

// Search results loaded
class SearchLoaded extends SearchState {
  final List<Map<String, dynamic>> folders;
  final List<Map<String, dynamic>> notes;
  final String query;

  const SearchLoaded({
    required this.folders,
    required this.notes,
    required this.query,
  });

  @override
  List<Object> get props => [folders, notes, query];

  bool get hasResults => folders.isNotEmpty || notes.isNotEmpty;
  int get totalResults => folders.length + notes.length;
}

// Error state
class SearchError extends SearchState {
  final String message;

  const SearchError({required this.message});

  @override
  List<Object> get props => [message];
}