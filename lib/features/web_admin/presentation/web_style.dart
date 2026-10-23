import 'package:flutter/material.dart';

/// Tokens del panel web, tal como los define el diseño (`.web` del lienzo).
///
/// Son aparte de [AppColors] a propósito: el panel es una superficie de
/// trabajo con su propia paleta (menú lateral oscuro, tarjetas blancas sobre
/// gris), y los colores semánticos de nivel de la app móvil no se mezclan aquí.
abstract final class WebColors {
  static const Color brand = Color(0xFFB3263A);
  static const Color brandDark = Color(0xFF9E1F32);
  static const Color brandSoft = Color(0xFFFBEAEC);
  static const Color brandSoftest = Color(0xFFFDF4F5);

  static const Color ink = Color(0xFF1C2731);
  static const Color inkMuted = Color(0xFF5B6670);
  static const Color inkFaint = Color(0xFF8A939C);

  static const Color page = Color(0xFFF4F5F7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE3E6EA);
  static const Color lineSoft = Color(0xFFEEF0F3);
  static const Color field = Color(0xFFD5DAE0);
  static const Color chip = Color(0xFFE7EAEE);

  static const Color good = Color(0xFF1F6B45);
  static const Color goodText = Color(0xFF1F5C3D);
  static const Color goodSoft = Color(0xFFEAF3EE);
  static const Color goodLine = Color(0xFFBFDCCB);

  static const Color warn = Color(0xFF8A5A00);
  static const Color warnText = Color(0xFF7A4F00);
  static const Color warnSoft = Color(0xFFFFF3DC);

  static const Color sideText = Color(0xFFC5CBD2);
  static const Color sideMuted = Color(0xFFAEB6BE);
}

/// Anchos donde el panel cambia de forma.
abstract final class WebBreakpoints {
  /// Por debajo, el menú lateral pasa a un cajón.
  static const double drawer = 900;

  /// Por debajo, los márgenes se aprietan.
  static const double narrow = 700;

  static bool isDrawer(BuildContext context) =>
      MediaQuery.sizeOf(context).width < drawer;

  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < narrow;
}

const TextStyle _base = TextStyle(color: WebColors.ink, height: 1.3);

/// Estilos de texto del panel.
abstract final class WebText {
  static final TextStyle title =
      _base.copyWith(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3);
  static final TextStyle sub =
      _base.copyWith(fontSize: 13, color: WebColors.inkMuted);
  static final TextStyle panelTitle =
      _base.copyWith(fontSize: 16, fontWeight: FontWeight.w800);
  static final TextStyle label = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: const Color(0xFF4A5560),
  );
  static final TextStyle kpiLabel =
      _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: WebColors.inkMuted);
  static final TextStyle kpi = _base.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.1,
  );
  static final TextStyle strong =
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w700);
  static final TextStyle body = _base.copyWith(fontSize: 14);
  static final TextStyle small =
      _base.copyWith(fontSize: 13, color: WebColors.inkMuted);
  static final TextStyle th = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: WebColors.inkMuted,
  );
}

/// La tarjeta blanca del diseño (`.panel`).
class WebPanel extends StatelessWidget {
  const WebPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = WebColors.card,
    this.borderColor = WebColors.line,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// Encabezado de una tarjeta: título (y subtítulo) a la izquierda, acción a la
/// derecha.
class WebPanelHeader extends StatelessWidget {
  const WebPanelHeader({required this.title, this.subtitle, this.trailing, super.key});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: WebText.panelTitle),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(subtitle!, style: WebText.small),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

enum WebChipTone { neutral, brand, good, warn, dark }

/// La insignia redonda (`.chip`).
class WebChip extends StatelessWidget {
  const WebChip(this.label, {this.tone = WebChipTone.neutral, super.key});

  final String label;
  final WebChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      WebChipTone.neutral => (WebColors.chip, const Color(0xFF2F3A44)),
      WebChipTone.brand => (WebColors.brandSoft, const Color(0xFF8A1C2D)),
      WebChipTone.good => (WebColors.goodSoft, WebColors.goodText),
      WebChipTone.warn => (WebColors.warnSoft, WebColors.warnText),
      WebChipTone.dark => (WebColors.ink, Colors.white),
    };
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Botón principal (`.wbtn`) o secundario (`.wbtn2`).
class WebButton extends StatelessWidget {
  const WebButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.small = false,
    this.dark = false,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool small;
  final bool dark;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final Color bg = secondary ? WebColors.card : (dark ? WebColors.ink : WebColors.brand);
    final Color fg = secondary ? WebColors.ink : Colors.white;
    return SizedBox(
      height: small ? 36 : 44,
      child: TextButton(
        onPressed: busy ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.6),
          disabledForegroundColor: fg,
          padding: EdgeInsets.symmetric(horizontal: small ? 12 : 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: secondary ? const BorderSide(color: WebColors.field) : BorderSide.none,
          ),
          textStyle: TextStyle(
            fontSize: small ? 13 : 14,
            fontWeight: secondary ? FontWeight.w600 : FontWeight.w700,
          ),
        ),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

/// Círculo con icono (`.wico`).
class WebIconBubble extends StatelessWidget {
  const WebIconBubble(this.icon, {this.tone = WebChipTone.brand, super.key});

  final IconData icon;
  final WebChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      WebChipTone.good => (WebColors.goodSoft, WebColors.good),
      WebChipTone.warn => (WebColors.warnSoft, WebColors.warn),
      WebChipTone.neutral || WebChipTone.dark => (WebColors.chip, WebColors.ink),
      WebChipTone.brand => (WebColors.brandSoft, WebColors.brand),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

/// Barra de avance (`.meter`).
class WebMeter extends StatelessWidget {
  const WebMeter({required this.fraction, this.color = WebColors.ink, this.height = 10, super.key});

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: WebColors.chip,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0, 1).toDouble(),
          child: Container(color: color),
        ),
      ),
    );
  }
}

/// Tarjeta de cifra (`.k` y `.v`).
class WebStat extends StatelessWidget {
  const WebStat({
    required this.label,
    required this.value,
    this.valueColor = WebColors.ink,
    this.note,
    this.noteColor = WebColors.inkMuted,
    super.key,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String? note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: WebText.kpiLabel),
          const SizedBox(height: 6),
          Text(value, style: WebText.kpi.copyWith(color: valueColor)),
          if (note != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              note!,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: noteColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reparte [children] en columnas que se apilan cuando no caben (`.g4`, `.g2`).
class WebGrid extends StatelessWidget {
  const WebGrid({required this.children, this.minWidth = 200, this.gap = 16, super.key});

  final List<Widget> children;
  final double minWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final int columns =
            ((box.maxWidth + gap) / (minWidth + gap)).floor().clamp(1, children.length);
        // Por filas y con IntrinsicHeight: las tarjetas de una misma fila miden
        // lo mismo aunque una traiga una nota más.
        final List<Widget> rows = <Widget>[];
        for (int start = 0; start < children.length; start += columns) {
          final List<Widget> slice = children.skip(start).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < columns; i++) ...<Widget>[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(child: i < slice.length ? slice[i] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

/// Dos columnas 2:1 que se apilan en pantallas angostas (`.g21`).
class WebSplit extends StatelessWidget {
  const WebSplit({required this.main, required this.side, super.key});

  final Widget main;
  final Widget side;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        if (box.maxWidth < 880) {
          return Column(children: <Widget>[main, const SizedBox(height: 16), side]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 2, child: main),
            const SizedBox(width: 16),
            Expanded(child: side),
          ],
        );
      },
    );
  }
}

/// Campo de texto del panel (`.fld` + `.inp`): etiqueta arriba, borde que se
/// pinta de marca al enfocar.
class WebField extends StatelessWidget {
  const WebField({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.hint,
    this.autofillHints,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.suffix,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final String? hint;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final FocusNode? focusNode;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    const OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: WebColors.field),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: WebText.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: !obscure,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          style: WebText.body,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: border,
            enabledBorder: border,
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: WebColors.brand),
            ),
          ),
        ),
      ],
    );
  }
}

/// Aviso de error debajo de un formulario.
class WebErrorNote extends StatelessWidget {
  const WebErrorNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.error_outline, size: 16, color: WebColors.brand),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: WebColors.brand),
          ),
        ),
      ],
    );
  }
}

/// Texto que se muestra mientras algo carga o cuando no se pudo cargar.
class WebLoadState extends StatelessWidget {
  const WebLoadState({this.error, this.onRetry, super.key});

  /// Nulo mientras carga.
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: error == null
            ? const CircularProgressIndicator(color: WebColors.brand)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(error!, style: WebText.small, textAlign: TextAlign.center),
                  if (onRetry != null) ...<Widget>[
                    const SizedBox(height: 12),
                    WebButton(label: 'Reintentar', secondary: true, small: true, onPressed: onRetry),
                  ],
                ],
              ),
      ),
    );
  }
}
