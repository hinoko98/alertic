import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'response_cache.dart';

/// La caché en el celular, en SQLite.
///
/// Una sola tabla con el cuerpo de cada respuesta como JSON: lo que se guarda es
/// exactamente lo que mandó el servidor, y se vuelve a leer con los mismos
/// traductores. Así no hay un segundo esquema que mantener al día con el de la
/// API.
class SqliteResponseCache implements ResponseCache {
  SqliteResponseCache({this.fileName = 'alertic_cache.db'});

  final String fileName;
  Future<Database>? _db;

  Future<Database> _open() => _db ??= () async {
        final String dir = await getDatabasesPath();
        return openDatabase(
          '$dir/$fileName',
          version: 1,
          onCreate: (Database db, int version) => db.execute(
            'CREATE TABLE responses ('
            '  key TEXT PRIMARY KEY,'
            '  body TEXT NOT NULL,'
            '  saved_at TEXT NOT NULL'
            ')',
          ),
        );
      }();

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows =
        await db.query('responses', columns: <String>['body'], where: 'key = ?', whereArgs: <Object>[key]);
    if (rows.isEmpty) return null;
    final Object? decoded = jsonDecode(rows.single['body']! as String);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> body) async {
    final Database db = await _open();
    await db.insert(
      'responses',
      <String, Object>{
        'key': key,
        'body': jsonEncode(body),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear() async {
    final Database db = await _open();
    await db.delete('responses');
  }
}
