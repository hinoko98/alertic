import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/panel_repository.dart';
import '../panel_layout.dart';
import '../widgets/bulk_code_dialogs.dart';
import '../widgets/new_person_sheets.dart';
import '../widgets/person_editor_sheet.dart';

/// Pantalla 19: comunidad y códigos.
///
/// Es la pestaña más delicada del panel: quien entra aquí puede generar el
/// código con el que alguien se registra. Por eso el listado **nunca** muestra
/// un código completo, solo su principio y en qué estado está.
class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  final TextEditingController _search = TextEditingController();

  List<CommunityMember> _members = <CommunityMember>[];
  CommunityStats? _stats;
  String? _role;
  bool _loading = true;

  /// Si la última carga falló: una lista vacía por un error no es lo mismo que
  /// una comunidad vacía, y decirlo igual haría creer que se perdieron los datos.
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final PanelRepository repository = AppScope.of(context).panelRepository!;
      final List<CommunityMember> members = await repository.loadCommunity(
        role: _role,
        query: _search.text,
      );
      final CommunityStats stats = await repository.loadStats();

      if (mounted) {
        setState(() {
          _members = members;
          _stats = stats;
          _failed = false;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'comunidad');
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CommunityStats? stats = _stats;
    final bool compact = PanelLayout.isCompact(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: PanelLayout.headerPadding(context),
          child: Flex(
            // En el computador el título y los botones van en una línea; en el
            // celular los botones bajan, porque tres botones y un título no
            // caben en 400 puntos sin que el texto se parta.
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Flexible(
                compact: compact,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'COMUNIDAD',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      stats == null
                          ? 'Cargando…'
                          : '${stats.total} personas · ${stats.activeCodes} '
                              'activas en la app · ${stats.pendingCodes} con '
                              'código pendiente',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (compact) const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _PanelButton(
                    icon: Icons.school_outlined,
                    label: 'NUEVO ESTUDIANTE',
                    filled: true,
                    onTap: _newStudent,
                  ),
                  _PanelButton(
                    icon: Icons.family_restroom_outlined,
                    label: 'NUEVO ACUDIENTE',
                    onTap: _newGuardian,
                  ),
                  _PanelButton(
                    icon: Icons.person_add_alt_outlined,
                    label: 'NUEVO DOCENTE',
                    onTap: _newTeacher,
                  ),
                  _PanelButton(
                    icon: Icons.upload_file_outlined,
                    label: 'CARGAR LISTA',
                    onTap: _importStudents,
                  ),
                  _PanelButton(
                    icon: Icons.qr_code_2_outlined,
                    label: 'CÓDIGOS POR GRUPO',
                    onTap: _groupCodes,
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: PanelLayout.gutter(context),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _RoleFilter(
                label: 'TODOS',
                selected: _role == null,
                onTap: () => _setRole(null),
              ),
              for (final ({String role, String label}) filter
                  in <({String role, String label})>[
                (role: 'estudiante', label: 'ESTUDIANTES'),
                (role: 'acudiente', label: 'ACUDIENTES'),
                (role: 'docente', label: 'DOCENTES'),
              ])
                _RoleFilter(
                  label: stats == null
                      ? filter.label
                      : '${filter.label} · ${stats.byRole[filter.role] ?? 0}',
                  selected: _role == filter.role,
                  onTap: () => _setRole(filter.role),
                ),
              // En el computador el buscador va al lado de los filtros. En el
              // celular no cabe, y baja a su propia línea: dentro de un `Wrap`
              // no se le puede pedir ancho infinito, porque el Wrap no acota a
              // sus hijos y el campo se saldría de la pantalla.
              if (!compact) SizedBox(width: 280, child: _searchField()),
            ],
          ),
        ),
        if (compact)
          Padding(
            padding: EdgeInsets.fromLTRB(
              PanelLayout.gutter(context),
              AppSpacing.sm,
              PanelLayout.gutter(context),
              0,
            ),
            child: _searchField(),
          ),
        const SizedBox(height: AppSpacing.lg),
        // La cabecera de la tabla solo tiene sentido si hay tabla debajo.
        if (!compact) ...<Widget>[const _TableHeader(), const Divider(height: 1)],
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _members.isEmpty
                  ? _EmptyCommunity(
                      filtered: _role != null || _search.text.trim().isNotEmpty,
                      failed: _failed,
                      onRetry: () {
                        setState(() => _loading = true);
                        _load();
                      },
                    )
                  : ListView.separated(
                  itemCount: _members.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) => _MemberRow(
                    member: _members[index],
                    compact: compact,
                    onTap: () => _edit(_members[index]),
                  ),
                ),
        ),
      ],
    );
  }

  /// El buscador. Se usa en dos sitios y se escribe una vez.
  Widget _searchField() {
    return TextField(
      controller: _search,
      onSubmitted: (_) => _load(),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o documento',
        hintStyle: AppTextStyles.caption,
        isDense: true,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.brand),
        ),
      ),
      style: AppTextStyles.body,
    );
  }

  void _setRole(String? role) {
    setState(() {
      _role = role;
      _loading = true;
    });
    _load();
  }

  /// Abre la hoja de una persona. Al guardar algo, el listado se recarga: lo que
  /// se ve es lo que quedó en el servidor, no lo que se escribió.
  void _edit(CommunityMember member) {
    showPersonEditor(context, member: member, onChanged: _load);
  }

  void _newTeacher() {
    showNewTeacherSheet(context, onChanged: _load);
  }

  void _newStudent() {
    showNewStudentSheet(context, onChanged: _load);
  }

  void _importStudents() {
    showImportStudents(context, onChanged: _load);
  }

  void _groupCodes() {
    showGroupCodes(context, onChanged: _load);
  }

  void _newGuardian() {
    showNewGuardianSheet(context, onChanged: _load);
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color foreground = filled ? AppColors.onBrand : AppColors.ink;

    return Material(
      color: filled ? AppColors.brand : AppColors.surface,
      shape: Border.fromBorderSide(
        BorderSide(color: filled ? AppColors.brand : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleFilter extends StatelessWidget {
  const _RoleFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
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
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: selected ? AppColors.onBrand : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          const Expanded(flex: 3, child: Text('NOMBRE', style: AppTextStyles.eyebrow)),
          const Expanded(flex: 2, child: Text('ROL', style: AppTextStyles.eyebrow)),
          const Expanded(flex: 2, child: Text('GRADO', style: AppTextStyles.eyebrow)),
          const Expanded(flex: 4, child: Text('VINCULADO CON', style: AppTextStyles.eyebrow)),
          const Expanded(flex: 2, child: Text('CÓDIGO', style: AppTextStyles.eyebrow)),
          const Expanded(flex: 2, child: Text('ESTADO', style: AppTextStyles.eyebrow)),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onTap, this.compact = false});

  final CommunityMember member;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Toda la fila se toca: en el celular un renglón de 40 puntos es un blanco
    // pequeño, y no hay un botón «editar» que apuntar con el dedo.
    return InkWell(onTap: onTap, child: _content(context));
  }

  Widget _content(BuildContext context) {
    // Seis columnas no caben en un celular sin dejar cuatro caracteres por
    // campo. En vertical se convierten en dos renglones y un distintivo.
    if (compact) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: PanelLayout.gutter(context),
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(member.fullName, style: AppTextStyles.itemTitle),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      _roleLabel(member.role),
                      if (member.grade != null) member.grade!,
                      if (member.linkedTo != null) member.linkedTo!,
                    ].join(' · '),
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.codeLabel == null
                        ? 'Sin código'
                        : member.codeLabel!,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusChip(status: member.codeStatus),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(member.fullName, style: AppTextStyles.itemTitle),
          ),
          Expanded(
            flex: 2,
            child: Text(_roleLabel(member.role), style: AppTextStyles.caption),
          ),
          Expanded(
            flex: 2,
            child: Text(member.grade ?? '—', style: AppTextStyles.caption),
          ),
          Expanded(
            flex: 4,
            child: Text(member.linkedTo ?? '—', style: AppTextStyles.caption),
          ),
          Expanded(
            flex: 2,
            child: Text(
              // Solo el principio. El código completo no existe en la base de
              // datos: se guarda hasheado.
              member.codeLabel ?? '—',
              style: AppTextStyles.caption.copyWith(fontFamily: 'monospace'),
            ),
          ),
          Expanded(flex: 2, child: _StatusChip(status: member.codeStatus)),
        ],
      ),
    );
  }

  static String _roleLabel(String role) => switch (role) {
        'estudiante' => 'Estudiante',
        'docente' => 'Docente',
        'acudiente' => 'Acudiente',
        'administrador' => 'Coordinación',
        _ => role,
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color background, Color foreground) = switch (status) {
      'usado' => ('ACTIVO', Colors.transparent, AppColors.brand),
      'pendiente' => ('PENDIENTE', AppColors.surfaceAlt, AppColors.inkMuted),
      'entregado' => ('SIN ENTREGAR', AppColors.ink, AppColors.onBrand),
      'vencido' => ('VENCIDO', AppColors.surfaceAlt, AppColors.brand),
      'revocado' => ('REVOCADO', AppColors.surfaceAlt, AppColors.inkFaint),
      'con_cuenta' => ('CON CUENTA', Colors.transparent, AppColors.brand),
      'sin_acceso' => ('SIN ACCESO', AppColors.surfaceAlt, AppColors.inkFaint),
      _ => ('SIN GENERAR', AppColors.surfaceAlt, AppColors.inkFaint),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: foreground,
          ),
        ),
      ),
    );
  }
}


/// Ocupa el ancho sobrante en horizontal y todo el ancho en vertical.
///
/// `Expanded` dentro de un [Flex] vertical estiraría el alto, que no es lo que
/// hace falta: en el celular el título ocupa su alto natural y los botones van
/// debajo.
class _Flexible extends StatelessWidget {
  const _Flexible({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return compact ? SizedBox(width: double.infinity, child: child) : Expanded(child: child);
  }
}

/// Lo que se ve cuando no hay nadie que mostrar.
///
/// Son tres situaciones distintas y se dicen distinto: el servidor no respondió,
/// la búsqueda no encontró nada, o la comunidad de verdad está vacía —el primer
/// día de un colegio—, y entonces dice por dónde empezar.
class _EmptyCommunity extends StatelessWidget {
  const _EmptyCommunity({
    required this.filtered,
    required this.failed,
    required this.onRetry,
  });

  final bool filtered;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (String title, String body) = failed
        ? (
            'NO PUDIMOS CARGAR LA COMUNIDAD',
            'Revisa que el servidor esté encendido e inténtalo otra vez.',
          )
        : filtered
            ? ('SIN RESULTADOS', 'Ninguna persona coincide con ese filtro o búsqueda.')
            : (
                'AÚN NO HAY NADIE',
                'Empieza dando de alta a un estudiante, a un acudiente o a un '
                    'docente con los botones de arriba. Cada estudiante y acudiente '
                    'recibe un código de un solo uso para entrar a la app.',
              );

    return Padding(
      padding: EdgeInsets.all(PanelLayout.gutter(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: AppTextStyles.screenTitle.copyWith(fontSize: 22)),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.body),
          if (failed) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _PanelButton(label: 'REINTENTAR', onTap: onRetry),
          ],
        ],
      ),
    );
  }
}
