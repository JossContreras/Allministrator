import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/note.dart';
import 'package:allministrator/domain/repositories/note_repository.dart';
import 'package:allministrator/features/notes/data/datasources/notes_local_data_source.dart';

/// Implementación local sustituible por una composición que añada remoto.
class LocalNoteRepository implements NoteRepository {
  LocalNoteRepository(this._localDataSource);

  final NotesLocalDataSource _localDataSource;

  @override
  Future<Note?> findActiveById(Uuid id) => _localDataSource.findActiveById(id);

  @override
  Future<void> save(Note note) => _localDataSource.save(note);

  @override
  Stream<List<Note>> watchActive() => _localDataSource.watchActive();
}
