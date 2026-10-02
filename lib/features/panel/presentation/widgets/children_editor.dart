import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/community_admin.dart';
import '../../domain/panel_repository.dart';
import 'admin_fields.dart';

/// Un estudiante a cargo de un acudiente, tal como se edita en la hoja.
class ChildEntry {
  const ChildEntry({
    required this.studentId,
    required this.name,
    required this.relationship,
    this.grade,
  });

  final String studentId;
  final String name;
  final String relationship;
  final String? grade;

  ChildEntry withRelationship(String value) => ChildEntry(
        studentId: studentId,
        name: name,
        grade: grade,
        relationship: value,
      );

  ChildLink toLink() => ChildLink(studentId: studentId, relationship: relationship);

  static ChildEntry fromLinked(LinkedPerson person) => ChildEntry(
        studentId: person.id,
        name: person.fullName,
        grade: person.grade,
        relationship: person.relationship,
      );
}

/// Los estudiantes a cargo de un acudiente: quién, y con qué parentesco.
///
/// Es el vínculo que decide a quién le llega el aviso «tu hijo necesita ayuda».
/// Por eso los estudiantes se **buscan en la matrícula** y no se escriben: un
/// nombre mal tecleado enlazaría a una familia con el menor equivocado.
class ChildrenEditor extends StatelessWidget {
  const ChildrenEditor({
    required this.children,
    required this.onChanged,
    super.key,
  });

  final List<ChildEntry> children;
  final ValueChanged<List<ChildEntry>> onChanged;

  static const List<String> _relationships = <String>['Madre', 'Padre', 'Acudiente'];

  Future<void> _add(BuildContext context) async {
    final CommunityMember? picked = await showStudentPicker(
      context,
      exclude: <String>{for (final ChildEntry c in children) c.studentId},
    );
    if (picked != null) {
      onChanged(<ChildEntry>[
        ...children,
        ChildEntry(
          studentId: picked.id,
          name: picked.fullName,
          grade: picked.grade,
          relationship: 'Acudiente',
        ),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Sin estudiantes a cargo todavía.',
              style: AppTextStyles.caption,
            ),
          ),
        for (int i = 0; i < children.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        children[i].grade == null
                            ? children[i].name
                            : '${children[i].name} · ${children[i].grade}',
                        style: AppTextStyles.itemTitle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => onChanged(<ChildEntry>[
                        for (int j = 0; j < children.length; j++)
                          if (j != i) children[j],
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String relationship in _relationships)
                      ChoiceBox(
                        label: relationship.toUpperCase(),
                        selected: children[i].relationship == relationship,
                        onTap: () => onChanged(<ChildEntry>[
                          for (int j = 0; j < children.length; j++)
                            j == i ? children[j].withRelationship(relationship) : children[j],
                        ]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: SheetButton(
            label: '+ AGREGAR ESTUDIANTE',
            onTap: () => _add(context),
          ),
        ),
      ],
    );
  }
}

/// Busca un estudiante en la matrícula y lo devuelve.
Future<CommunityMember?> showStudentPicker(
  BuildContext context, {
  Set<String> exclude = const <String>{},
}) {
  return showModalBottomSheet<CommunityMember>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext context) => _StudentPicker(exclude: exclude),
  );
}

class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.exclude});

  final Set<String> exclude;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  final TextEditingController _search = TextEditingController();

  List<CommunityMember> _results = <CommunityMember>[];
  bool _loading = true;
  bool _failed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final PanelRepository repository = AppScope.of(context).panelRepository!;
      final List<CommunityMember> found = await repository.loadCommunity(
        role: 'estudiante',
        query: _search.text,
      );
      if (mounted) {
        setState(() {
          _results = <CommunityMember>[
            for (final CommunityMember m in found)
              if (!widget.exclude.contains(m.id)) m,
          ];
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'buscar estudiantes');
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Buscar estudiante',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: TextField(
              controller: _search,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Nombre o documento',
                hintStyle: AppTextStyles.caption,
                isDense: true,
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: _load,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    ),
                  )
                : _failed
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'No pudimos buscar. Revisa la conexión.',
                          style: AppTextStyles.body,
                        ),
                      )
                    : _results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Text(
                              'No hay estudiantes que coincidan. Si todavía no '
                              'está en la matrícula, dalo de alta primero.',
                              style: AppTextStyles.caption,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _results.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final CommunityMember member = _results[index];
                              return ListTile(
                                title: Text(member.fullName, style: AppTextStyles.itemTitle),
                                subtitle: Text(
                                  member.grade ?? 'Sin grupo',
                                  style: AppTextStyles.caption,
                                ),
                                onTap: () => Navigator.of(context).pop(member),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
