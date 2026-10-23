import 'package:shared_preferences/shared_preferences.dart';

/// Qué tan grande se ve la letra en la pantalla de una alerta.
///
/// Es aparte del tamaño de letra del sistema: se multiplica con él. Sirve para
/// que quien lee mal de cerca pueda agrandar **solo** lo que importa en una
/// emergencia sin agrandar toda la app.
enum AlertTextSize {
  normal(wire: 'normal', label: 'Normal', scale: 1.0),
  large(wire: 'grande', label: 'Grande', scale: 1.15),
  extraLarge(wire: 'muy_grande', label: 'Muy grande', scale: 1.3);

  const AlertTextSize({required this.wire, required this.label, required this.scale});

  final String wire;
  final String label;
  final double scale;

  static AlertTextSize fromWire(String? value) {
    for (final AlertTextSize size in values) {
      if (size.wire == value) return size;
    }
    return AlertTextSize.normal;
  }
}

/// Cómo quiere esta persona que le llegue una alerta **en este celular**.
///
/// Vive en el celular y no en el colegio: la vibración y el tamaño de letra
/// dependen del aparato, y un celular nuevo empieza con los valores de fábrica.
/// Lo que sí es del colegio —sonar aunque esté en silencio— está en los ajustes
/// de la cuenta.
class AlertPreferences {
  const AlertPreferences({
    this.strongVibration = false,
    this.textSize = AlertTextSize.normal,
  });

  /// Vibrar en un patrón fuerte y repetido, para sentir la alerta sin oírla.
  final bool strongVibration;
  final AlertTextSize textSize;

  AlertPreferences copyWith({bool? strongVibration, AlertTextSize? textSize}) {
    return AlertPreferences(
      strongVibration: strongVibration ?? this.strongVibration,
      textSize: textSize ?? this.textSize,
    );
  }
}

/// Guarda y lee las [AlertPreferences] del celular.
abstract final class AlertPreferencesStore {
  static const String _vibrationKey = 'alerta-vibracion-fuerte';
  static const String _sizeKey = 'alerta-tamano-letra';

  static Future<AlertPreferences> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AlertPreferences(
      strongVibration: prefs.getBool(_vibrationKey) ?? false,
      textSize: AlertTextSize.fromWire(prefs.getString(_sizeKey)),
    );
  }

  static Future<void> save(AlertPreferences preferences) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, preferences.strongVibration);
    await prefs.setString(_sizeKey, preferences.textSize.wire);
  }
}
