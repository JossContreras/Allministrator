/// Controlled language identifiers used by code blocks. Rendering may add
/// highlighting later without changing the persisted document format.
class CodeLanguageCatalog {
  static const ids = <String>[
    'plainText',
    'dart',
    'python',
    'javascript',
    'typescript',
    'json',
    'html',
    'css',
    'sql',
    'java',
    'kotlin',
    'c',
    'cpp',
    'csharp',
    'bash',
    'yaml',
    'markdown',
  ];
  static bool supports(String? id) => id == null || ids.contains(id);
}
