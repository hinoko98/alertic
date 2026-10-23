import 'package:alertic/features/onboarding/data/profile_mapper.dart';
import 'package:alertic/features/onboarding/domain/enrollment.dart';
import 'package:flutter_test/flutter_test.dart';

/// La tarea que coordinación le asigna a un docente llega en su perfil.
void main() {
  Map<String, dynamic> profile(Object? task) => <String, dynamic>{
        'id': 't1',
        'fullName': 'Laura Gómez',
        'role': 'docente',
        'subject': 'Matemáticas',
        'groups': <String>['9° B'],
        'homeroomGroup': '9° B',
        'emergencyTask': ?task,
      };

  TeacherEnrollment parse(Object? task) =>
      ProfileMapper.map(profile(task)) as TeacherEnrollment;

  test('con tarea, la trae con su detalle', () {
    final TeacherEnrollment teacher = parse(<String, dynamic>{
      'title': 'Guiar a 9.° B al Punto A',
      'detail': 'Por la escalera sur y pasar lista al llegar',
    });

    expect(teacher.emergencyTask?.title, 'Guiar a 9.° B al Punto A');
    expect(teacher.emergencyTask?.detail, 'Por la escalera sur y pasar lista al llegar');
  });

  test('sin tarea, no inventa ninguna', () {
    expect(parse(null).emergencyTask, isNull);
  });

  test('una tarea sin título se descarta en vez de mostrarse a medias', () {
    expect(parse(<String, dynamic>{'title': '  ', 'detail': 'algo'}).emergencyTask, isNull);
  });
}
