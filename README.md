# ALERTIC

Alertas tempranas para el Instituto Integrado de Comercio de Barbosa, Santander.
App en Flutter para estudiantes, docentes y acudientes.

## Levantar todo

Son tres cosas, cada una en su terminal. La API tiene que estar arriba antes que
las otras dos.

**1 · La API** (se queda corriendo)

```bash
cd ../alerticapi
npm install            # solo la primera vez
npm run admin:create -- correo@colegio.edu.co "Nombre Apellido"   # solo la primera vez
npm start              # http://localhost:3000
```

**2 · La app del celular**

```bash
cd alertic
flutter run --dart-define=ALERTIC_API=http://10.0.2.2:3000     # emulador de Android
flutter run --dart-define=ALERTIC_API=http://192.168.1.4:3000  # celular real (IP de tu PC)
```

`10.0.2.2` es el computador visto desde el emulador. Con un celular real es otra
cosa: ver **[Probar en tu celular](#probar-en-tu-celular)**, abajo.

**3 · El panel del colegio** (computador de coordinación)

```bash
flutter run -d windows -t lib/panel_main.dart --dart-define=ALERTIC_API=http://localhost:3000
```

Pide iniciar sesión y solo deja pasar a coordinación. En este equipo falta el
componente «Desarrollo para escritorio con C++» de Visual Studio, así que mientras
tanto sirve el mismo código en el navegador (el servidor permite el puerto 5173):

```bash
flutter run -d chrome --web-port 5173 -t lib/panel_main.dart --dart-define=ALERTIC_API=http://localhost:3000
```

### La app siempre habla con el servidor

**No hay datos de prueba ni modo demostración.** Lo que se ve es lo que hay en la
base de datos, aunque esté vacía. Sin `--dart-define=ALERTIC_API=...` la app usa
`http://localhost:3000` (en Android hace falta `adb reverse tcp:3000 tcp:3000`, también en el emulador) en web y
Windows; un celular real necesita su dirección (ver *Probar en tu celular*). En
VS Code, `.vscode/launch.json` trae las configuraciones con la dirección puesta.

La pantalla de bienvenida y la de inicio de sesión dicen si el servidor responde:

| Línea | Qué significa |
|---|---|
| 🟢 `Conectado · 10.0.2.2:3000` | El servidor respondió. |
| 🔴 `Sin conexión con 10.0.2.2:3000. Toca para reintentar.` | No respondió: API apagada, IP equivocada o cortafuegos. |

### Primer día: un colegio vacío

El servidor arranca **sin una sola persona**, con un punto de encuentro genérico y
un protocolo por amenaza (que coordinación reemplaza con lo suyo). El único acceso
lo crea esta herramienta, con contraseña aleatoria que se muestra una vez:

```bash
cd ../alerticapi
npm run admin:create -- coordinacion@iic.edu.co "Nombre Apellido"
```

Entra con **YA TENGO CUENTA**. Desde **Comunidad** se da de alta a cada estudiante,
acudiente y docente (cada estudiante y acudiente recibe su código de un solo uso);
desde **Protocolos**, se editan los protocolos y los puntos de encuentro. Se puede
**crear, editar y eliminar**; a un docente que emitió alertas se le da de baja en
vez de eliminarlo, para conservar su historial. Para restablecer el acceso del
administrador, vuelve a correr el mismo comando con su correo.

**Cargar un colegio entero.** En **Comunidad**, **CARGAR LISTA** recibe una línea
por estudiante, `Nombre; Grupo; Documento; Acudiente; Documento del acudiente` (del
documento en adelante es opcional; el acudiente lleva nombre y documento juntos y,
con el mismo documento en varias líneas, los hermanos comparten acudiente; sirve
pegar desde Excel). Si una línea está mal no se carga ninguna y se dice cuál.
Termina en la lista de códigos de todos, ordenada por grupo, con **COPIAR TODO**
para llevarla a una hoja de cálculo y de ahí a los carnés. **CÓDIGOS POR GRUPO**
emite los de los grupos que se elijan (con o sin sus acudientes) y, si se marca
«reemplazar», cambia también los vigentes sin usar.

**Los códigos duran una hora.** Un código que nadie valida en una hora vence: la
persona aparece como **VENCIDO** en Comunidad y **CÓDIGOS POR GRUPO** (o **EMITIR
CÓDIGO NUEVO** en su ficha) le genera otro. Mientras está vigente, coordinación lo
ve completo en la lista y en la ficha.

**El código.** Ocho caracteres: `IICB-7K4P`. Los cuatro primeros son del colegio
(`SCHOOL_CODE` en el servidor; en la app, `--dart-define=SCHOOL_CODE=XXXX`, mismo
valor) y vienen escritos al registrarse; los cuatro últimos son de la persona.

Los datos de prueba solo existen para las **pruebas automáticas** (`test/`). Para
las de integración se siembran en una base **aparte** con `npm run seed:demo`.

### Si el emulador de Android se queda en negro

En este equipo, **cualquier** app de Flutter (incluida la que genera
`flutter create`) sale en negro cuando el emulador usa la GPU del host. La app
arranca bien, Android reporta «Fully drawn», pero no se dibuja nada.

La solución es arrancar el emulador con renderizado por software:

```bash
"$ANDROID_HOME/emulator/emulator" -avd Pixel_7 -gpu swiftshader_indirect
```

o, en Android Studio, en el AVD Manager: *Edit* → *Emulated Performance* →
*Graphics: Software*. Con eso la app se ve normal.

Dos detalles más del emulador:

- Si la pantalla del emulador está dormida cuando se lanza la app, Android la
  mata con un ANR («Application does not have a focused window»). Conviene
  despertarla antes y subir el tiempo de apagado.
- `android/app/src/debug/AndroidManifest.xml` debe conservar el permiso
  `INTERNET`. Sin él, el VM service no puede abrir su socket y `flutter run`
  falla con *Error connecting to the service protocol*, sin hot reload.

En un celular real no hace falta nada de esto.

## Probar en tu celular

El emulador y un celular real se parecen poco en lo que importa aquí: el
emulador ve tu computador como `10.0.2.2`, y un celular **no sabe quién es tu
computador**. Hay tres formas de decírselo, de la más fácil a la más lejana.

### A · Con cable USB (la recomendada: no depende del wifi ni del cortafuegos)

1. En el celular: **Ajustes → Acerca del teléfono** → toca siete veces «Número de
   compilación». Vuelve a Ajustes → **Opciones de desarrollador** → activa
   **Depuración USB**.
2. Conéctalo al computador y acepta la ventana «¿Permitir depuración USB?».
   `adb devices` tiene que listarlo.
3. Hazle ver la API del computador **como si fuera suya**:

   ```bash
   adb reverse tcp:3000 tcp:3000
   ```

   Desde el celular, `localhost:3000` pasa a ser la API de tu computador. Hay que
   repetirlo cada vez que desconectes y vuelvas a conectar el cable.
4. Con la API corriendo (`cd ../alerticapi && npm start`):

   ```bash
   flutter run --dart-define=ALERTIC_API=http://localhost:3000
   ```

### B · Por wifi, sin cable

El celular y el computador tienen que estar **en el mismo wifi**.

1. La IP del computador en ese wifi: `ipconfig`, la «Dirección IPv4» del adaptador
   de LAN inalámbrica (algo como `192.168.1.4`).
2. Deja pasar la API por el cortafuegos de Windows, **una sola vez**, en una
   PowerShell de administrador:

   ```powershell
   New-NetFirewallRule -DisplayName "ALERTIC API" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow -Profile Private
   ```

3. Compruébalo **antes de abrir la app**: en el navegador del celular abre
   `http://192.168.1.4:3000/health`. Si responde `{"ok":true,...}`, la app también
   llegará. Si no, el problema es de red y no de ALERTIC.
4. `flutter run --dart-define=ALERTIC_API=http://192.168.1.4:3000`

**Si no llega**: un wifi de colegio, de universidad o de un café suele tener
«aislamiento de clientes» y no deja que un dispositivo vea a otro. Usa la
opción A o tu propio celular como punto de acceso.

### Instalar el APK, sin cable ni `flutter run`

```bash
flutter build apk --release --dart-define=ALERTIC_API=http://192.168.1.4:3000
```

Queda en `build/app/outputs/flutter-apk/app-release.apk`. Pásalo al celular (por
cable, Drive o WhatsApp) e instálalo; Android pide permiso para «instalar apps de
orígenes desconocidos». Está firmado con la llave de depuración: sirve para
probar, **no** para Play Store.

> **El APK de release necesita el permiso `INTERNET`.** Flutter solo lo declara en
> los manifiestos de depuración, y un APK de release sin él instala bien y no
> conecta con nada. Está declarado en
> [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml).

### Qué comprobar en el celular

| | Qué debes ver |
|---|---|
| Pantalla de bienvenida | 🟢 `Conectado · …` (si dice 🟠 «datos de prueba», falta el `--dart-define`) |
| Primer inicio de sesión | Android pregunta si permites **notificaciones**: acepta |
| Celular registrado | `cd ../alerticapi && npm run fcm:check`, y la tabla `device_tokens` tiene una fila |
| Alerta roja con la app **cerrada** | Aviso flotante arriba; al tocarlo, abre la alerta |
| Cerrar sesión | Vuelve a la bienvenida, y una alerta nueva ya no llega |

Las notificaciones con el celular bloqueado, y los fabricantes con ahorro de
batería agresivo (Xiaomi, Huawei, Oppo), **solo se pueden comprobar en un celular
real**; el emulador no los reproduce. Ver [FIREBASE.md](FIREBASE.md).

### Desde cualquier red, con HTTPS

Los celulares de otras personas no están en tu wifi. Para eso la API tiene que
estar en internet con HTTPS: ver **[Publicarlo](../alerticapi/README.md#publicarlo)**
en el README de la API. Para una demostración sin desplegar nada, un túnel
(`cloudflared tunnel --url http://localhost:3000`) te da una dirección `https://`
temporal que apunta a tu computador; esa dirección es el valor de
`ALERTIC_API`. *No lo he probado en este equipo.*

## Estructura

```
lib/
  main.dart        app móvil (estudiante, docente, acudiente)
  panel_main.dart  panel del colegio (bloque F)
  app/             arranque, rutas, shell por rol y dependencias
  core/            tema, red, sesión, errores y redacción de datos personales
    notifications/ canales de Android, push de Firebase y registro del celular
  shared/          widgets que usan varias pantallas
  features/
    onboarding/    bloque A: registro (01 a 06) y el inicio de sesión con
                   correo de docentes y administradores
    alerts/        bloque B: alertas por nivel (07 a 09) y protocolos
    student/       bloque C: app del estudiante (10 a 12, guía y perfil)
    teacher/       bloque D: app del docente (13 a 15)
    guardian/      bloque E: app del acudiente (16 y 17)
    panel/         bloque F: tablero, comunidad, historial y protocolos (18 y 19)
    session/       sesión emitida por el servidor
```

Cada feature se divide en `domain/` (modelo y reglas, sin Flutter), `data/`
(acceso a datos) y `presentation/` (pantallas y widgets).

**Dos apps, un proyecto.** La app móvil y el panel del colegio tienen puntos de
entrada distintos porque responden preguntas distintas —«¿qué hago yo?» contra
«¿cómo va el colegio?»— pero comparten dominio, tema y repositorios.

## Patrones de diseño

No están puestos por cumplir: cada uno resuelve algo que ya dolía.

| Patrón | Dónde | Qué resuelve |
|---|---|---|
| **Abstract Factory** (creacional) | `app/role_experience.dart` | Cada rol produce su propia familia de pantallas. El shell no sabe qué rol muestra; agregar el docente es escribir una fábrica, no tocar la navegación. |
| **Factory Method** (creacional) | `alerts/presentation/widgets/alert_level_style.dart` | Un solo sitio convierte el nivel de alerta en colores, tamaños y acciones. Las pantallas no preguntan «si es roja entonces...». |
| **Decorator** (estructural) | `alerts/data/logging_alert_repository.dart` | Agrega registro y medición al repositorio sin que el repositorio envuelto ni las pantallas lo sepan. Se puede apilar con caché o reintentos. |
| **Decorator de árbol** (estructural) | `alerts/presentation/widgets/alert_gate.dart` | Envuelve el shell para que una alerta entre por encima de cualquier pestaña abierta. |
| **Composition root** | `app/app_scope.dart` | Un punto donde se arman las dependencias y se inyectan dobles en las pruebas, sin traer un paquete de inyección. |
| **Adapter** (estructural) | `*/data/api_*_repository.dart` | Traduce lo que responde la API al modelo del dominio, y sus errores HTTP a fallos con mensaje en español. Cambiar de backend no toca ninguna pantalla. |
| **Interface segregation** | `teacher/domain`, `guardian/domain` | Cada rol tiene su propia interfaz. La app del estudiante no puede ni nombrar «emitir alerta». |
| **Clase sellada intermedia** | `onboarding/domain/enrollment.dart` | `CodeEnrollment` agrupa a quienes entran con código. El compilador impide pedirle el código a un docente y obliga a cubrir cada rol nuevo en todos los `switch`. |
| **Null Object** (comportamental) | `core/notifications/silent_notification_service.dart` | El panel de Windows y las pruebas usan un servicio que no notifica, en vez de repartir comprobaciones de nulo por toda la app. No es un doble de prueba: es el caso legítimo «esta plataforma no tiene notificaciones». |

## Seguridad

Decisiones tomadas y por qué:

- **El rol lo decide el servidor, no la app.** El perfil y el token llegan en la
  respuesta a confirmar identidad (`Session.role`). Si el rol se dedujera del
  código escrito, bastaría con modificar la app para entrar como docente y
  emitir alertas a todo el instituto.
- **Quemar el código es del backend.** El código es de un solo uso; validarlo en
  el celular permitiría usarlo dos veces. El cliente solo revisa el formato para
  no mandar llamadas inútiles.
- **Todo lo que entra se valida.** `Alert.validated` rechaza alertas sin
  instrucciones, sin nivel conocido, con textos más largos de lo que cabe en
  pantalla o con caracteres de control; `AlertLevel.tryParse` y `Hazard.tryParse`
  no interpretan valores desconocidos. Una alerta que no se entiende no se
  muestra a medias.
- **Sin campos de texto libre.** Reportar una emergencia y decir dónde se está
  son listas cerradas. En una emergencia nadie escribe, y un texto libre que sale
  del celular de un menor hacia la pantalla del colegio es una entrada más que
  limpiar y moderar.
- **Nada personal en los logs.** Todo lo que se registra pasa por
  `core/security/redaction.dart`: el código queda en `IICB-••••`, el nombre
  en iniciales, el token nunca se escribe y la ubicación solo dice si había GPS.
  `PersonalCode.toString()` sale redactado a propósito, porque `toString` es lo
  que se cuela sin querer en una interpolación.
- **La sesión no se guarda en texto plano.** Hoy vive solo en memoria
  (`InMemorySessionStore`): al cerrar la app hay que registrarse otra vez. Es
  preferible eso a escribir un token en un almacenamiento sin cifrar. Queda
  pendiente `flutter_secure_storage` cuando exista el backend.
- **Cerrar sesión borra primero.** Se limpia el token antes de navegar, para que
  un fallo posterior no lo deje guardado.

- **Emitir una alerta exige sostener el botón.** Un toque se da sin querer con
  el celular en el bolsillo; sonarle a 1.248 personas no puede pasar por
  accidente. Es la única fricción deliberada de toda la app.
- **La alerta no le toma la pantalla al acudiente.** Las instrucciones
  («cúbrete», «sal en fila») son para quien está dentro del colegio. A una madre
  que va manejando le quitarían justo lo que necesita: el estado de sus hijos.
- **Aviso si la API no usa HTTPS.** `AppConfig.isInsecureTransport` lo registra
  al arrancar; un token viajando en claro se lee desde cualquier punto del
  camino. Se permite `http` solo contra direcciones de red local.

Pendiente para cuando la API salga a internet: *certificate pinning*, borrar la
sesión ante un 401, y `FLAG_SECURE` en las pantallas con datos de menores.

## Estado

- Bloque A · registro: pantallas 01 a 06.
- Bloque B · alertas: 07 a 09, los tres niveles.
- Bloque C · estudiante: 10 a 12, más guía y perfil.
- Bloque D · docente: 13 a 15, con emisión de alertas y lista del grupo.
- Bloque E · acudiente: 16 y 17.
- Bloque F · panel del colegio: emergencia, comunidad, historial y protocolos,
  en Windows y en el celular del administrador.
- Acceso por rol: código para estudiantes y acudientes; correo y contraseña
  para docentes y administradores.
- Backend: `../alerticapi`, conectado para **todos los roles**: registro, alertas,
  protocolos, lista del grupo, hijos del acudiente, panel y reportes.
- Reportes de emergencia de la comunidad, de punta a punta y en vivo.
- Notificaciones: el código está completo y probado. Falta enlazar tu proyecto de
  Firebase — ver **[FIREBASE.md](FIREBASE.md)**, no cuesta nada. Sin eso la app
  compila y corre igual; lo que falta es el aviso con el celular guardado.
- Coordinación administra la comunidad: grupo de cada estudiante, docentes
  (crear, cambiar, dar de baja), director de grupo, y credenciales.
- Los cuatro roles pueden cerrar sesión; docentes y coordinación, cambiar su
  contraseña.
- Coordinación carga una lista de estudiantes pegada desde Excel o el SIMAT
  (**CARGAR LISTA**) y emite los códigos de uno o varios grupos de una vez
  (**CÓDIGOS POR GRUPO**).
- **Pendiente**: leer el archivo del SIMAT directamente (hoy se pega el texto),
  «enviar
  actualización» a la comunidad, GPS en los reportes y la sesión en almacenamiento
  cifrado (hoy vive en memoria: al cerrar la app hay que volver a entrar). Las
  contraseñas temporales no caducan ni obligan a cambiarlas en el primer ingreso.

Cómo levantarlo, con y sin servidor, y las cuentas de prueba: ver **[Levantar
todo](#levantar-todo)** arriba.

## Mapa y ruta en vivo (pantallas 08 y 09)

El estudiante ve dónde está y hacia dónde ir, en vivo:

- **Mapa de evacuación.** Punto azul con el margen de error del GPS (`GPS ±6 m`), el
  punto de encuentro, la ruta que falta, la distancia y el tiempo caminando. Puede
  escoger otro punto del colegio; el asignado sale como «Recomendado».
- **Ruta guiada.** Una flecha que apunta hacia dónde ir, los metros restantes, la barra
  de avance, el tramo ya recorrido en gris, y los pasos que escribió el colegio. A menos
  de 15 m del punto, la app da por llegada a la persona y pasa a la confirmación.
  Incluye «Ruta bloqueada» y «Necesito ayuda».

**Qué es y qué no es el mapa.** Es un plano de coordenadas reales con escala y norte,
dibujado por la app: **no trae calles ni edificios inventados** y funciona sin internet
(el GPS no necesita datos). Si el colegio quiere un plano con bloques, se agrega después
con el plano verdadero.

**Cómo se ubica un punto de encuentro.** En el panel: Protocolos → punto de encuentro →
«Usar mi ubicación actual», parado en el punto. Mientras un punto no tenga coordenadas, la
app dice que no está ubicado y deja solo las indicaciones escritas (no inventa una ruta).

**Privacidad.** La ubicación se lee **solo mientras la pantalla del mapa o de la ruta está
abierta** y se apaga al salir. Se queda en el celular: la app no envía la posición del
estudiante al servidor. Permiso: `ACCESS_FINE_LOCATION` (Android) y
`NSLocationWhenInUseUsageDescription` (iOS), «mientras se usa la app».

Código: `core/location/` (`geo.dart`, `location_service.dart`, `location_tracker.dart`) y
`features/student/presentation/widgets/live_route_map.dart`. En las pruebas se mueve a la
persona con `FakeLocationService`.

## Reportes de emergencia y tiempo real

### Un estudiante ve humo y lo avisa

El botón **«REPORTAR EMERGENCIA»** del estudiante manda el reporte al servidor, que
se lo hace llegar **al director de grupo y a coordinación**, en vivo y con una
notificación si hay Firebase. Antes mostraba «enviado a tu docente» sin mandar
nada: un estudiante que reportara un incendio creería haber avisado y nadie se
enteraría.

- **Solo dice «enviado» si el servidor lo confirmó.** Si no llegó, dice
  «No se pudo enviar el reporte. Avisa a tu docente en persona».
- **Nunca emite una alerta.** Avisa, y un docente o coordinación decide: puede
  marcarlo *atendido*, *descartarlo* o **convertirlo en alerta** (la pantalla de
  emitir ya viene con la amenaza escogida y el reporte queda enlazado a la alerta
  que motivó).
- **Cada quien ve lo suyo.** Un docente recibe los reportes de los estudiantes de
  sus grupos, no los de otro salón; coordinación, todos; quien reporta, solo la
  confirmación.
- **No se puede usar para hacer ruido.** Un doble toque no duplica el reporte, y
  cada persona puede mandar hasta cuatro en diez minutos. El límite es **por
  persona y no por IP**: en el colegio todos salen por la misma dirección.

### Todo se mueve solo

Una sola conexión en vivo (`ApiEventHub`) la comparten todas las pantallas de un
celular. Cuando algo cambia, el servidor avisa y la pantalla vuelve a pedir lo
suyo:

| Pantalla | Se actualiza cuando… |
|---|---|
| Tablero de coordinación | alguien reporta que está a salvo o pide ayuda |
| Bandeja de reportes | un estudiante reporta, o alguien atiende uno |
| Lista del grupo (docente) | un estudiante de su grupo responde |
| Hijos (acudiente) | uno de **sus** hijos responde |
| Alerta activa (todos) | se emite o se finaliza una alerta |

El aviso es solo «algo cambió, vuelve a preguntar», **nunca un dato**. Por eso un
aviso perdido no deja números viejos para siempre, y por eso el servidor puede
decidir a quién le manda qué sin filtrar información: un estudiante no recibe
avisos de lo que hacen los demás, y un acudiente solo se entera de sus hijos.

Durante una alerta roja pueden llegar mil reportes en un minuto. El servidor los
agrupa (un aviso cada ~0,8 s por pantalla) y la app no lanza una segunda consulta
del tablero mientras la primera sigue en camino.

### Cifras reales, no escritas en la app

Se quitaron los números inventados: *«Llega a 1248 personas»*, *«34 matriculados ·
32 presentes · Aula 7»*, *«REPORTES · 1»* y un teléfono de coordinación que se le
mostraba a un acudiente. Ahora vienen del servidor. Si el servidor no tiene el
dato, la pantalla lo dice (`—`, «el colegio todavía no publicó un número») en vez
de inventar uno.

## Quién entra por dónde

| | Estudiantes y acudientes | Docentes y administradores |
|---|---|---|
| Botón | **EMPEZAR** | **YA TENGO CUENTA** |
| Credencial | Código del carné, un solo uso | Correo y contraseña |
| Pantalla «¿eres tú?» | Sí | No: acaban de escribir su propia contraseña |

**Por qué no un solo método.** Registrar 1.248 personas en unos pocos días con
correo y contraseña dejaría por fuera a un niño de sexto y a una madre que quizá
no tiene correo. El código resuelve eso: se imprime en el carné y se usa una vez.

Pero quien puede **emitir una alerta para todo el colegio** no entra con un
papel. Un código impreso se queda sobre un escritorio, se fotografía y no se
puede cambiar; una contraseña se cambia y se revoca sin cambiar ningún papel.

Esto está en los tipos, no solo en una comprobación: `CodeEnrollment` es una
clase sellada que solo heredan `StudentEnrollment` y `GuardianEnrollment`. La
pantalla de confirmar identidad recibe un `CodeEnrollment`, así que **el
compilador impide** pedirle el código a un docente, que no tiene.

### El administrador lleva el panel en el celular

Son **las mismas cuatro pantallas** que corren en el computador de coordinación
—Emergencia, Comunidad, Historial, Protocolos—, no una versión reducida: se
adaptan al ancho en `PanelLayout`. A ellas se suma **Cuenta**, con los datos de
quien entró, el cambio de contraseña y **cerrar sesión**.

No están duplicadas a propósito. Duplicarlas significaría que el día que cambie
el tablero hay que acordarse de cambiarlo dos veces, y en una emergencia la
versión olvidada es la que alguien está mirando. En el computador la comunidad es
una tabla de seis columnas; en el celular, tarjetas. `test/panel_responsive_test.dart`
comprueba los dos anchos para que arreglar uno no rompa el otro en silencio.

### Coordinación administra la comunidad

Tocar a cualquier persona en **Comunidad** abre su hoja. Qué se puede cambiar
depende de quién es:

| | Se puede cambiar | Credencial |
|---|---|---|
| Estudiante | Nombre, **grupo**, jornada, salón | Emitir **código nuevo**, cerrar sesiones |
| Acudiente | Nombre | Emitir **código nuevo**, cerrar sesiones |
| Docente | Nombre, correo, materia, **director de grupo**, **grupos que dicta** | **Restablecer contraseña**, cerrar sesiones, **dar de baja** |
| Coordinación | Nada desde el panel | — |

**Nuevo docente** crea la cuenta: es la única forma de que un docente nuevo entre,
porque no tiene código. La contraseña la elige el servidor y se muestra **una sola
vez**; coordinación no puede volver a verla, ni nadie.

Las reglas viven en el servidor, no en la app:

- **Un grupo, un director.** Quien toma un grupo lo dirige y el anterior deja de
  hacerlo; la hoja avisa antes de guardar («Hoy lo dirige Carlos Jaimes») y
  después («Carlos Jaimes dejó de dirigir 10° B»). El director siempre dicta en su
  grupo.
- **Al cambiar de grupo a un estudiante**, hereda el salón y el director del grupo
  nuevo. Conservar el salón del grupo anterior lo mandaría, en una evacuación, a un
  sitio que ya no es el suyo.
- **Un docente con acceso tiene al menos un grupo**: sin él, su pantalla de inicio
  no tendría nada que mostrar.
- **Cambiar una credencial cierra las sesiones de esa persona.** Restablecer una
  contraseña que deja entrar con la vieja no restablece nada. El servidor sube una
  «versión de sesión» por persona y comprueba el token contra ella en cada
  petición; también borra los celulares registrados, para que un teléfono perdido
  deje de recibir avisos con el nombre de un menor.
- **Dar de baja** no borra a nadie: lo que reportó e hizo en alertas anteriores
  tiene que poder consultarse. Para que vuelva se le asignan grupos y se le
  restablece la contraseña.

Cada docente puede **cambiar su propia contraseña** desde la pestaña **Cuenta**.
Pide la actual aunque haya sesión (un celular prestado y desbloqueado no basta),
cierra sus otras sesiones y deja esta abierta.

**A coordinación tampoco se le toma la pantalla con la alerta.** Su teléfono es el
que está dirigiendo la evacuación: bloquearlo con «estoy a salvo / necesito
ayuda» le esconde el tablero a la única persona que puede ver quién pidió ayuda y
finalizar la alerta. El servidor tampoco la cuenta en el tablero —los conteos son
de estudiantes y docentes—, así que no falta su respuesta. Es la misma decisión
que ya se había tomado con el acudiente, por la misma razón: taparle la pantalla
a quien está afuera le quita justo lo que necesita mirar.

## Notificaciones

Ver **[FIREBASE.md](FIREBASE.md)** para conectarlas. Las decisiones de diseño:

- **El servidor manda solo datos, no un aviso ya armado.** Firebase puede mandar
  un bloque `notification` que el sistema dibuja solo, sin despertar la app. Es
  más simple y no se usa: ese camino no permite pedir `fullScreenIntent`, que es
  lo que hace que la alerta roja tome la pantalla de un celular bloqueado, ni
  que el mismo mensaje se comporte distinto según el rol.
- **Un canal por nivel.** Así alguien puede silenciar los avisos amarillos, que
  son informativos, sin poder silenciar los rojos. El canal rojo usa el volumen
  de **alarma** y no el de notificaciones: un celular en silencio tiene las
  notificaciones calladas pero la alarma viva, que es lo que hace falta a las
  nueve de la mañana en un salón.
- **Al acudiente no se le toma la pantalla.** Lo decide el servidor mandando a
  un tema distinto por rol. Las instrucciones de evacuación son para quien está
  dentro del edificio; a una madre manejando le taparían justo lo que necesita
  ver. Es la misma decisión que ya tomaba `AlertGate`.
- **Un tema por rol, no un envío por celular.** Una alerta son tres peticiones a
  Firebase en vez de 1.248. Con envíos uno por uno, mandar la alerta tomaría
  minutos: exactamente el tiempo que no hay.
- **En la bandeja del sistema solo queda el identificador de la alerta.** Esa
  bandeja sobrevive al cierre de la app y la lee cualquiera que tenga el
  teléfono en la mano. El aviso de «tu hijo pidió ayuda» va además con
  `visibility: private`: en la pantalla bloqueada se ve que hay algo de ALERTIC,
  y el nombre aparece al desbloquear.
- **La carga del push se valida como entrada hostil.** Llega por la red y se
  interpreta en un aislado sin pantalla, donde un error no se puede mostrar ni
  reportar. `AlertNotification.tryFrom` nunca lanza: descarta lo que no entiende
  y recorta lo que viene largo.

### Cerrar sesión da de baja el celular

`signOutOfDevice` (`lib/app/sign_out.dart`) hace tres cosas, en este orden: da de
baja el celular en el servidor **mientras la sesión todavía vale**, borra la
sesión guardada y suelta el token del cliente de red. Si la baja saliera después,
saldría sin permiso. Nunca falla: cerrar sesión no puede depender de que haya red.

Los cuatro roles tienen el botón: el estudiante en su **Perfil**, y docentes,
acudientes y coordinación en la pestaña **Cuenta** (`AccountScreen`). Todos usan
`confirmAndSignOut`, que **pregunta antes**: cerrar sesión da de baja el celular,
y quien lo toca sin querer deja de recibir alertas; a un estudiante o a una madre,
además, no los deja volver a entrar sin otro código. El mensaje cambia según cómo
entra cada uno.

### Sin internet

El push necesita internet, y eso no tiene vuelta. La respuesta es por capas:

| Capa | Cómo | Funciona cuando |
|---|---|---|
| 1. Firebase | Push normal | Hay datos o wifi con internet |
| 2. Wifi del colegio | El panel de Windows hace de servidor local y la app recibe por SSE en la red local | **Se cayó el internet** pero el wifi del colegio sigue |
| 3. SMS | Pasarela (Hablame, Masiv) | Hay señal celular sin datos |
| 4. Sirena | La del colegio | Siempre |

La capa 2 es la que más conviene y casi no cuesta: en una emergencia lo primero
que se cae es la fibra del ISP, pero el switch y el wifi siguen con UPS, y el
panel ya es un servidor. Falta anunciarlo en la red local (mDNS) y que la app lo
busque. La app deduplica por identificador de alerta, así que acepta lo primero
que llegue sin mostrar la alerta dos veces.

Sin nada de red, lo que ya está hecho: protocolos, plano y punto de encuentro
quedan guardados en el celular y se leen sin señal.

## Diseño y estructura (v2)

La app sigue las pantallas de `ALERTIC_Pantallas.V2.pdf`: tarjetas redondeadas, color
de marca carmesí, insignias (`Pill`), y un encabezado con el chat y «Ayuda». Los
componentes viven en `lib/shared/design/` (`AppPage`, `AppCard`, `Pill`, `IconBubble`,
`StatusBanner`, `SectionLabel`, `AppBottomNav`).

| Rol | Pestañas |
|---|---|
| Estudiante | Inicio · Mapa · Guías · Reportar · Perfil (el chat con el colegio y «Ayuda» están en el encabezado) |
| Docente | Inicio · Guías · Reportar · Mensajes · Cuenta |
| Acudiente | Inicio · Guías · Reportar · Perfil (el chat está en el encabezado) |
| Coordinación | Emergencia · Comunidad · Mensajes · Más · Cuenta (en «Más»: Simulacros, Reportes de riesgo, Historial, Protocolos) |

**Chat.** Estudiante y acudiente escriben al colegio; lo atiende su director de grupo o
coordinación (`features/support`). Los avisos llegan en vivo (`LiveChange.chat`) y por
push sin el texto del mensaje.

## Pruebas

```bash
flutter analyze
flutter test                                      # todo, incluidas las de integración
flutter test --exclude-tags integracion           # sin necesitar el servidor
```

Las pruebas de `test/integration/` hablan con la API de verdad. Si no está
corriendo, **se saltan** en vez de fallar. Si un código de registro ya se quemó
(son de un solo uso), también se saltan: vuelve a sembrar la base de pruebas con `DATABASE_FILE=./data/demo.db npm run seed:demo`.

El servidor tiene las suyas, con una base de datos en memoria que no toca tus
datos: `cd ../alerticapi && npm test` (172 pruebas).

**Sin código QR.** Se decidió no implementarlo. Se quitó el escáner del registro,
el botón de imprimir carnés del panel, y el QR dibujado de la pantalla de entrega
del acudiente —que no se podía escanear y decía «el docente lo escanea y queda
registrada la entrega»—. Esa pantalla ahora dice lo que sí es cierto: qué llevar
y a quién se va a recoger.
