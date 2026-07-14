import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/entities/note.dart';

/// Contrato de dominio; no conoce Drift ni el origen concreto de los datos.
abstract interface class NoteRepository {
  Stream<List<Note>> watchActive();
  Future<Note?> findActiveById(Uuid id);
  Future<void> save(Note note);
}
