# Cuenta demo para App Review sin 2FA por SMS/correo

## Problema

Al iniciar sesión con correo y contraseña, el backend responde con un `challengeToken` y la app pide un código de 6 dígitos (`POST /auth/mfa/send`, `POST /auth/mfa/verify`). El revisor de Apple no puede recibir ese código, así que no podría entrar y rechazaría la app (guideline 2.1, no se pudo acceder a la app).

El cliente no necesita cambios: `LoginViewModel` ya sigue lo que diga el backend (`requiresMFA`). Todo el cambio es en el **backend**.

## Opción recomendada: código fijo solo para la cuenta demo

### Comportamiento esperado

1. `POST /auth/mfa/send`: si el usuario del `challengeToken` es la cuenta demo, responde éxito **sin enviar** SMS ni correo.
2. `POST /auth/mfa/verify`: si el usuario es la cuenta demo y el código es el fijo, acepta y devuelve los tokens normales.
3. Cualquier otro usuario sigue el flujo normal sin cambios.

### Reglas de seguridad (obligatorias)

- **Solo producción y solo esa cuenta.** La comparación es contra un identificador fijo de la cuenta demo (su `userId` o su correo exacto), nunca por patrón.
- **Configuración por variables de entorno**, no código en el repositorio:
  - `DEMO_MFA_ENABLED=true`
  - `DEMO_MFA_EMAIL=<correo de la cuenta demo>`
  - `DEMO_MFA_CODE=<código de 6 dígitos>`
- Si `DEMO_MFA_ENABLED` no es `true`, el atajo no existe.
- El código fijo debe seguir respetando el límite de intentos y la expiración del `challengeToken`.
- La cuenta demo no debe tener datos reales ni métodos de pago reales.
- Registra en logs cada vez que se use el atajo (sin registrar el código).

### Pseudocódigo

```js
// POST /auth/mfa/verify
const isDemo = process.env.DEMO_MFA_ENABLED === 'true'
  && user.email === process.env.DEMO_MFA_EMAIL;

if (isDemo) {
  if (code !== process.env.DEMO_MFA_CODE) throw invalidCode();
  return issueTokens(user);
}
// ... flujo normal
```

```js
// POST /auth/mfa/send
if (isDemo) return { success: true, resendCodeTimeInSeconds: 30, expiresInSeconds: 600 };
// ... flujo normal (envía SMS/correo)
```

## Opción alternativa: MFA no requerido para la cuenta demo

Se marca la cuenta con una bandera (por ejemplo `mfaRequired = false`) y `POST /auth/signIn` devuelve los tokens directamente, sin `challengeToken`.

## Comparación

| | Código fijo | MFA no requerido |
|---|---|---|
| Cambios en la app | Ninguno | Ninguno |
| Pantalla de código visible al revisor | Sí, se prueba el flujo real | No, se salta |
| Seguridad si se filtran correo y contraseña | Hace falta además el código | Basta con correo y contraseña |
| Riesgo de dejar una bandera abierta | Se apaga con una variable de entorno | Queda una bandera persistente en la cuenta |
| Esfuerzo de backend | Dos ramas pequeñas (`send` y `verify`) | Una bandera y una condición en `signIn` |

**Recomendación: código fijo.** Se explica en la respuesta del chat.

## Texto para las notas del revisor (App Store Connect)

```
Demo account: [correo] / [contraseña]
This account uses a fixed verification code: [código]
(No SMS or email will be sent for this account.)
```

## Después de la aprobación

1. Cambia la contraseña de la cuenta demo, o desactiva `DEMO_MFA_ENABLED`.
2. Si Apple vuelve a revisar una actualización, reactívalo antes de enviarla.

## Lista de verificación antes de enviar la app

- [ ] Variables de entorno configuradas en producción.
- [ ] Iniciar sesión con la cuenta demo en el build de TestFlight, usando el código fijo.
- [ ] Confirmar que una cuenta normal sigue recibiendo su código.
- [ ] La cuenta demo tiene partidos futuros publicados para que el revisor vea contenido.
- [ ] El backend de producción está despierto (si está en un plan que se duerme).
- [ ] Credenciales y código pegados en las notas del revisor.
