import 'package:allministrator/features/about/presentation/about_screen.dart';
import 'package:allministrator/features/backups/presentation/backups_screen.dart';
import 'package:allministrator/features/documents/presentation/documents_screen.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/editor/presentation/document_editor_screen.dart';
import 'package:allministrator/features/folders/presentation/folders_screen.dart';
import 'package:allministrator/features/favorites/presentation/favorites_screen.dart';
import 'package:allministrator/features/recent/presentation/recent_screen.dart';
import 'package:allministrator/features/settings/presentation/settings_screen.dart';
import 'package:allministrator/features/tags/presentation/tags_screen.dart';
import 'package:allministrator/features/templates/presentation/templates_screen.dart';
import 'package:allministrator/features/trash/presentation/trash_screen.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter(DocumentRepository repository) => GoRouter(
  initialLocation: '/documents',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/documents'),
    GoRoute(
      path: '/documents',
      builder: (_, _) => DocumentsScreen(repository: repository),
    ),
    GoRoute(path: '/recent', builder: (_, _) => const RecentScreen()),
    GoRoute(
      path: '/favorites',
      builder: (_, _) => FavoritesScreen(repository: repository),
    ),
    GoRoute(path: '/folders', builder: (_, _) => const FoldersScreen()),
    GoRoute(path: '/tags', builder: (_, _) => const TagsScreen()),
    GoRoute(path: '/templates', builder: (_, _) => const TemplatesScreen()),
    GoRoute(
      path: '/trash',
      builder: (_, _) => TrashScreen(repository: repository),
    ),
    GoRoute(path: '/backups', builder: (_, _) => const BackupsScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    GoRoute(
      path: '/editor/:documentId',
      builder: (_, state) => DocumentEditorScreen(
        repository: repository,
        documentId: state.pathParameters['documentId']!,
      ),
    ),
  ],
);
