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
    controller.value = TextEditingValue(
      text: before + text + after,
      selection: TextSelection.collapsed(offset: start + text.length),
    );

    if (_capsOn && text.length == 1) setState(() => _capsOn = false);
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

    controller.value = TextEditingValue(
      text: value.text.substring(0, actualStart) + value.text.substring(end),
      selection: TextSelection.collapsed(offset: actualStart),
    );
  }

  void _enter() {
    if (keyboardService.activeFocusNode?.nextFocus() == true) return;
    keyboardService.hide();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: keyboardService.isVisible ? KeyboardService.keyboardHeight : 0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: keyboardService.isVisible
          ? Material(
              color: bg,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                child: _numbersMode
                    ? _NumbersLayout(
                        onInsert: _insertText,
                        onDelete: _delete,
                        onEnter: _enter,
                        onToggleMode: () => setState(() => _numbersMode = false),
                        onClose: () => keyboardService.hide(),
                      )
                    : _LettersLayout(
                        capsOn: _capsOn,
                        onToggleCaps: () => setState(() => _capsOn = !_capsOn),
                        onInsert: _insertText,
                        onDelete: _delete,
                        onEnter: _enter,
                        onToggleMode: () => setState(() => _numbersMode = true),
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
          _Row(children: [
            for (final key in row)
              _Key(
                label: _label(key),
                onTap: () => _handle(key),
                isAction: key == '⌫' || key == '↵' || key == '⇧',
                flex: key == '↵' ? 2 : 1,
              ),
          ]),
        _Row(children: [
          _Key(label: '123', onTap: onToggleMode, isAction: true, flex: 1),
          _Key(label: ' ', onTap: () => onInsert(' '), isAction: false, flex: 4),
          _Key(label: '✕', onTap: onClose, isAction: true, flex: 1),
        ]),
      ],
    );
  }

  String _label(String key) {
    if (key == '⌫' || key == '↵' || key == '⇧') return key;
    return capsOn ? key.toUpperCase() : key;
  }

  void _handle(String key) {
    switch (key) {
      case '⌫': onDelete();
      case '↵': onEnter();
      case '⇧': onToggleCaps();
      default: onInsert(_label(key));
    }
  }
}

// ── Numbers layout ────────────────────────────────────────────────────────────

class _NumbersLayout extends StatelessWidget {
  final void Function(String) onInsert;
  final VoidCallback onDelete;
  final VoidCallback onEnter;
  final VoidCallback onToggleMode;
  final VoidCallback onClose;

  const _NumbersLayout({
    required this.onInsert,
    required this.onDelete,
    required this.onEnter,
    required this.onToggleMode,
    required this.onClose,
  });

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
          _Row(children: [
            for (final key in row)
              _Key(
                label: key,
                onTap: () => _handle(key),
                isAction: key == '⌫' || key == '↵',
                flex: key == '↵' ? 2 : 1,
              ),
          ]),
        _Row(children: [
          _Key(label: 'ABC', onTap: onToggleMode, isAction: true, flex: 1),
          _Key(label: ' ', onTap: () => onInsert(' '), isAction: false, flex: 4),
          _Key(label: '✕', onTap: onClose, isAction: true, flex: 1),
        ]),
      ],
    );
  }

  void _handle(String key) {
    switch (key) {
      case '⌫': onDelete();
      case '↵': onEnter();
      default: onInsert(key);
    }
  }
}

// ── Shared layout helpers ──────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final List<Widget> children;
  const _Row({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: children),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAction;
  final int flex;

  const _Key({
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
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isAction ? const Color(0xFFE8EAF6) : surface,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isAction ? accent : textHi,
              fontSize: 14,
              fontWeight: isAction ? FontWeight.w600 : FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
