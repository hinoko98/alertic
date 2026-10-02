import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../domain/community_admin.dart';
import '../../domain/group_name.dart';

/// Piezas de formulario del panel de coordinación. Cuadradas y sin sombra, como
/// el resto del panel.

/// Título de una sección del formulario.
class FormSection extends StatelessWidget {
  const FormSection(this.label, {this.hint, super.key});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: AppTextStyles.eyebrow),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(hint!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

/// Campo de texto con su etiqueta encima.
class AdminTextField extends StatelessWidget {
  const AdminTextField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLength,
    this.enabled = true,
    this.obscureText = false,
    this.suffix,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool enabled;

  /// Para contraseñas: no se ve lo que se escribe, y el teclado no la guarda en
  /// su diccionario de sugerencias.
  final bool obscureText;

  /// Algo al final del campo, como el ojo de «mostrar contraseña».
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    const OutlineInputBorder square = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.border),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLength: maxLength,
        obscureText: obscureText,
        enableSuggestions: !obscureText,
        autocorrect: !obscureText,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffix,
          labelStyle: AppTextStyles.caption,
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.all(AppSpacing.md),
          border: square,
          enabledBorder: square,
          disabledBorder: square,
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.brand),
          ),
        ),
      ),
    );
  }
}

/// Una opción seleccionable, cuadrada.
class ChoiceBox extends StatelessWidget {
  const ChoiceBox({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.surface,
      shape: Border.fromBorderSide(
        BorderSide(color: selected ? AppColors.ink : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: selected ? AppColors.onBrand : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Elige grupos de la lista del colegio.
///
/// Una de dos formas: **uno** (el grupo de un estudiante, el que dirige un
/// docente) o **varios** (los que dicta). Los grupos salen del servidor, así que
/// coordinación elige en vez de escribir; si falta uno, «+ OTRO» lo agrega con el
/// formato correcto.
class GroupPicker extends StatefulWidget {
  const GroupPicker.single({
    required this.groups,
    required this.selected,
    required this.onChanged,
    this.allowNone = false,
    super.key,
  }) : multiple = false;

  const GroupPicker.multiple({
    required this.groups,
    required this.selected,
    required this.onChanged,
    super.key,
  })  : multiple = true,
        allowNone = false;

  final List<GroupInfo> groups;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool multiple;

  /// Con grupo único, deja elegir «ninguno» (un docente que no dirige).
  final bool allowNone;

  @override
  State<GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<GroupPicker> {
  /// Grupos que coordinación agregó a mano y todavía no existen en el servidor.
  final Set<String> _added = <String>{};

  List<String> get _names {
    final Set<String> all = <String>{
      for (final GroupInfo group in widget.groups) group.grade,
      ..._added,
      ...widget.selected,
    };
    return all.toList()..sort(GroupName.compare);
  }

  void _toggle(String grade) {
    if (!widget.multiple) {
      widget.onChanged(<String>{grade});
      return;
    }
    final Set<String> next = Set<String>.of(widget.selected);
    if (!next.remove(grade)) {
      next.add(grade);
    }
    widget.onChanged(next);
  }

  Future<void> _addOther() async {
    final String? created = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _GroupNameDialog(),
    );

    if (created != null && mounted) {
      setState(() => _added.add(created));
      _toggle(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        if (widget.allowNone)
          ChoiceBox(
            label: 'NINGUNO',
            selected: widget.selected.isEmpty,
            onTap: () => widget.onChanged(<String>{}),
          ),
        for (final String grade in _names)
          ChoiceBox(
            label: grade,
            selected: widget.selected.contains(grade),
            onTap: () => _toggle(grade),
          ),
        ChoiceBox(label: '+ OTRO', selected: false, onTap: _addOther),
      ],
    );
  }
}

/// Aviso en línea dentro de una hoja: un error que no se puede perder.
///
/// Un `SnackBar` queda **detrás** de una hoja modal y no se ve; y quien corrige un
/// formulario necesita leer el motivo mientras lo hace.
class InlineNotice extends StatelessWidget {
  const InlineNotice(this.message, {this.isError = true, super.key});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isError ? AppColors.surface : AppColors.surfaceAlt,
        border: Border.all(color: isError ? AppColors.brand : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: isError ? AppColors.brand : AppColors.ink,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTextStyles.caption.copyWith(color: AppColors.ink))),
        ],
      ),
    );
  }
}

/// Botón de acción dentro de una hoja.
class SheetButton extends StatelessWidget {
  const SheetButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.destructive = false,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool destructive;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final Color color = filled
        ? AppColors.onBrand
        : destructive
            ? AppColors.brand
            : AppColors.ink;

    return Material(
      color: filled ? AppColors.brand : AppColors.surface,
      shape: Border.fromBorderSide(
        BorderSide(color: filled ? AppColors.brand : AppColors.border),
      ),
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: onTap == null ? AppColors.inkFaint : color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado de una hoja: qué es, a quién se refiere, y cómo cerrarla.
class SheetHeader extends StatelessWidget {
  const SheetHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(subtitle.toUpperCase(), style: AppTextStyles.eyebrow),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Elige el punto de encuentro de un estudiante entre los del colegio.
class MeetingPointPicker extends StatelessWidget {
  const MeetingPointPicker({
    required this.points,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<MeetingPoint> points;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final MeetingPoint point in points)
          ChoiceBox(
            label: '${point.code} · ${point.name}'.toUpperCase(),
            selected: selected.contains(point.code),
            onTap: () => onChanged(<String>{point.code}),
          ),
      ],
    );
  }
}

/// Pide el nombre de un grupo que todavía no existe.
///
/// Es un widget con estado y no un diálogo armado en una función: el controlador
/// del campo tiene que vivir **mientras el diálogo se anima al cerrarse**. Liberarlo
/// en cuanto `showDialog` devuelve —lo que se hacía— hacía que el campo, todavía
/// en pantalla, usara un controlador ya liberado.
class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog();

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _accept() {
    final String? grade = GroupName.normalize(_controller.text);
    if (grade == null) {
      setState(() => _error = 'Escríbelo como «9° C»: grado y letra.');
      return;
    }
    Navigator.of(context).pop(grade);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(),
      title: const Text('Otro grupo'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(hintText: 'Por ejemplo 9° C', errorText: _error),
        onSubmitted: (_) => _accept(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        TextButton(onPressed: _accept, child: const Text('AGREGAR')),
      ],
    );
  }
}
