import 'package:flutter/material.dart';
import 'package:allministrator/app/theme/app_motion.dart';
import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/domain/editing/editor_history.dart';
import 'package:allministrator/domain/editing/selection_controller.dart';

enum ToolbarContextKind {
  hidden,
  textCursor,
  textSelection,
  paragraph,
  image,
  table,
  code,
  drawing,
  attachment,
}

class ToolbarContext {
  const ToolbarContext({
    required this.hasSelection,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.alignment = 'left',
  });
  final bool hasSelection, bold, italic, underline, strikethrough;
  final String alignment;
}

class ToolbarState {
  const ToolbarState({
    this.isVisible = false,
    this.isExpanded = false,
    this.context = ToolbarContextKind.hidden,
    this.availableActions = const {},
    this.activeActions = const {},
    this.mixedActions = const {},
    this.disabledActions = const {},
    this.keyboardVisible = false,
  });
  final bool isVisible, isExpanded, keyboardVisible;
  final ToolbarContextKind context;
  final Set<String> availableActions,
      activeActions,
      mixedActions,
      disabledActions;
}

class ToolbarController extends ChangeNotifier {
  ToolbarContext context = const ToolbarContext(hasSelection: false);
  ToolbarState state = const ToolbarState();
  void update(ToolbarContext value) {
    context = value;
    state = ToolbarState(
      isVisible: value.hasSelection,
      context: value.hasSelection
          ? ToolbarContextKind.textSelection
          : ToolbarContextKind.hidden,
      availableActions: value.hasSelection
          ? const {
              'bold',
              'italic',
              'underline',
              'strikethrough',
              'color',
              'highlight',
              'fontSize',
              'alignment',
            }
          : const {},
      activeActions: {
        if (value.bold) 'bold',
        if (value.italic) 'italic',
        if (value.underline) 'underline',
        if (value.strikethrough) 'strikethrough',
      },
    );
    notifyListeners();
  }

  ToolbarState updateContext(
    EditorState editorState,
    SelectionContext selectionContext,
  ) {
    final hasSelection = !editorState.selection.isCollapsed;
    update(
      ToolbarContext(
        hasSelection: hasSelection,
        bold: editorState.document.formatActive(
          editorState.selection,
          'bold',
          true,
        ),
        italic: editorState.document.formatActive(
          editorState.selection,
          'italic',
          true,
        ),
        underline: editorState.document.formatActive(
          editorState.selection,
          'underline',
          true,
        ),
        strikethrough: editorState.document.formatActive(
          editorState.selection,
          'strikethrough',
          true,
        ),
      ),
    );
    return state;
  }

  void show() {
    state = ToolbarState(
      isVisible: true,
      isExpanded: state.isExpanded,
      context: state.context,
      availableActions: state.availableActions,
      activeActions: state.activeActions,
      mixedActions: state.mixedActions,
      disabledActions: state.disabledActions,
      keyboardVisible: state.keyboardVisible,
    );
    notifyListeners();
  }

  void hide() {
    state = ToolbarState(
      isExpanded: state.isExpanded,
      keyboardVisible: state.keyboardVisible,
    );
    notifyListeners();
  }

  void toggleExpanded() {
    state = ToolbarState(
      isVisible: state.isVisible,
      isExpanded: !state.isExpanded,
      context: state.context,
      availableActions: state.availableActions,
      activeActions: state.activeActions,
      mixedActions: state.mixedActions,
      disabledActions: state.disabledActions,
      keyboardVisible: state.keyboardVisible,
    );
    notifyListeners();
  }

  void setContext(ToolbarContext value) => update(value);
  void setKeyboardVisibility(bool visible) {
    state = ToolbarState(
      isVisible: state.isVisible,
      isExpanded: state.isExpanded,
      context: state.context,
      availableActions: state.availableActions,
      activeActions: state.activeActions,
      mixedActions: state.mixedActions,
      disabledActions: state.disabledActions,
      keyboardVisible: visible,
    );
    notifyListeners();
  }

  void setEditorFocus(bool focused) {
    if (focused) {
      show();
    } else {
      hide();
    }
  }
}

class ToolbarButton extends StatelessWidget {
  const ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    super.key,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    toggled: active,
    child: IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: active,
      icon: Icon(icon),
      selectedIcon: Icon(icon),
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
  );
}

class ToolbarGroup extends StatelessWidget {
  const ToolbarGroup({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: children
        .map(
          (child) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: child,
          ),
        )
        .toList(),
  );
}

class ToolbarDivider extends StatelessWidget {
  const ToolbarDivider({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: SizedBox(height: 32, child: VerticalDivider(width: 1)),
  );
}

class ToolbarOverlay extends StatelessWidget {
  const ToolbarOverlay({required this.visible, required this.child, super.key});
  final bool visible;
  final Widget child;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.25),
      duration: AppMotion.normal,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.fast,
        child: child,
      ),
    ),
  );
}

class SmartFormattingToolbar extends StatelessWidget {
  const SmartFormattingToolbar({
    required this.contextState,
    required this.onToggle,
    required this.onColor,
    required this.onSize,
    required this.onAlignment,
    super.key,
  });
  final ToolbarContext contextState;
  final void Function(String attribute, Object? value) onToggle;
  final ValueChanged<int?> onColor;
  final ValueChanged<double> onSize;
  final ValueChanged<String> onAlignment;

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    policy: ReadingOrderTraversalPolicy(),
    child: Semantics(
      container: true,
      label: 'Formato del texto seleccionado',
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ToolbarGroup(
                children: [
                  ToolbarButton(
                    icon: Icons.format_bold,
                    tooltip: 'Negrita',
                    active: contextState.bold,
                    onPressed: () => onToggle('bold', !contextState.bold),
                  ),
                  ToolbarButton(
                    icon: Icons.format_italic,
                    tooltip: 'Cursiva',
                    active: contextState.italic,
                    onPressed: () => onToggle('italic', !contextState.italic),
                  ),
                  ToolbarButton(
                    icon: Icons.format_underlined,
                    tooltip: 'Subrayado',
                    active: contextState.underline,
                    onPressed: () =>
                        onToggle('underline', !contextState.underline),
                  ),
                  ToolbarButton(
                    icon: Icons.strikethrough_s,
                    tooltip: 'Tachado',
                    active: contextState.strikethrough,
                    onPressed: () =>
                        onToggle('strikethrough', !contextState.strikethrough),
                  ),
                ],
              ),
              const ToolbarDivider(),
              PopupMenuButton<int?>(
                key: const ValueKey('text-color-menu'),
                tooltip: 'Color de texto',
                onSelected: onColor,
                itemBuilder: (_) => _colors
                    .map(
                      (color) => PopupMenuItem(
                        value: color,
                        child: _colorChoice(color),
                      ),
                    )
                    .toList(),
                icon: const Icon(Icons.format_color_text),
              ),
              PopupMenuButton<int?>(
                key: const ValueKey('text-highlight-menu'),
                tooltip: 'Resaltado',
                onSelected: (value) => onToggle('highlight', value),
                itemBuilder: (_) => _highlights
                    .map(
                      (color) => PopupMenuItem(
                        value: color,
                        child: _colorChoice(color),
                      ),
                    )
                    .toList(),
                icon: const Icon(Icons.highlight),
              ),
              const ToolbarDivider(),
              PopupMenuButton<double>(
                key: const ValueKey('font-size-menu'),
                tooltip: 'Tamaño de fuente',
                onSelected: onSize,
                itemBuilder: (_) => [12, 14, 16, 18, 24, 32]
                    .map(
                      (size) => PopupMenuItem(
                        value: size.toDouble(),
                        child: Text('${size}px'),
                      ),
                    )
                    .toList(),
                icon: const Icon(Icons.format_size),
              ),
              const ToolbarDivider(),
              ToolbarGroup(
                children: [
                  ToolbarButton(
                    icon: Icons.format_align_left,
                    tooltip: 'Alinear a la izquierda',
                    active: contextState.alignment == 'left',
                    onPressed: () => onAlignment('left'),
                  ),
                  ToolbarButton(
                    icon: Icons.format_align_center,
                    tooltip: 'Centrar',
                    active: contextState.alignment == 'center',
                    onPressed: () => onAlignment('center'),
                  ),
                  ToolbarButton(
                    icon: Icons.format_align_right,
                    tooltip: 'Alinear a la derecha',
                    active: contextState.alignment == 'right',
                    onPressed: () => onAlignment('right'),
                  ),
                  ToolbarButton(
                    icon: Icons.format_align_justify,
                    tooltip: 'Justificar',
                    active: contextState.alignment == 'justify',
                    onPressed: () => onAlignment('justify'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static const _colors = <int?>[
    null,
    0xFF202124,
    0xFFD93025,
    0xFF188038,
    0xFF1967D2,
    0xFFF9AB00,
  ];
  static const _highlights = <int?>[
    null,
    0xFFFFF2CC,
    0xFFFFD6D6,
    0xFFD9EAD3,
    0xFFD9EAF7,
  ];
  Widget _colorChoice(int? value) => Row(
    children: [
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: value == null ? Colors.transparent : Color(value),
          border: Border.all(color: Colors.grey),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Text(value == null ? 'Quitar' : 'Aplicar'),
    ],
  );
}
