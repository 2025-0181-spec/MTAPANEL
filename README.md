# MTAPANEL — Panel de Control MTA:SA

Panel de administración para servidores **MTA:SA** (Multi Theft Auto: San Andreas) en Linux VPS.

## Instalación rápida

```bash
curl -sL https://raw.githubusercontent.com/2025-0181-spec/MTAPANEL/main/setup.sh | bash
```

Luego escribe `mta` para abrir el panel.

## Funciones

| Opción | Descripción |
|--------|-------------|
| **Iniciar** | Lanza el server en screen con logging |
| **Detener** | Shutdown seguro (guarda datos) o kill forzado |
| **Reiniciar** | Shutdown + reinicio automático |
| **Consola** | Output en tiempo real o adjuntarse al screen |
| **Comandos** | Envía comandos a la consola MTA (say, kick, start, stop...) |
| **Logs** | Server log, error log, log en vivo |
| **Config** | Directorio, screen name, buscar ejecutable, actualizar panel |

## Estructura del repo

```
MTAPANEL/
├── setup.sh      ← Instalador
├── panel.sh      ← Panel principal
├── version.txt   ← Versión actual
└── README.md
```

## Requisitos

- Ubuntu 20.04+ / Debian 10+
- MTA:SA Server instalado
- Root access
