# Changelog

Este archivo sigue el formato de [Keep a Changelog](https://keepachangelog.com/es/1.1.0/) y versionado semántico cuando sea aplicable.

## [Unreleased]

### Changed

- Se incorporan reglas de exclusión para productos de compilación, paquetes de distribución y metadatos locales de macOS.
- Se añade la documentación de arquitectura C4, operación y alcance funcional del estado inicial.

## [1.0.1] - 2026-09-12

### Added

- Aplicación nativa macOS en SwiftUI para administrar dispositivos Android mediante una instalación local de ADB.
- Detección de dispositivos USB y de depuración inalámbrica mediante Bonjour, con alternativa usando `adb mdns services`.
- Emparejamiento y conexión inalámbrica, incluyendo dispositivos guardados por IP y puerto.
- Acciones remotas: teclas del sistema, texto, capturas, espejo con `scrcpy`, instalación de APK y modo TCP/IP.
- Gestión de aplicaciones instaladas y reglas de puertos inversos con ADB.
- Script para generar una aplicación firmada ad-hoc y una imagen DMG local.

### Changed

- Al abrirse, la aplicación comprueba ADB y scrcpy en las rutas de Homebrew y en `PATH`; muestra la ruta y versión detectadas, instrucciones copiables de instalación y permite volver a comprobarlas.
- ADB pasa a ser una dependencia explícita para operar la aplicación y scrcpy una dependencia opcional, requerida solo para Mirror.
- Se documentan Android SDK Platform-Tools 37.0.1 (`adb` 1.0.41) y scrcpy 4.1 como versiones de referencia, junto con los comandos de instalación mediante Homebrew.
- Screenshot captura la salida sin bloquearse por el buffer del proceso y valida que la respuesta de ADB sea un PNG antes de guardarla.
- Mirror conserva el proceso de scrcpy y evita iniciar más de un espejo para el mismo dispositivo.
- Las acciones Home y Menu usan los keycodes Android explícitos `KEYCODE_HOME` y `KEYCODE_MENU`; el estado de éxito ya no espera la posterior actualización de dispositivos.
