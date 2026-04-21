# Panafix

Panafix es una app Flutter conectada con Firebase para servicios del hogar, con dos lados principales:

- Clientes: buscan tecnicos, piden servicios, pagan, siguen el estado y pueden usar saldo interno.
- Tecnicos: configuran servicios, reciben solicitudes, gestionan trabajos y cobran por pago movil.

## Stack

- Flutter
- Firebase Auth
- Cloud Firestore
- Firebase Storage
- Firebase Hosting
- Google Maps

## Estado del proyecto

Funciones importantes ya montadas:

- Registro e inicio de sesion con correo y Google
- Flujo cliente / tecnico / owner / admin
- Solicitudes de servicio con tracking
- Pago movil con comprobante
- Revision manual de pagos por la dueña
- Saldo interno Panafix anclado al BCV
- Suscripciones para tecnicos
- Verificacion de tecnicos
- Panel super admin / owner

## Estructura rapida

- `lib/main.dart`: arranque de la app
- `lib/pages/`: pantallas principales
- `lib/services/`: servicios de apoyo, incluyendo BCV y pagos
- `firestore.rules`: reglas de Firestore
- `storage.rules`: reglas de Storage
- `firebase.json`: deploy de Firebase
- `functions/`: backend auxiliar de Firebase Functions

## Build Android App Bundle

```powershell
cd C:\Users\Bella\StudioProjects\panafix
& "C:\Users\Bella\Downloads\flutter_windows_3.41.3-stable\flutter\bin\flutter.bat" build appbundle --release
```

El archivo queda en:

```text
C:\Users\Bella\StudioProjects\panafix\build\app\outputs\bundle\release\app-release.aab
```

## Build web

```powershell
cd C:\Users\Bella\StudioProjects\panafix
& "C:\Users\Bella\Downloads\flutter_windows_3.41.3-stable\flutter\bin\flutter.bat" build web --release
firebase deploy --only "hosting"
```

## Documentacion interna

Lee estos archivos antes de tocar algo grande:

- `docs/CODEX_PROJECT_GUIDE.md`
- `docs/playstore_launch_checklist.md`
- `docs/android_release_guide.md`

## Nota importante

Este repo debe ir preferiblemente a un repositorio privado porque el proyecto contiene configuraciones reales de Firebase y negocio.
