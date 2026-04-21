# Panafix: guia rapida para Codex / Mac handoff

## Que es Panafix

Panafix es una app de servicios del hogar parecida a un marketplace entre clientes y tecnicos, con control fuerte de pagos y supervision manual.

Roles:

- `client`: pide servicios
- `technician`: recibe solicitudes y trabaja
- `owner`: super admin real de la dueña
- `admin`: apoyo administrativo
- `pending`: usuario autenticado que aun no eligio rol

## Flujo principal del negocio

1. El cliente elige categoria y servicio.
2. Se crea una solicitud.
3. El cliente paga.
4. La dueña revisa el pago movil.
5. Si se aprueba, el tecnico puede seguir el flujo del trabajo.
6. Si el pago es rechazado o incompleto, ahora puede convertirse en saldo interno Panafix.

## Cosas delicadas que ya existen

### 1. Saldo Panafix anclado al BCV

- El saldo del cliente no debe tratarse como bolivares fijos.
- Se guarda en USD referencial:
  - `appWalletBalanceUsd`
- Al momento de pagar otro servicio:
  - se consulta la tasa BCV
  - se convierte el saldo USD a Bs
  - se aplica automaticamente

Colecciones relacionadas:

- `users`
- `client_wallet_transactions`
- `client_refund_requests`
- `orders`
- `app_config/bcv_rate`

### 2. Pagos de clientes

Estados importantes en `orders.paymentStatus`:

- `pending`
- `review`
- `paid`
- `released`
- `refund_pending`
- `refund_requested`
- `partial_payment`

### 3. Rechazo de tecnico

Si un tecnico rechaza una solicitud:

- el cliente recibe notificacion
- en `MyRequestsPage` aparece boton para pedir otro tecnico enseguida

### 4. Usuarios nuevos con Google

Si un usuario entra con Google y aun no tiene rol:

- queda con `role = pending`
- `needsRoleSelection = true`
- `AuthGate` lo lleva a `RoleSelectionPage`

Si por alguna razon Firebase Auth crea la cuenta pero Firestore no creo el doc de usuario:

- `AuthGate` intenta reconstruir el perfil automaticamente

## Archivos clave

- `lib/pages/auth_gate.dart`
- `lib/pages/auth_service.dart`
- `lib/pages/register_page.dart`
- `lib/pages/role_selection_page.dart`
- `lib/pages/home_page.dart`
- `lib/pages/my_requests_page.dart`
- `lib/pages/payment_page.dart`
- `lib/pages/owner_home_page.dart`
- `lib/pages/technician_home_page.dart`
- `lib/pages/technician_services_page.dart`
- `lib/pages/technician_requests_page.dart`
- `lib/services/bcv_rate_service.dart`
- `firestore.rules`

## Que no romper

- No volver a guardar el saldo interno solo en Bs.
- No quitar el flujo manual del owner para pagos reales.
- No hacer que el tecnico vea lo que pago el cliente.
- No reabrir el chat cuando el tecnico ya llego o termino.
- No quitar la proteccion de Google Sign-In basada en Firebase + package `com.panafix.app`.

## Android / Play Store

Package Android actual:

- `com.panafix.app`

Google Sign-In en Android depende de:

- huellas SHA en Firebase
- `google-services.json` actualizado
- Play App Signing configurado

## Para compilar en otra maquina

1. Instalar Flutter estable
2. Instalar Android Studio
3. Abrir el proyecto
4. Ejecutar:

```powershell
flutter pub get
flutter build appbundle --release
```

## Para Codex en Mac

Antes de empezar:

1. Leer este archivo
2. Leer `README.md`
3. Leer `docs/playstore_launch_checklist.md`
4. Revisar `pubspec.yaml`
5. Revisar `firebase_options.dart`

Si algo "parece que no hace nada", revisar primero:

- `AuthGate`
- Firestore rules
- documentos faltantes en `users/{uid}`
- estado de `orders.paymentStatus`

## Estado deseado del repo

Este proyecto debe vivir en GitHub privado para backup y continuidad entre Windows y Mac.
