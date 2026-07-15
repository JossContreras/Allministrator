import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ExtractedImageText {
  const ExtractedImageText({required this.text, required this.blockCount});

  final String text;
  final int blockCount;

  bool get isEmpty => text.trim().isEmpty;
}

/// Offline OCR adapter. ML Kit runs on-device and the source image never has
/// to leave the device. Desktop platforms intentionally report unsupported
/// until a native desktop recognizer is registered.
class ImageTextExtractor {
  ImageTextExtractor({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<ExtractedImageText> extract(String path) async {
    if (!isSupported) {
      throw UnsupportedError('El OCR está disponible en Android y iOS.');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('La imagen ya no está disponible.');
    }
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(path),
    );
    return ExtractedImageText(
      text: result.text.trim(),
      blockCount: result.blocks.length,
    );
  }

  Future<void> dispose() => _recognizer.close();
}
