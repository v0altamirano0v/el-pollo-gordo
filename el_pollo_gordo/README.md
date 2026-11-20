# El Pollo Gordo - Gestión de Ventas

Aplicación Flutter/Dart multiplataforma (Android y Web) para la pollería "El Pollo Gordo" (Pisco, Perú).
Incluye los flujos operativos LRPD para salón, para llevar y delivery, con base de datos relacional local,
datos de prueba iniciales y script DDL.

## 1. Estructura

```
lib/
  main.dart                    Punto de entrada
  app.dart                     MaterialApp + proveedor de estado
  core/                        Constantes, tema, formato y contrato DbClient
  data/
    schema.dart                DDL ejecutado por la app + seed data
    database.dart              Fábrica multiplataforma
    database_io.dart           SQLite real (Android) usando sqflite
    database_web.dart          Persistencia JSON (Web) con SharedPreferences
    repositories.dart          Repositorio de todos los flujos de negocio
  state/app_state.dart         ChangeNotifier sesión + catálogos
  models/entities.dart         Extensiones typed y modelos de carrito/resumen
  ui/                          Pantallas por rol y scaffold adaptativo
sql/schema.sql                 DDL relacional completo con índices
android/                       Configuración Android (APK)
web/index.html                 Shell Web
```

## 2. Compilación del APK (Android)

Requisitos: Flutter SDK 3.32+ (Dart 3.5+) y Android SDK con API 35.

```powershell
# Desde la raíz del proyecto
flutter create --platforms=android,web .   # Genera/asegura gradlew, wrapper y plataforma
flutter pub get
flutter analyze
flutter build apk --release
```

El APK queda en:

```
build\app\outputs\flutter-apk\app-release.apk
```

Para instalar en un dispositivo conectado:

```powershell
flutter install
# o
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

Desde Android Studio: **File > Open** la carpeta del proyecto → **Build > Flutter > Build APK**.
El release está firmado con la firma `debug` incluida por Flutter para permitir instalación inmediata.
Para publicación en Play Store reemplace esa firma por su propia llave.

## 3. Compilación Web

```powershell
flutter build web
```

Salida: `build\web`. La persistencia Web usa `SharedPreferences` (localStorage del navegador),
mientras que Android usa SQLite en:

```
/data/data/com.ejemplo.pollogordo/databases/el_pollo_gordo.db
```

## 4. Datos de prueba (seed)

Al primer inicio se crean automáticamente:

- 2 establecimientos: Principal (Las Américas 965) y Delivery (Av. Camino Real).
- 8 empleados: cajero, administrador, mostrador, mozo, 2 repartidores, cajero delivery y propietario.
- 6 mesas en 2 pisos, clientes, proveedor y compra inicial de 30 pollos.
- 9 productos con `equivalencia_pollo` (1/8 = 0.125, 1/4 = 0.25, 1/2 = 0.5, entero = 1).
- Pedidos demo: salón listo, para llevar registrado y delivery en ruta con liquidación pendiente.

Seleccione establecimiento y rol en la pantalla inicial. La sesión se recuerda entre reinicios.

## 5. Flujos implementados

| Rol | Funciones |
|---|---|
| Cajero / Administrador | Registro `salon` / `para_llevar`, mesa, número de pedido, cobro efectivo + comprobante, validación de incidencias, cambios y devoluciones. |
| Mostrador / Despacho | Consulta de pendientes, paso a `listo`, cobro y confirmación de entrega para llevar. |
| Mozo | Pedidos de salón/mesas, recojo en mostrador, entrega en mesa, reporte de incidencias (pollo crudo/con sangre, papas en mal estado) y solicitud de cambios. |
| Cajero Delivery | Pedido telefónico con validación de datos incompletos y duplicados, total con envío, asignación/reasignación, incidencias, llamadas y devoluciones. |
| Repartidor | Entregas asignadas, salida `en ruta`, registro de cobro/entrega, intentos de contacto y entregas fallidas. |
| Propietario / Caja | Liquidación esperado vs rendido con diferencia, compras de pollos y cierre diario consolidado (ventas, pollos vendidos vs comprados, observaciones). |

## 6. Modelo relacional

Entidades: `ESTABLECIMIENTO`, `EMPLEADO`, `MESA`, `CLIENTE`, `PROVEEDOR`, `COMPRA_POLLO`,
`CATEGORIA`, `PRODUCTO`, `PEDIDO`, `DETALLE_PEDIDO`, `PAGO`, `COMPROBANTE`,
`ENTREGA_DELIVERY`, `LIQUIDACION_REPARTO` y `CIERRE_DIARIO`.
El DDL de referencia está en `sql/schema.sql` y el ejecutado por la app en `lib/data/schema.dart`.
