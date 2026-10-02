import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/personal_code.dart';

/// Campo del código personal: dos grupos de cuatro caracteres, como en el carné.
/// El primero es el del colegio y viene escrito (se puede corregir); la persona
/// completa el segundo.
class PersonalCodeField extends StatefulWidget {
  const PersonalCodeField({
    required this.onChanged,
    this.onCompleted,
    super.key,
  });

  /// Se llama con los ocho caracteres escritos, en mayúsculas.
  final ValueChanged<String> onChanged;

  /// Se llama cuando los dos grupos quedan completos.
  final VoidCallback? onCompleted;

  @override
  State<PersonalCodeField> createState() => _PersonalCodeFieldState();
}

class _PersonalCodeFieldState extends State<PersonalCodeField> {
  final List<TextEditingController> _controllers = <TextEditingController>[
    TextEditingController(text: AppStrings.schoolCode),
    TextEditingController(),
  ];
  final List<FocusNode> _focusNodes = <FocusNode>[FocusNode(), FocusNode()];

  @override
  void initState() {
    super.initState();
    for (final FocusNode node in _focusNodes) {
      node.addListener(_onFocusChanged);
    }
    // El grupo del colegio ya viene escrito: se avisa al llamador para que sepa
    // cuántos caracteres lleva desde el principio.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onChanged(_value);
      }
    });
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    for (final FocusNode node in _focusNodes) {
      node
        ..removeListener(_onFocusChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  String get _value => _controllers.map((TextEditingController c) => c.text).join();

  void _handleChanged(int index, String raw) {
    setState(() {});
    widget.onChanged(_value);

    // Pasa al siguiente grupo al llenar el actual y vuelve al anterior al
    // borrarlo, para que se pueda escribir el código de corrido.
    if (raw.length == PersonalCode.groupLength && index == 0) {
      _focusNodes[1].requestFocus();
    } else if (raw.isEmpty && index == 1) {
      _focusNodes[0].requestFocus();
    }

    if (_value.length == PersonalCode.digitsLength) {
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _group(0)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _group(1)),
      ],
    );
  }

  Widget _group(int index) {
    final bool focused = _focusNodes[index].hasFocus;
    final bool filled = _controllers[index].text.isNotEmpty;

    return Container(
      height: AppSpacing.buttonHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: focused || filled ? AppColors.brand : AppColors.border,
          width: focused ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 1,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        keyboardType: TextInputType.visiblePassword,
        textInputAction:
            index == 0 ? TextInputAction.next : TextInputAction.done,
        maxLength: PersonalCode.groupLength,
        style: AppTextStyles.code,
        cursorColor: AppColors.brand,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
          const _UpperCaseFormatter(),
        ],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: '____',
          hintStyle: TextStyle(
            fontSize: 22,
            letterSpacing: 4,
            color: AppColors.inkFaint,
          ),
        ),
        onChanged: (String raw) => _handleChanged(index, raw),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
