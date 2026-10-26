import 'package:flutter/material.dart';

import 'web_style.dart';

/// Círculo con iniciales (`.av`).
class WebAvatar extends StatelessWidget {
  const WebAvatar(this.name, {this.dark = false, super.key});

  final String name;
  final bool dark;

  static String initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '—';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: dark ? WebColors.brand : WebColors.chip,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials(name),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: dark ? Colors.white : WebColors.ink,
        ),
      ),
    );
  }
}

/// Interruptor del diseño (`.tog`).
class WebToggle extends StatelessWidget {
  const WebToggle({required this.value, required this.onChanged, this.label, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: value,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? WebColors.brand : const Color(0xFFC5CBD2),
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// Fila «título + explicación + interruptor».
class WebToggleRow extends StatelessWidget {
  const WebToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: WebText.strong),
              if (subtitle != null) Text(subtitle!, style: WebText.small),
            ],
          ),
        ),
        const SizedBox(width: 12),
        WebToggle(value: value, onChanged: onChanged, label: title),
      ],
    );
  }
}

/// Botón de opción (`.op`): uno entre varios, o varios a la vez.
class WebOption extends StatelessWidget {
  const WebOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Punto de color antes del texto (nivel de alerta).
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? WebColors.brandSoftest : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? WebColors.brand : WebColors.field,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (dot != null) ...<Widget>[
                Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF8A1C2D) : WebColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un campo con su etiqueta y cualquier control debajo (`.fld`).
class WebLabeled extends StatelessWidget {
  const WebLabeled({required this.label, required this.child, this.hint, super.key});

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: WebText.label),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...<Widget>[const SizedBox(height: 4), Text(hint!, style: WebText.small)],
      ],
    );
  }
}

/// Lista desplegable con el aspecto de los campos del panel.
class WebSelect<T> extends StatelessWidget {
  const WebSelect({
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.width,
    super.key,
  });

  final T? value;

  /// Valor → texto.
  final Map<T, String> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final double? width;

  @override
  Widget build(BuildContext context) {
    const OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: WebColors.field),
    );
    final Widget field = DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: items.containsKey(value) ? value : null,
      isExpanded: true,
      style: WebText.body,
      decoration: const InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: border,
        enabledBorder: border,
      ),
      items: <DropdownMenuItem<T>>[
        for (final MapEntry<T, String> e in items.entries)
          DropdownMenuItem<T>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
    final Widget sized = width == null ? field : SizedBox(width: width, child: field);
    return label == null ? sized : WebLabeled(label: label!, child: sized);
  }
}

/// Área de texto (`.ta`).
class WebTextArea extends StatelessWidget {
  const WebTextArea({
    required this.controller,
    this.label,
    this.hint,
    this.minLines = 3,
    this.maxLength,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final int minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    const OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: WebColors.field),
    );
    final Widget field = TextField(
      controller: controller,
      minLines: minLines,
      maxLines: null,
      maxLength: maxLength,
      onChanged: onChanged,
      style: WebText.body,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(12),
        border: border,
        enabledBorder: border,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: WebColors.brand),
        ),
      ),
    );
    return label == null ? field : WebLabeled(label: label!, child: field);
  }
}

/// Caja de búsqueda (`.search`).
class WebSearchBox extends StatelessWidget {
  const WebSearchBox({required this.controller, required this.onChanged, this.hint = 'Buscar', super.key});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: WebText.body,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 18, color: WebColors.inkMuted),
          filled: true,
          fillColor: WebColors.page,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: WebColors.field),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: WebColors.field),
          ),
        ),
      ),
    );
  }
}

/// Tabla del diseño (`.tbl`): encabezado en mayúsculas pequeñas, filas con línea
/// y desplazamiento horizontal si no cabe.
class WebTable extends StatelessWidget {
  const WebTable({required this.headers, required this.rows, this.empty = 'Sin resultados.', super.key});

  final List<String> headers;
  final List<List<Widget>> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(empty, style: WebText.small)),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: const TableBorder(
                horizontalInside: BorderSide(color: WebColors.lineSoft),
              ),
              children: <TableRow>[
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: WebColors.line)),
                  ),
                  children: <Widget>[
                    for (final String h in headers)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Text(h.toUpperCase(), style: WebText.th),
                      ),
                  ],
                ),
                for (final List<Widget> row in rows)
                  TableRow(
                    children: <Widget>[
                      for (final Widget cell in row)
                        Padding(padding: const EdgeInsets.all(12), child: cell),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Franja de aviso con icono: información, advertencia o éxito.
class WebNotice extends StatelessWidget {
  const WebNotice(this.text, {this.icon = Icons.info_outline, this.tone = WebChipTone.neutral, super.key});

  final String text;
  final IconData icon;
  final WebChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      WebChipTone.good => (WebColors.goodSoft, WebColors.goodText),
      WebChipTone.warn => (WebColors.warnSoft, WebColors.warnText),
      WebChipTone.brand => (WebColors.brandSoft, const Color(0xFF8A1C2D)),
      _ => (WebColors.page, const Color(0xFF4A5560)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: fg, height: 1.4))),
        ],
      ),
    );
  }
}

/// Lo que se muestra donde el diseño pide algo que el servidor todavía no
/// ofrece. Lo dice con claridad en vez de dibujar datos inventados.
class WebUnavailable extends StatelessWidget {
  const WebUnavailable({required this.title, required this.detail, this.icon = Icons.construction_outlined, super.key});

  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WebIconBubble(icon, tone: WebChipTone.neutral),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: WebText.strong),
                const SizedBox(height: 2),
                Text(detail, style: WebText.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta el resultado de un [Future]: cargando, error con «Reintentar», o los
/// datos.
class WebFuture<T> extends StatelessWidget {
  const WebFuture({
    required this.future,
    required this.builder,
    required this.onRetry,
    this.errorText = 'No pudimos cargar esta información.',
    super.key,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<T> snap) {
        if (snap.connectionState != ConnectionState.done) return const WebLoadState();
        if (snap.hasError) return WebLoadState(error: errorText, onRetry: onRetry);
        return builder(context, snap.data as T);
      },
    );
  }
}

/// Un par «etiqueta · valor» de las fichas de detalle.
class WebKeyValue extends StatelessWidget {
  const WebKeyValue(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: WebText.kpiLabel)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: WebText.strong)),
        ],
      ),
    );
  }
}

/// Texto de una persona con subtítulo debajo, para las celdas.
class WebTitleSub extends StatelessWidget {
  const WebTitleSub(this.title, {this.sub, this.onTap, super.key});

  final String title;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget titleText = Text(
      title,
      style: WebText.strong.copyWith(color: onTap == null ? WebColors.ink : WebColors.brandDark),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        onTap == null ? titleText : InkWell(onTap: onTap, child: titleText),
        if (sub != null) Text(sub!, style: WebText.small),
      ],
    );
  }
}

/// Mensaje breve al pie de la pantalla.
void webToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? WebColors.brand : WebColors.ink,
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );
}

/// Pregunta de confirmación; devuelve `true` si la persona acepta.
Future<bool> webConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirmar',
  bool danger = false,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: danger ? WebColors.brand : WebColors.ink),
          child: Text(confirm.toUpperCase()),
        ),
      ],
    ),
  );
  return ok ?? false;
}
