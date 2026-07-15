import 'dart:io';

import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_frame.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AttachmentBlockWidget extends StatelessWidget {
  const AttachmentBlockWidget({required this.renderContext, super.key});

  final BlockRenderContext renderContext;

  AttachmentBlock get block => renderContext.block as AttachmentBlock;

  @override
  Widget build(BuildContext context) {
    final path = renderContext.resolveAttachmentPath(block.attachmentId);
    final missing = path == null || !File(path).existsSync();
    final isVideo = block.mimeType.startsWith('video/');
    return BlockFrame(
      block: block,
      geometryRegistry: renderContext.geometryRegistry,
      workspaceId: renderContext.session.workspace.id,
      pageId: renderContext.session.page.id,
      visualLayer: renderContext.visualLayer,
      child: renderContext.region(
        id: 'attachment',
        target: AttachmentActionHitTarget(block.id, actionId: 'open'),
        priority: 20,
        child: isVideo && !missing
            ? _VideoAttachmentPreview(path: path, block: block)
            : Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: ListTile(
                  leading: Icon(
                    missing
                        ? Icons.insert_drive_file_outlined
                        : _icon(block.extension),
                    color: missing ? Theme.of(context).colorScheme.error : null,
                  ),
                  title: Text(
                    block.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (missing) 'Archivo faltante',
                      block.mimeType,
                      if (block.sizeBytes > 0) _size(block.sizeBytes),
                      if (block.description?.trim().isNotEmpty == true)
                        block.description!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: missing
                      ? null
                      : () => renderContext.onOpenAttachment(block),
                ),
              ),
      ),
    );
  }

  IconData _icon(String extension) => switch (extension.toLowerCase()) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'png' || 'jpg' || 'jpeg' || 'webp' => Icons.image_outlined,
    'zip' || 'rar' => Icons.folder_zip_outlined,
    'doc' || 'docx' => Icons.description_outlined,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
    'ppt' || 'pptx' => Icons.slideshow_outlined,
    'mp4' || 'mov' || 'm4v' || 'webm' => Icons.video_file_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _VideoAttachmentPreview extends StatefulWidget {
  const _VideoAttachmentPreview({required this.path, required this.block});

  final String path;
  final AttachmentBlock block;

  @override
  State<_VideoAttachmentPreview> createState() =>
      _VideoAttachmentPreviewState();
}

class _VideoAttachmentPreviewState extends State<_VideoAttachmentPreview> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _initialize = _controller.initialize().then((_) {
      _controller.setLooping(false);
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    elevation: 0,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<void>(
          future: _initialize,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !_controller.value.isInitialized) {
              return const SizedBox(
                height: 120,
                child: Center(child: Text('No se pudo reproducir el video')),
              );
            }
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio == 0
                  ? 16 / 9
                  : _controller.value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(_controller),
                  Center(
                    child: IconButton.filledTonal(
                      tooltip: _controller.value.isPlaying
                          ? 'Pausar video'
                          : 'Reproducir video',
                      onPressed: () => setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      }),
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            widget.block.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
