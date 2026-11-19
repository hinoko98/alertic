import '../../alerts/domain/alert_level.dart';
import '../../alerts/domain/hazard.dart';

/// Vigilancia de amenazas: qué fuentes consulta el servidor, con qué umbrales y
/// cómo les fue en la última consulta.
///
/// Las fuentes solo **sugieren**: ninguna emite una alerta por su cuenta. Lo
/// decide una persona de coordinación o un docente.
class HazardWatchOverview {
  const HazardWatchOverview({
    required this.settings,
    required this.sources,
    required this.watching,
    required this.place,
    this.latitude,
    this.longitude,
  });

  final HazardSettings settings;
  final List<HazardSourceStatus> sources;

  /// Si el servidor tiene encendida la vigilancia. Apagada (pruebas, sin
  /// internet), los ajustes se guardan pero no se consulta nada.
  final bool watching;

  /// Dónde se vigila: «Instituto Integrado de Comercio · Barbosa, Santander».
  final String place;
  final double? latitude;
  final double? longitude;
}

/// Cómo le fue a una fuente en su última consulta.
class HazardSourceStatus {
  const HazardSourceStatus({
    required this.key,
    required this.label,
    required this.enabled,
    this.lastRunAt,
    this.lastOkAt,
    this.lastError,
    this.lastCount = 0,
  });

  /// `sismos`, `lluvia` o `creciente`.
  final String key;
  final String label;
  final bool enabled;
  final DateTime? lastRunAt;
  final DateTime? lastOkAt;

  /// El error de la última consulta, o null si salió bien.
  final String? lastError;
  final int lastCount;

  bool get failing => lastError != null;
}

/// Los umbrales que coordinación puede afinar.
class HazardSettings {
  const HazardSettings({
    required this.pollMinutes,
    required this.quakesEnabled,
    required this.quakeMinMagnitude,
    required this.quakeRadiusKm,
    required this.rainEnabled,
    required this.rainMmNext6h,
    required this.floodEnabled,
    required this.floodRainMm,
    required this.floodDischargeRatio,
  });

  final int pollMinutes;

  final bool quakesEnabled;
  final double quakeMinMagnitude;
  final int quakeRadiusKm;

  final bool rainEnabled;
  final double rainMmNext6h;

  /// Creciente súbita o avalancha de río.
  final bool floodEnabled;
  final double floodRainMm;
  final double floodDischargeRatio;

  HazardSettings copyWith({
    int? pollMinutes,
    bool? quakesEnabled,
    double? quakeMinMagnitude,
    int? quakeRadiusKm,
    bool? rainEnabled,
    double? rainMmNext6h,
    bool? floodEnabled,
    double? floodRainMm,
    double? floodDischargeRatio,
  }) {
    return HazardSettings(
      pollMinutes: pollMinutes ?? this.pollMinutes,
      quakesEnabled: quakesEnabled ?? this.quakesEnabled,
      quakeMinMagnitude: quakeMinMagnitude ?? this.quakeMinMagnitude,
      quakeRadiusKm: quakeRadiusKm ?? this.quakeRadiusKm,
      rainEnabled: rainEnabled ?? this.rainEnabled,
      rainMmNext6h: rainMmNext6h ?? this.rainMmNext6h,
      floodEnabled: floodEnabled ?? this.floodEnabled,
      floodRainMm: floodRainMm ?? this.floodRainMm,
      floodDischargeRatio: floodDischargeRatio ?? this.floodDischargeRatio,
    );
  }

  /// Tal como lo espera `PATCH /hazards/settings`.
  Map<String, Object?> toJson() => <String, Object?>{
        'general': <String, Object?>{'pollMinutes': pollMinutes},
        'sismos': <String, Object?>{
          'enabled': quakesEnabled,
          'minMagnitude': quakeMinMagnitude,
          'radiusKm': quakeRadiusKm,
        },
        'lluvia': <String, Object?>{'enabled': rainEnabled, 'mmNext6h': rainMmNext6h},
        'creciente': <String, Object?>{
          'enabled': floodEnabled,
          'rainMm': floodRainMm,
          'dischargeRatio': floodDischargeRatio,
        },
      };
}

/// Un aviso que escribe una persona, porque ninguna fuente lo detecta: un
/// incendio, sobre todo. Nace pendiente de que **otra** persona lo apruebe.
class ManualHazardReport {
  const ManualHazardReport({
    required this.hazard,
    required this.detail,
    this.headline,
    this.suggestedLevel,
  });

  final Hazard hazard;

  /// Qué y dónde: «Humo saliendo del laboratorio 2».
  final String detail;
  final String? headline;
  final AlertLevel? suggestedLevel;

  Map<String, Object?> toJson() => <String, Object?>{
        'hazard': hazard.wire,
        'detail': detail.trim(),
        if (headline != null && headline!.trim().isNotEmpty) 'headline': headline!.trim(),
        if (suggestedLevel != null) 'suggestedLevel': suggestedLevel!.wire,
      };
}

/// En qué va un aviso.
enum SignalStatus {
  pending('nueva'),
  attended('atendida'),
  dismissed('descartada');

  const SignalStatus(this.wire);

  final String wire;
}
