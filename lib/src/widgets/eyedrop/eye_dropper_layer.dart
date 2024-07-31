import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../../utils.dart';
import 'eye_dropper_overlay.dart';

final captureKey = GlobalKey();

class EyeDropperModel {
  /// based on PointerEvent.kind
  bool touchable = false;

  OverlayEntry? eyeOverlayEntry;

  img.Image? snapshot;

  Offset? cursorPosition;

  Color hoverColor = Colors.black;

  List<Color> hoverColors = [];

  Color selectedColor = Colors.black;

  ValueChanged<Color>? onColorSelected;

  ValueChanged<Color>? onColorChanged;

  EyeDropperModel();
}

class EyeDrop extends InheritedWidget {
  static EyeDropperModel data = EyeDropperModel();

  EyeDrop({required Widget child, Key? key})
      : super(
          key: key,
          child: RepaintBoundary(
            key: captureKey,
            child: Listener(
              onPointerMove: (details) => _onHover(
                captureKey.currentContext!,
                details.position,
                details.kind == PointerDeviceKind.touch,
              ),
              onPointerHover: (details) => _onHover(
                captureKey.currentContext!,
                details.position,
                details.kind == PointerDeviceKind.touch,
              ),
              onPointerUp: (details) =>
                  _onPointerUp(captureKey.currentContext!, details.position),
              child: child,
            ),
          ),
        );

  static EyeDrop of(BuildContext context) {
    final eyeDrop = context.dependOnInheritedWidgetOfExactType<EyeDrop>();
    if (eyeDrop == null) {
      throw Exception(
          'No EyeDrop found. You must wrap your application within an EyeDrop widget.');
    }
    return eyeDrop;
  }

  static void _onPointerUp(BuildContext context, Offset position) {
    _onHover(context, position, data.touchable);

    if (data.eyeOverlayEntry != null) {
      try {
        data.eyeOverlayEntry!.remove();
        data.eyeOverlayEntry = null;
        data.onColorSelected = null;
        data.onColorChanged = null;
      } catch (err) {
        debugPrint('ERROR !!! _onPointerUp $err');
      }
    }

    if (data.onColorSelected != null) {
      data.onColorSelected!(data.hoverColors.center);
    }
  }

  static void _onHover(
      BuildContext context, Offset globalOffset, bool touchable) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localOffset = renderBox.globalToLocal(globalOffset);

    if (data.eyeOverlayEntry != null) data.eyeOverlayEntry!.markNeedsBuild();

    data.cursorPosition = globalOffset;
    data.touchable = touchable;

    if (data.snapshot != null) {
      data.hoverColor = getPixelColor(data.snapshot!, localOffset);
      data.hoverColors = getPixelColors(data.snapshot!, localOffset);
    }

    if (data.onColorChanged != null) {
      data.onColorChanged!(data.hoverColors.center);
    }
  }

  void capture(
    BuildContext context,
    ValueChanged<Color> onColorSelected,
    ValueChanged<Color>? onColorChanged,
  ) async {
    final renderer =
        captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (renderer == null) return;

    data.onColorSelected = onColorSelected;
    data.onColorChanged = onColorChanged;

    data.snapshot = await repaintBoundaryToImage(renderer);

    if (data.snapshot == null || data.cursorPosition == null) return;

    final localOffset = renderer.globalToLocal(data.cursorPosition!);

    data.hoverColor = getPixelColor(data.snapshot!, localOffset);
    data.hoverColors = getPixelColors(data.snapshot!, localOffset);
    data.eyeOverlayEntry?.markNeedsBuild();

    data.eyeOverlayEntry = OverlayEntry(
      builder: (_) => EyeDropOverlay(
        touchable: data.touchable,
        colors: data.hoverColors,
        cursorPosition: data.cursorPosition,
      ),
    );

    if (context.mounted) {
      Overlay.of(context).insert(data.eyeOverlayEntry!);
    }
  }

  void updateCursorPosition(Offset offset) {
    data.cursorPosition = offset;
  }

  @override
  bool updateShouldNotify(EyeDrop oldWidget) {
    return true;
  }
}