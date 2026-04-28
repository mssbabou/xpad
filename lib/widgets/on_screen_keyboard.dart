import 'package:flutter/material.dart';
import 'package:xpad/app/app_state.dart';
import 'package:xpad/app/theme.dart';
import 'package:xpad/widgets/keyboard_service.dart';

class OnScreenKeyboard extends StatefulWidget {
  const OnScreenKeyboard({super.key});

  @override
  State<OnScreenKeyboard> createState() => _OnScreenKeyboardState();
}

class _OnScreenKeyboardState extends State<OnScreenKeyboard> {
  bool _capsOn = false;
  bool _numbersMode = false;

  void _insertText(String text) {
    final controller = keyboardService.activeController;
    if (controller == null) return;

    final value = controller.value;
    final start = value.selection.start;
    final end = value.selection.end;

    if (start < 0) return;

    final before = value.text.substring(0, start);
    final after = value.text.substring(end);
    final newText = before + text + after;
    final newPos = start + text.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newPos),
    );

    if (_capsOn && text.length == 1) {
      setState(() => _capsOn = false);
    }
  }

  void _delete() {
    final controller = keyboardService.activeController;
    if (controller == null) return;

    final value = controller.value;
    final start = value.selection.start;
    final end = value.selection.end;

    if (start < 0) return;

    final actualStart = start == end ? (start > 0 ? start - 1 : 0) : start;
    if (actualStart == start && start == 0) return;

    final before = value.text.substring(0, actualStart);
    final after = value.text.substring(end);
    final newText = before + after;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: actualStart),
    );
  }

  void _enter() {
    if (keyboardService.activeFocusNode?.nextFocus() == true) {
      return;
    }
    keyboardService.hide();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: keyboardService.isVisible ? KeyboardService.keyboardHeight : 0,
      color: bg,
      child: keyboardService.isVisible
          ? SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _numbersMode ? _NumbersLayout() : _LettersLayout(
                  capsOn: _capsOn,
                  onToggleCaps: () => setState(() => _capsOn = !_capsOn),
                  onInsert: _insertText,
                  onDelete: _delete,
                  onEnter: _enter,
                  onToggleMode: () => setState(() => _numbersMode = !_numbersMode),
                  onClose: () => keyboardService.hide(),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ── Letters layout ─────────────────────────────────────────────────────────────

class _LettersLayout extends StatelessWidget {
  final bool capsOn;
  final VoidCallback onToggleCaps;
  final void Function(String) onInsert;
  final VoidCallback onDelete;
  final VoidCallback onEnter;
  final VoidCallback onToggleMode;
  final VoidCallback onClose;

  const _LettersLayout({
    required this.capsOn,
    required this.onToggleCaps,
    required this.onInsert,
    required this.onDelete,
    required this.onEnter,
    required this.onToggleMode,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '⌫'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', '↵'],
      ['⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '.'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final key in row)
                  _KeyButton(
                    label: _displayLabel(key),
                    onTap: () => _handleKey(key),
                    isAction: key == '⌫' || key == '↵' || key == '⇧',
                    flex: key == '↵' ? 2 : 1,
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _KeyButton(
                label: '123',
                onTap: onToggleMode,
                isAction: true,
                flex: 1,
              ),
              _KeyButton(
                label: '                ',
                onTap: () => onInsert(' '),
                isAction: false,
                flex: 4,
              ),
              _KeyButton(
                label: '✕',
                onTap: onClose,
                isAction: true,
                flex: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _displayLabel(String key) {
    if (key == '⌫' || key == '↵' || key == '⇧' || key == '123') return key;
    return capsOn ? key.toUpperCase() : key;
  }

  void _handleKey(String key) {
    if (key == '⌫') {
      onDelete();
    } else if (key == '↵') {
      onEnter();
    } else if (key == '⇧') {
      onToggleCaps();
    } else {
      onInsert(_displayLabel(key));
    }
  }
}

// ── Numbers layout ────────────────────────────────────────────────────────────

class _NumbersLayout extends StatelessWidget {
  const _NumbersLayout();

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '⌫'],
      ['-', '/', ':', ';', '(', ')', '&', '@', '#', '_', '↵'],
      ['.', ',', '!', '?', "'", '"', '~', '=', '+', '*'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final key in row)
                  _KeyButton(
                    label: key,
                    onTap: () => _handleKey(key),
                    isAction: key == '⌫' || key == '↵',
                    flex: key == '↵' ? 2 : 1,
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _KeyButton(
                label: 'ABC',
                onTap: () => Navigator.of(context).pop(),
                isAction: true,
                flex: 1,
              ),
              _KeyButton(
                label: '                ',
                onTap: () {
                  final controller = keyboardService.activeController;
                  if (controller == null) return;
                  final value = controller.value;
                  final start = value.selection.start;
                  final end = value.selection.end;
                  if (start < 0) return;
                  final before = value.text.substring(0, start);
                  final after = value.text.substring(end);
                  final newText = '$before $after';
                  controller.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: start + 1),
                  );
                },
                isAction: false,
                flex: 4,
              ),
              _KeyButton(
                label: '✕',
                onTap: () => keyboardService.hide(),
                isAction: true,
                flex: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleKey(String key) {
    final controller = keyboardService.activeController;
    if (controller == null) return;

    if (key == '⌫') {
      final value = controller.value;
      final start = value.selection.start;
      if (start <= 0) return;
      final before = value.text.substring(0, start - 1);
      final after = value.text.substring(value.selection.end);
      controller.value = TextEditingValue(
        text: before + after,
        selection: TextSelection.collapsed(offset: start - 1),
      );
    } else if (key == '↵') {
      keyboardService.activeFocusNode?.nextFocus();
    } else {
      final value = controller.value;
      final start = value.selection.start;
      final end = value.selection.end;
      if (start < 0) return;
      final before = value.text.substring(0, start);
      final after = value.text.substring(end);
      final newText = before + key + after;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + key.length),
      );
    }
  }
}

// ── Key button ────────────────────────────────────────────────────────────────

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAction;
  final int flex;

  const _KeyButton({
    required this.label,
    required this.onTap,
    required this.isAction,
    required this.flex,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isAction ? accent : surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isAction ? Colors.white : textHi,
              fontSize: isAction ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
