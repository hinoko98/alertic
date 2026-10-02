# Conectar Firebase para las notificaciones

El código de notificaciones está escrito y probado. Lo que falta es **enlazar tu
proyecto de Firebase** con la app y con el servidor, y son dos archivos distintos
que van a dos sitios distintos:

| Archivo | Para qué | Dónde va |
|---|---|---|
| `google-services.json` | Que **la app** sepa a qué proyecto pertenece | `android/app/google-services.json` |
| Clave de la cuenta de servicio (`.json`) | Que **el servidor** pueda mandar notificaciones | `alerticapi/.env` (con una herramienta, no a mano) |

Mezclarlos es el error más común: se parecen y no son lo mismo. Las herramientas
de abajo avisan si te equivocas de archivo.

**Cuesta cero pesos.** Firebase Cloud Messaging no tiene límite de mensajes ni de
dispositivos. Tu proyecto ya está en el plan Spark (sin costo), que sobra para
1.248 personas.

> **Qué no necesitas:** Authentication, Firestore, Analytics ni nada de lo que
> aparece en el menú de la consola. ALERTIC solo usa **Cloud Messaging**, y la
> sección «Messaging» de la consola (campañas) tampoco: las notificaciones las
> manda el servidor por su cuenta.

## Qué funciona hoy sin hacer nada de esto

| | Sin Firebase | Con Firebase |
|---|---|---|
| Alerta con la app abierta | ✅ llega, por el canal en vivo | ✅ llega |
| Alerta con el celular en el bolsillo | ❌ | ✅ aviso arriba |
| Alerta con el celular bloqueado | ❌ | ✅ toma la pantalla (roja) |
| Reporte de un estudiante a su director de grupo | ✅ con la app abierta | ✅ también en el bolsillo |
| Todo lo demás (tablero, reportes, protocolos) | ✅ | ✅ |

La app compila y corre sin `google-services.json`. Con el archivo y sin las
credenciales del servidor también corre: el servidor lo dice en su registro
(`notificaciones push apagadas`) y sigue funcionando.

---

## Camino A · Desde la consola (sin instalar nada)

Es el que corresponde a tu captura: el proyecto **alertic** ya existe.

### 1. Registrar la app de Android

1. En la **Descripción general** del proyecto, pulsa **«+ Agregar app»** y elige
   el icono de **Android**.
2. **Nombre del paquete de Android**: escribe exactamente

   ```
   com.example.alertic
   ```

   Tiene que ser idéntico al `applicationId` de
   [android/app/build.gradle.kts](android/app/build.gradle.kts). Si no coincide,
   las notificaciones no llegan y no hay ningún error que lo diga.

   > Para desarrollar sirve `com.example.alertic`. **Google Play lo rechaza**:
   > antes de publicar hay que cambiarlo por uno del colegio, como
   > `co.edu.iic.alertic`, y registrar la app otra vez en Firebase con el nombre
   > nuevo. Mejor decidirlo ahora si ya sabes que va a Play Store.
3. El **apodo** es libre (por ejemplo «ALERTIC Android»). El **certificado SHA-1**
   déjalo vacío: solo se necesita para inicio de sesión con Google y no se usa.
4. Pulsa **Registrar app**.
5. **Descarga `google-services.json`** y déjalo en:

   ```
   alertic/android/app/google-services.json
   ```

6. Los pasos que siguen en la consola («Agregar el SDK de Firebase») **ya están
   hechos** en el proyecto: salta hasta el final y pulsa **Continuar a la
   consola**.

El archivo está en `.gitignore`: identifica el proyecto del colegio y no tiene por
qué estar en un repositorio.

### 2. Darle al servidor su llave

1. Engranaje junto a «Descripción general» → **Configuración del proyecto** →
   pestaña **Cuentas de servicio**.
2. **Generar nueva clave privada** → **Generar clave**. Se descarga un `.json`.
3. Escribe las credenciales en el servidor con la herramienta (te ahorra copiar
   una llave de varias líneas, que es donde más se falla). El segundo archivo es
   opcional y sirve para comprobar que la app y el servidor son del **mismo**
   proyecto:

   ```bash
   cd alerticapi
   npm run fcm:set -- C:/ruta/al/alertic-firebase-adminsdk.json ../alertic/android/app/google-services.json
   ```

   Muestra el proyecto y la cuenta, **nunca la llave**.
4. **Borra el archivo que descargaste.** Esa llave puede mandarle una notificación
   a todos los celulares del colegio, y guardada en `.env` ya no hace falta el
   original.

### 3. Comprobar que funciona

```bash
npm run fcm:check
```

Habla con Google y comprueba las credenciales **sin mandarle nada a nadie**:

```
Probando Firebase con el proyecto «alertic-xxxxx»…

✓ Firebase respondió: las credenciales sirven.
```

Si falla, dice por qué y qué hacer:

| Mensaje | Qué pasó |
|---|---|
| `Google rechazó la llave` | La llave es vieja, se revocó o se copió mal. Genera una nueva. |
| `Firebase Cloud Messaging no está activado` | En Google Cloud, activa **Firebase Cloud Messaging API** (la V1). |
| `Firebase no encontró el proyecto` | `FCM_PROJECT_ID` debe ser el **identificador** del proyecto, no el nombre. |

Después reinicia el servidor. Al arrancar debe decir `notificaciones push activas`.

### 4. Probar en un celular

```bash
cd alertic
flutter run --dart-define=ALERTIC_API=http://10.0.2.2:3000
```

(`10.0.2.2` es el computador visto desde el emulador de Android; con un celular
real, la IP del computador en el wifi.)

1. Entra con un código o con una cuenta. En el paso **«Último paso»** Android
   preguntará si permites las notificaciones. Acepta.
2. **Cierra la app del todo** (no solo minimizarla).
3. Emite una alerta desde otra sesión o desde el panel. El aviso debe aparecer
   arriba.

Comprueba que el celular quedó registrado:

```bash
cd alerticapi
node --experimental-sqlite -e "const {DatabaseSync}=require('node:sqlite');console.log(new DatabaseSync('./data/alertic.db').prepare('SELECT platform, created_at FROM device_tokens').all())"
```

---

## Si algo falla

**`The request for this plugin could not be satisfied because the plugin is already on the classpath with a different version`**

La consola de Firebase te sugiere pegar `id("com.google.gms.google-services") version "4.x.x" apply false` en `android/app/build.gradle.kts`. **No lo pegues**: ese plugin ya está declarado, con su versión, en `android/settings.gradle.kts`, y Gradle no admite dos versiones. En `app/build.gradle.kts` el plugin se aplica solo si existe `google-services.json`, sin versión. Si ya lo pegaste, borra esa línea.

**`FirebaseApp initialization unsuccessful` en el registro del celular**

Falta `android/app/google-services.json`, o el nombre del paquete que registraste no es el `applicationId`. Con el archivo bien puesto debe decir `initialization successful`.

**El celular no pide permiso de notificaciones**

Android solo pregunta una vez. Si dijiste «No permitir», se activa a mano en Ajustes → Apps → alertic → Notificaciones.

**Cerrar sesión**

Da de baja el celular en el servidor: sin eso, el teléfono seguiría recibiendo los avisos de quien lo usó antes. Si lo vendes o lo prestas, cierra sesión primero.

---

## Qué se comprobó

En un emulador con Google Play Services, con este proyecto:

| Paso | Resultado |
|---|---|
| `npm run fcm:check` | ✓ las credenciales sirven |
| Entrar como estudiante, aceptar notificaciones | el celular se registró con un token de 142 caracteres |
| Alerta roja con la app en segundo plano | aviso flotante «SISMO · Sal en fila, sin correr»; al tocarlo se abre la alerta |
| Cerrar sesión | el celular se da de baja y una alerta posterior ya no llega |
| Entrar como coordinación y reportar un incendio como estudiante | aviso «Reporte de incendio · Sofía · 10° B» |

## Camino B · Con la línea de comandos (más corto)

El Firebase CLI ya está instalado en este equipo. Solo falta iniciar sesión, y eso
abre tu navegador, así que lo haces tú:

```bash
firebase login
firebase projects:list          # copia el ID de «alertic»
```

Con eso, el registro de la app y la descarga del archivo se hacen en dos comandos:

```bash
cd alertic
firebase apps:create ANDROID "ALERTIC Android" --package-name com.example.alertic --project <ID-DEL-PROYECTO>
firebase apps:list ANDROID --project <ID-DEL-PROYECTO>                      # copia el App ID
firebase apps:sdkconfig ANDROID <APP-ID> --project <ID-DEL-PROYECTO> --out android/app/google-services.json
```

La clave del servidor (paso 2 del camino A) sigue siendo desde la consola: es una
credencial y Firebase solo la entrega por ahí.

---

## Lo que queda pendiente y por qué

**Alertas críticas en iOS.** Que una notificación suene con el celular en silencio
requiere el *Critical Alerts entitlement*, que Apple concede por formulario y solo
a apps de emergencia de verdad. El código ya lo pide (`criticalAlert: true`);
mientras Apple no lo conceda, iOS lo ignora y el aviso suena como uno normal. En
Android ya funciona sin permiso especial, con el canal configurado como alarma.

**`USE_FULL_SCREEN_INTENT` en Play Store.** Desde Android 14, Google revisa este
permiso al publicar: hay que declarar en la ficha que la app es de alarmas o
emergencias. Un sistema de alerta temprana escolar califica, pero hay que
escribirlo en el formulario o rechazan la publicación.

**Fabricantes con ahorro de batería agresivo.** Xiaomi, Huawei y Oppo a veces
impiden que una app despierte en segundo plano. Es un problema conocido de Android
que ninguna app resuelve del todo; en esos celulares hay que agregar ALERTIC a la
lista de apps protegidas desde los ajustes del sistema. Vale la pena decirlo en la
capacitación del colegio.

**Si la persona forzó el cierre de la app**, Android corta la entrega de
notificaciones por completo. No es algo que el código pueda evitar: le pasa a
WhatsApp igual. Por eso el sistema tiene más capas que el push: el canal en vivo
por el wifi del colegio, y la sirena.
