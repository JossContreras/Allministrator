import 'package:allministrator/domain/value_objects/structured_document.dart';

typedef NodeDeserializer = DocumentNode Function(Map<String, Object?> json);

class DocumentNodeRegistry {
  DocumentNodeRegistry({Map<String, NodeDeserializer>? deserializers})
    : _deserializers = {
        'paragraph': ParagraphNode.fromJson,
        'image': ImageNode.fromJson,
        'divider': DividerNode.fromJson,
        'checklist': ChecklistNode.fromJson,
        'quote': QuoteNode.fromJson,
        'callout': CalloutNode.fromJson,
        'codeBlock': CodeBlockNode.fromJson,
        ...?deserializers,
      };
  final Map<String, NodeDeserializer> _deserializers;
  void register(String type, NodeDeserializer deserializer) =>
      _deserializers[type] = deserializer;
  DocumentNode deserialize(Map<String, Object?> json) =>
      _deserializers[json['type']]?.call(json) ?? DocumentNode.fromJson(json);
  bool supports(String type) => _deserializers.containsKey(type);
}

abstract interface class NodeRenderer<T> {
  T render(DocumentNode node);
}

abstract interface class NodeToolbarProvider {
  List<String> actionsFor(DocumentNode node);
}
