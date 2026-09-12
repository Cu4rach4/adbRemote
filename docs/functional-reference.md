# Referencia funcional

Estado documentado: commit `cd6827e` (`first commit`). Las funciones siguientes están implementadas en `Sources/ADBRemote`.

## Conexión y descubrimiento

| Función | Comportamiento | Integración |
| --- | --- | --- |
| Listar dispositivos | Muestra serial, estado, producto, modelo y transporte. | `adb devices -l` |
| Descubrir cercanos | Resuelve servicios `_adb-tls-connect._tcp` por Bonjour; usa mDNS de ADB si no hay resultados. | `NetServiceBrowser`; `adb mdns services` |
| Emparejar | Valida `host:puerto` y código de seis dígitos. | `adb pair <host> <code>` |
| Conectar | Valida IP/host y puerto; verifica respuesta de ADB. Reintenta tras reiniciar el daemon si la red no tiene ruta. | `adb connect <host:puerto>` |
| Dispositivos manuales | Guarda nombre, IP y puerto (5555 por defecto), evita endpoints duplicados y conecta al crearlos. | `UserDefaults` |
| Alias | Guarda un nombre alternativo por serial. | `UserDefaults` |

## Operaciones sobre un dispositivo conectado

| Función | Comando o mecanismo |
| --- | --- |
| Volver, inicio, menú y enter | `adb -s <serial> shell input keyevent <key>` |
| Enviar texto | `adb -s <serial> shell input text <texto>`; los espacios se codifican como `%s`. |
| Captura de pantalla | `adb -s <serial> exec-out screencap -p`; se guarda en PNG y copia al portapapeles. |
| Espejo | Inicia `scrcpy -s <serial>` desde `/opt/homebrew/bin` o `/usr/local/bin`. |
| Instalar APK | Soltar un archivo `.apk` ejecuta `adb -s <serial> install -r <ruta>`. |
| Activar TCP/IP | `adb -s <serial> tcpip <puerto>`. |
| Desconectar | `adb disconnect <serial>`; solo se habilita para seriales con `:`. |

## Aplicaciones y puertos

| Función | Comando o mecanismo |
| --- | --- |
| Listar apps | `adb -s <serial> shell pm list packages`, filtrado por todas, usuario (`-3`), sistema (`-s`) o deshabilitadas (`-d`). |
| Buscar apps | Filtrado local sin distinción entre mayúsculas y minúsculas. |
| Abrir app | `adb -s <serial> shell monkey -p <paquete> 1`. |
| Deshabilitar app | `adb -s <serial> shell pm disable-user --user 0 <paquete>`. |
| Desinstalar app | `adb -s <serial> uninstall <paquete>`. |
| Puerto inverso | `adb -s <serial> reverse <remoto> <local>`; al eliminar, `reverse --remove <remoto>`. |

## Validaciones y errores

- ADB debe existir y ser ejecutable en `/usr/local/bin/adb`.
- Los puertos de conexión deben ser enteros entre 1 y 65535.
- El código de emparejamiento debe contener exactamente seis dígitos.
- Los errores de ADB se muestran en la interfaz. Para "No route to host", el mensaje indica revisar Wi-Fi, VPN y aislamiento de clientes.
- Una conexión se considera exitosa únicamente si ADB responde `connected to` o `already connected to`.

## Cobertura automatizada actual

Las pruebas comprueban análisis de `adb devices -l`, endpoint y puerto manual por defecto, análisis de servicios mDNS y manejo de respuestas de conexión sin ruta de red. Se ejecutan con `swift test`.
