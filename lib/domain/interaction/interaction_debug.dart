import 'dart:collection';

import 'package:allministrator/domain/interaction/interaction_intent_result.dart';

class InteractionDebugEntry {
  const InteractionDebugEntry({
    required this.timestamp,
    required this.eventType,
    required this.device,
    required this.result,
    this.target,
    this.intent,
  });

  final DateTime timestamp;
  final String eventType;
  final String device;
  final String? target;
  final String? intent;
  final InteractionIntentResultKind result;
}

class InteractionDebugTimeline {
  InteractionDebugTimeline({this.limit = 100});

  final int limit;
  final Queue<InteractionDebugEntry> _entries = Queue();

  List<InteractionDebugEntry> get entries => List.unmodifiable(_entries);

  void add(InputDispatchResult result) {
    _entries.addLast(
      InteractionDebugEntry(
        timestamp: result.event.timestamp,
        eventType: result.event.type.name,
        device: result.event.deviceType.name,
        target: result.event.hitTarget?.kind.name,
        intent: result.resolution.intent?.runtimeType.toString(),
        result: result.resolution.kind,
      ),
    );
    while (_entries.length > limit) {
      _entries.removeFirst();
    }
  }

  void clear() => _entries.clear();
}
