import 'package:flutter/material.dart';

class KeyboardService extends ChangeNotifier {
  static const double keyboardHeight = 300.0;

  bool isVisible = false;
  TextEditingController? activeController;
  FocusNode? activeFocusNode;
  bool obscureText = false;

  void show(
    TextEditingController controller,
    FocusNode focusNode, {
    bool obscure = false,
  }) {
    activeController = controller;
    activeFocusNode = focusNode;
    obscureText = obscure;
    isVisible = true;
    notifyListeners();
  }

  void hide() {
    activeFocusNode?.unfocus();
    activeController = null;
    activeFocusNode = null;
    isVisible = false;
    notifyListeners();
  }
}
