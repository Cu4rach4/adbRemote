# Operación y distribución

## Requisitos

- macOS 26 o posterior.
- Swift 6 / herramientas de Xcode; Xcode completo para crear y firmar una aplicación distribuible.
- ADB 1.0.41 o posterior instalado en `/usr/local/bin/adb`.
- `scrcpy` opcional para espejo de pantalla: `brew install scrcpy`.
- Para depuración inalámbrica, Mac y Android deben poder comunicarse en la misma red local y Android debe tener Wireless debugging activo.

## Desarrollo y pruebas

```zsh
swift test
swift run ADBRemote
```

La primera exploración por Bonjour puede mostrar la autorización de red local. Puede habilitarse después desde **System Settings > Privacy & Security > Local Network**.

## Empaquetado local

```zsh
chmod +x scripts/create-dmg.sh
scripts/create-dmg.sh
```

El script compila en modo `release`, crea `dist/ADB Remote.app`, la firma ad-hoc y genera `dist/ADB-Remote.dmg`. Estos son artefactos locales y se excluyen del repositorio.

La firma ad-hoc sirve para pruebas locales. Antes de distribuir fuera del equipo, se requiere firma con un certificado Developer ID y notarización de Apple.

## Datos persistentes y privacidad

El proyecto solo almacena en `UserDefaults` los aliases de serial y los dispositivos guardados por IP. No incorpora credenciales, ADB, `scrcpy`, telemetría, servicios remotos ni una base de datos. Los comandos se ejecutan localmente contra los dispositivos que la persona usuaria conecte.

## Archivos generados

`.build/`, `dist/`, `.DS_Store`, datos de usuario de Xcode, símbolos de depuración y temporales no deben versionarse. La raíz incluye `.gitignore` para mantenerlos fuera del índice.
