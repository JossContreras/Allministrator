import 'package:allministrator/domain/interaction/interaction_intents.dart';
import 'package:allministrator/domain/interaction/normalized_input_event.dart';
import 'package:allministrator/domain/interaction/workspace_hit_target.dart';

enum InteractionPriority {
  modal,
  internalControl,
  nativeText,
  handle,
  editableRegion,
  blockRegion,
  layout,
  viewport,
  emptyArea,
}

enum InteractionIntentResultKind {
  intent,
  consumed,
  ignored,
  rejected,
  delegatedToNative,
  error,
  cancelled,
}

class InteractionIntentResult {
  const InteractionIntentResult._({
    required this.kind,
    this.intent,
    this.reason,
    this.priority,
    this.target,
  });

  const InteractionIntentResult.intent(
    InteractionIntent intent, {
    InteractionPriority? priority,
    WorkspaceHitTarget? target,
  }) : this._(
         kind: InteractionIntentResultKind.intent,
         intent: intent,
         priority: priority,
         target: target,
       );

  const InteractionIntentResult.state(
    InteractionIntentResultKind kind, {
    String? reason,
    InteractionPriority? priority,
    WorkspaceHitTarget? target,
  }) : this._(kind: kind, reason: reason, priority: priority, target: target);

  final InteractionIntentResultKind kind;
  final InteractionIntent? intent;
  final String? reason;
  final InteractionPriority? priority;
  final WorkspaceHitTarget? target;

  bool get isTerminal => kind != InteractionIntentResultKind.intent;
}

class InputDispatchResult {
  const InputDispatchResult({
    required this.event,
    required this.resolution,
    this.correlationId,
  });

  final NormalizedInputEvent event;
  final InteractionIntentResult resolution;
  final String? correlationId;
}
