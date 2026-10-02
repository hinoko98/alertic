import 'package:flutter/material.dart';

import '../../domain/hazard.dart';

/// Ícono de cada amenaza.
///
/// Vive aquí, y no dentro del enum, para que el dominio no dependa de Flutter:
/// las reglas del protocolo tienen que poder probarse sin levantar la interfaz.
IconData hazardIcon(Hazard hazard) {
  return switch (hazard) {
    Hazard.lluvia => Icons.thunderstorm_outlined,
    Hazard.inundacion => Icons.waves_outlined,
    Hazard.sismo => Icons.monitor_heart_outlined,
    Hazard.incendio => Icons.local_fire_department_outlined,
  };
}
