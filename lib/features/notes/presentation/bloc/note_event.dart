part of 'note_bloc.dart';


// Define base class for Note events
abstract class NoteEvent extends Equatable {
  const NoteEvent();

  @override
  List<Object> get props => [];
}

// Event to load notes for a specific folder
class LoadNotes extends NoteEvent {
  final int folderId;

  const LoadNotes({required this.folderId,});

  @override
  List<Object> get props => [folderId];
}

// Event to add a new note
class AddNote extends NoteEvent {
  final int folderId;
  final String title;
  final String description;

  const AddNote({
    required this.folderId,
    required this.title,
    required this.description,
  });

  @override
  List<Object> get props => [folderId, title, description];
}

// Event to update an existing note
class UpdateNote extends NoteEvent {
  final int noteId;
  final int folderId;
  final String title;
  final String description;

  const UpdateNote({
    required this.noteId,
    required this.folderId,
    required this.title,
    required this.description,
  });

  @override
  List<Object> get props => [noteId, folderId, title, description];
}

// Event to delete a note
class DeleteNote extends NoteEvent {
  final int noteId;
  final int folderId;

  const DeleteNote({
    required this.noteId,
    required this.folderId,
  });

  @override
  List<Object> get props => [noteId, folderId];
}

// Event to search notes within a folder
class SearchNotes extends NoteEvent {
  final int folderId;
  final String query;

  const SearchNotes({
    required this.folderId,
    required this.query,
  });

  @override
  List<Object> get props => [folderId, query];
}
