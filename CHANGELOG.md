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
