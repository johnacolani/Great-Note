import 'package:equatable/equatable.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object> get props => const [];
}

class SearchAll extends SearchEvent {
  final String query;

  const SearchAll({required this.query});

  @override
  List<Object> get props => [query];
}

class ClearSearch extends SearchEvent {
  const ClearSearch();
}

class SearchFoldersOnly extends SearchEvent {
  final String query;

  const SearchFoldersOnly({required this.query});

  @override
  List<Object> get props => [query];
}

class SearchNotesOnly extends SearchEvent {
  final String query;

  const SearchNotesOnly({required this.query});

  @override
  List<Object> get props => [query];
}
