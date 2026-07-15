import 'package:allministrator/features/content_io/data/document_export_service.dart';
import 'package:flutter/material.dart';

Future<ExportFileType?> showDocumentExportSheet(BuildContext context) =>
    showModalBottomSheet<ExportFileType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Exportar una copia',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _choice(
              context,
              type: ExportFileType.pdf,
              icon: Icons.picture_as_pdf_outlined,
              title: 'PDF',
              subtitle: 'Documento paginado listo para compartir o imprimir',
            ),
            _choice(
              context,
              type: ExportFileType.markdown,
              icon: Icons.code_outlined,
              title: 'Markdown (.md)',
              subtitle: 'Conserva encabezados, listas, citas, tablas y código',
            ),
            _choice(
              context,
              type: ExportFileType.plainText,
              icon: Icons.text_snippet_outlined,
              title: 'Texto plano (.txt)',
              subtitle: 'Solo contenido textual, sin estilos visuales',
            ),
            _choice(
              context,
              type: ExportFileType.html,
              icon: Icons.html_outlined,
              title: 'HTML',
              subtitle: 'Publicación portable para navegador',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

Widget _choice(
  BuildContext context, {
  required ExportFileType type,
  required IconData icon,
  required String title,
  required String subtitle,
}) => ListTile(
  leading: Icon(icon),
  title: Text(title),
  subtitle: Text(subtitle),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.pop(context, type),
);
