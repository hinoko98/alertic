import 'community_admin.dart';
import 'group_name.dart';

/// Lo que salió de leer una lista pegada: los estudiantes, o por qué no se pudo.
class StudentListResult {
  const StudentListResult.ok(this.students) : error = null;
  const StudentListResult.failed(this.error) : students = const <NewStudent>[];

  final List<NewStudent> students;

  /// Dice qué línea está mal, para corregirla en el mismo cuadro.
  final String? error;
}

/// Lee una lista de estudiantes pegada desde una hoja de cálculo o el SIMAT.
///
/// Una línea por estudiante: `Nombre ; Grupo ; Documento ; Acudiente ; Documento
/// del acudiente`. Del documento en adelante todo es opcional; el acudiente lleva
/// su nombre y su documento juntos (con el mismo documento en varias líneas, los
/// hermanos comparten acudiente). Separa por tabulador (lo que pega Excel), por punto y coma o, si
/// no hay ninguno, por coma. La primera línea puede ser el encabezado.
///
/// Solo se arregla el grupo (`10b` → `10° B`); el nombre y el documento los valida
/// el servidor, que es quien los conoce todos.
abstract final class StudentListParser {
  /// Lo que acepta el servidor por carga.
  static const int maxStudents = 300;

  static StudentListResult parse(String text) {
    final List<String> lines = text
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    final List<NewStudent> students = <NewStudent>[];

    for (int i = 0; i < lines.length; i++) {
      final List<String> cells = _split(lines[i]);

      if (cells.length < 2) {
        return StudentListResult.failed(
          'Línea ${i + 1}: falta el grupo. Escribe «Nombre completo; 10° B».',
        );
      }

      final String? grade = GroupName.normalize(cells[1]);
      if (grade == null) {
        // Un encabezado («Nombre; Grupo») no es un estudiante.
        if (i == 0 && cells[1].toLowerCase().contains('grupo')) {
          continue;
        }
        return StudentListResult.failed(
          'Línea ${i + 1}: no entiendo el grupo «${cells[1]}». Escríbelo como 10° B.',
        );
      }

      String cell(int index) => cells.length > index ? cells[index] : '';

      final String guardianName = cell(3);
      final String guardianDocument = cell(4);
      if (guardianName.isEmpty != guardianDocument.isEmpty) {
        return StudentListResult.failed(
          'Línea ${i + 1}: el acudiente necesita nombre y documento.',
        );
      }

      students.add(
        NewStudent(
          fullName: cells[0],
          grade: grade,
          document: cell(2).isEmpty ? null : cell(2),
          guardianName: guardianName.isEmpty ? null : guardianName,
          guardianDocument: guardianDocument.isEmpty ? null : guardianDocument,
        ),
      );
    }

    if (students.isEmpty) {
      return const StudentListResult.failed('Pega al menos un estudiante.');
    }
    if (students.length > maxStudents) {
      return StudentListResult.failed(
        'Son ${students.length} estudiantes; el máximo por vez es $maxStudents. '
        'Envíalos por grupos.',
      );
    }
    return StudentListResult.ok(students);
  }

  static List<String> _split(String line) {
    final String separator = line.contains('\t')
        ? '\t'
        : line.contains(';')
            ? ';'
            : ',';
    return line.split(separator).map((String cell) => cell.trim()).toList();
  }
}
