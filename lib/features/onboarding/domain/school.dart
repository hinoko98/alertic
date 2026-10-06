/// El colegio al que apunta un código.
///
/// Lo dice el servidor: la app no sabe de qué colegio es hasta que la persona
/// escribe los cuatro primeros caracteres de su carné.
class School {
  const School({required this.name, required this.city});

  final String name;
  final String city;
}
