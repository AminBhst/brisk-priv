import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../base/outlined_text_field.dart';

class TextFieldSetting extends StatelessWidget {
  final String text;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final Widget? icon;
  final double width;
  final double? textWidth;
  final Function(String value)? onChanged;
  final TextEditingController txtController;

  TextFieldSetting({
    super.key,
    required this.text,
    this.icon,
    this.width = 300,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
    this.onChanged,
    this.textWidth,
    required this.txtController,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Provider.of<ThemeProvider>(context).activeTheme.settingTheme.pageTheme;
    textWidth ?? MediaQuery.of(context).size.width * 0.6 * 0.5;
    return Row(
      children: [
        SizedBox(
          width: textWidth,
          child: Text(
            text,
            style: TextStyle(color: theme.titleTextColor),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 10),
        SizedBox(
          width: width,
          height: 50,
          child: OutLinedTextField(
            controller: txtController,
            keyboardType: keyboardType,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: icon != null ? 10 : 0),
        icon != null ? icon! : Container(),
      ],
    );
  }
}
