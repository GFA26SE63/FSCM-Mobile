import 'package:flutter/widgets.dart';

/// Releases the keyboard focus (and so the cursor and keyboard). Used as the
/// `onTapOutside` of search fields and on every route change.
void releaseFocus([PointerDownEvent? _]) =>
    FocusManager.instance.primaryFocus?.unfocus();
