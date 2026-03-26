// widgets/color_picker_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerDialog extends StatelessWidget {
  final String initialColor;
  final String title;
  final Function(String) onColorSelected;

  const ColorPickerDialog({
    Key? key,
    required this.initialColor,
    required this.title,
    required this.onColorSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color currentColor = Color(
      int.parse(initialColor.replaceFirst('#', '0xff')),
    );

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: currentColor,
          onColorChanged: (color) {
            onColorSelected(
              '#${color.value.toRadixString(16).substring(2)}',
            );
          },
          showLabel: true,
          pickerAreaHeightPercent: 0.8,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}