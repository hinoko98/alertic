/// Textos de la app. Centralizados aqui para poder revisarlos con el colegio
/// sin tocar las pantallas.
abstract final class AppStrings {
  static const String appName = 'ALERTIC';
  static const String tagline = 'ALERTAS TEMPRANAS';
  static const String schoolName = 'Instituto Integrado de Comercio';
  static const String schoolCity = 'Barbosa, Santander';

  /// Los cuatro primeros caracteres de todos los códigos del colegio (`IICB` en
  /// `IICB-7K4P`). Es lo que el servidor tiene en `SCHOOL_CODE`; se puede
  /// cambiar al compilar con `--dart-define=SCHOOL_CODE=XXXX`.
  static const String schoolCode =
      String.fromEnvironment('SCHOOL_CODE', defaultValue: 'IICB');
}
