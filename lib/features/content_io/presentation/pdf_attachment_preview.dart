import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

Future<void> showPdfAttachmentPreview(
  BuildContext context, {
  required String path,
  required String title,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: Text(title),
      ),
      body: PdfPreview(
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        build: (_) => File(path).readAsBytes(),
        loadingWidget: const Center(child: CircularProgressIndicator()),
        pdfFileName: title,
      ),
    ),
  ),
);
