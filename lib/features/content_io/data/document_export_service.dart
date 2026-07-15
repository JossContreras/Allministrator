import 'dart:io';

import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ExportFileType { plainText, markdown, html, pdf }

class DocumentExportResult {
  const DocumentExportResult({
    required this.path,
    required this.type,
    this.warning,
  });

  final String path;
  final ExportFileType type;
  final String? warning;
}

class DocumentExportSerializer {
  const DocumentExportSerializer();

  String plainText(Document document) => document.content.text.trimRight();

  String markdownText(Document document) {
    final output = StringBuffer();
    if (document.title.trim().isNotEmpty) {
      output.writeln('# ${document.title.trim()}\n');
    }
    for (final block in document.content.workspace.primaryPage.blocks) {
      switch (block) {
        case TextBlock():
          output.writeln(block.plainText);
        case ChecklistBlock():
          for (final item in block.items) {
            output.writeln('- [${item.isChecked ? 'x' : ' '}] ${item.text}');
          }
        case CodeBlock():
          output
            ..writeln('```${block.languageId}')
            ..writeln(block.code)
            ..writeln('```');
        case QuoteBlock():
          output.writeln(
            block.text.split('\n').map((line) => '> $line').join('\n'),
          );
        case CalloutBlock():
          output.writeln(
            '> **${block.title ?? block.calloutType.name}:** ${block.text}',
          );
        case TableBlock():
          _writeTable(output, block);
        case ImageBlock():
          output.writeln(
            '![${block.altText ?? block.caption ?? 'Imagen'}](attachment:${block.attachmentId})',
          );
        case AttachmentBlock():
          output.writeln(
            '[${block.displayName}](attachment:${block.attachmentId})',
          );
        case DividerBlock():
          output.writeln('---');
        case UnknownBlock():
          output.writeln(
            '<!-- Bloque no compatible: ${block.originalType} -->',
          );
      }
      output.writeln();
    }
    return output.toString().trimRight();
  }

  String html(Document document) => markdown.markdownToHtml(
    markdownText(document),
    extensionSet: markdown.ExtensionSet.gitHubWeb,
  );

  void _writeTable(StringBuffer output, TableBlock table) {
    if (table.rows.isEmpty) return;
    final rows = table.rows
        .map(
          (row) => row.cells
              .map((cell) => cell.text.replaceAll('|', '\\|'))
              .toList(),
        )
        .toList();
    output.writeln('| ${rows.first.join(' | ')} |');
    output.writeln('| ${List.filled(rows.first.length, '---').join(' | ')} |');
    for (final row in rows.skip(1)) {
      output.writeln('| ${row.join(' | ')} |');
    }
  }
}

class DocumentExportService {
  DocumentExportService({DocumentExportSerializer? serializer})
    : _serializer = serializer ?? const DocumentExportSerializer();

  final DocumentExportSerializer _serializer;

  Future<DocumentExportResult> export(
    Document document,
    ExportFileType type,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final exports = Directory(
      '${directory.path}${Platform.pathSeparator}exports',
    );
    await exports.create(recursive: true);
    final extension = switch (type) {
      ExportFileType.plainText => 'txt',
      ExportFileType.markdown => 'md',
      ExportFileType.html => 'html',
      ExportFileType.pdf => 'pdf',
    };
    final file = File(
      '${exports.path}${Platform.pathSeparator}${_safeName(document.title)}-${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    if (type == ExportFileType.pdf) {
      await file.writeAsBytes(await _buildPdf(document), flush: true);
    } else {
      final value = switch (type) {
        ExportFileType.plainText => _serializer.plainText(document),
        ExportFileType.markdown => _serializer.markdownText(document),
        ExportFileType.html => _serializer.html(document),
        ExportFileType.pdf => '',
      };
      await file.writeAsString(value, flush: true);
    }
    return DocumentExportResult(
      path: file.path,
      type: type,
      warning: document.isCanvas
          ? 'Esta exportación conserva el contenido textual del Canvas; la composición espacial requiere exportación visual.'
          : null,
    );
  }

  Future<List<int>> _buildPdf(Document document) async {
    final pdf = pw.Document(
      title: document.title,
      author: 'Workspace',
      creator: 'Workspace offline editor',
    );
    final text = _serializer.plainText(document);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => [
          if (document.title.trim().isNotEmpty)
            pw.Header(level: 0, child: pw.Text(document.title.trim())),
          pw.Text(text.isEmpty ? 'Documento vacío' : text),
        ],
      ),
    );
    return pdf.save();
  }

  String _safeName(String value) {
    final normalized = value.trim().isEmpty ? 'documento' : value.trim();
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ_-]+'), '-');
  }
}
