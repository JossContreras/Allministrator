import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/domain/interaction/interaction_intents.dart';

/// Data-changing actions are commands for the editor layer, never mutations
/// performed by the dispatcher or resolver.
class InternalBlockActionIntent extends InteractionIntent {
  const InternalBlockActionIntent({
    required this.blockId,
    required this.actionId,
  });

  final Uuid blockId;
  final String actionId;
}

class OpenAttachmentIntent extends InteractionIntent {
  const OpenAttachmentIntent(this.blockId);

  final Uuid blockId;
}

class CopyCodeIntent extends InteractionIntent {
  const CopyCodeIntent(this.blockId);

  final Uuid blockId;
}
