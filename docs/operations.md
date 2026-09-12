# Operación y distribución

## Requisitos

- macOS 26 o posterior.
- Swift 6 / herramientas de Xcode; Xcode completo para crear y firmar una aplicación distribuible.
- Android SDK Platform-Tools **37.0.1** (`adb` 1.0.41), versión validada por esta entrega. Se recomienda la versión estable más reciente de Platform-Tools.
- `scrcpy` **4.1**, versión de referencia para el espejo de pantalla. Se recomienda la versión estable más reciente.

Instalación mediante Homebrew:

```zsh
brew install --cask android-platform-tools
brew install scrcpy
```

Al abrirse, la app busca ambos binarios en Homebrew para Apple Silicon (`/opt/homebrew/bin`), Homebrew para Intel (`/usr/local/bin`) y el `PATH` del proceso. ADB es obligatorio; scrcpy solo lo es para **Mirror**. La pantalla **Dependencias** muestra la ruta y versión detectadas, y permite volver a comprobarlas después de instalar o actualizar.
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
