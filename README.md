# threeDotsFiles

Repositorio de bootstrap portable para una maquina Arch-family, centrado en configuraciones de terminal/editor y sincronizacion controlada de dotfiles.

## Que es este proyecto

`threeDotsFiles` sirve para:

- Preparar una maquina nueva con un set base de herramientas y configuraciones.
- Mantener configuraciones versionadas de forma reproducible.
- Sincronizar cambios desde una maquina local hacia este repo con modo seguro por defecto.

Alcance actual:

- Configs de `zsh`, `tmux`, `nvim` y `opencode`.
- Listas de paquetes oficiales y AUR.
- Scripts de backup, linkeo por symlink y sync maquina -> repo.

No incluye:

- Autenticaciones, credenciales, tokens, claves privadas o secretos.
- Estado local de aplicaciones (cache, history, sesiones, etc.).

## Estructura del repo

```text
threeDotsFiles/
|-- install.sh
|-- sync.sh
|-- .gitignore
|-- README.md
|-- packages/
|   |-- official.txt
|   `-- aur.txt
|-- scripts/
|   |-- checks.sh
|   |-- packages.sh
|   |-- backup.sh
|   |-- link.sh
|   `-- sync-excludes.txt
`-- configs/
    |-- zsh/.zshrc
    |-- tmux/.tmux.conf
    |-- nvim/README.md
    `-- opencode/README.md
```

Proposito por carpeta:

- `configs/`: fuente versionada de configuraciones portables.
- `packages/`: listas declarativas de paquetes para instalacion automatica (pacman primero, AUR fallback).
- `scripts/`: bloques reutilizables usados por `install.sh` y `sync.sh`.

## Requisitos

- Sistema basado en Arch Linux.
- `pacman` (obligatorio).
- `yay` (opcional, el script lo bootstrapea automaticamente si hay AUR y falta).
- `git`.
- Recomendado: `rsync` para sincronizacion mas precisa en `sync.sh`.

## Que instala/configura exactamente

Paquetes (instalacion automatica solo con `--apply`):

- Oficiales de Arch desde `packages/official.txt` usando `pacman`.
- AUR desde `packages/aur.txt` usando `yay` (con bootstrap automatico de `yay-bin` si falta en modo `--apply`).

Configuraciones por symlink:

- `configs/zsh/.zshrc` -> `~/.zshrc`
- `configs/tmux/.tmux.conf` -> `~/.tmux.conf`
- `configs/nvim/` -> `~/.config/nvim`
- `configs/opencode/` -> `~/.config/opencode`

Estrategia de paquetes:

- Prioridad absoluta a `pacman` para todo paquete disponible en repos oficiales.
- `yay` queda reservado para paquetes que realmente son AUR-only.
- Si hay paquetes AUR declarados y `yay` no existe, `install.sh --apply` intenta bootstrap (`base-devel` + `git` + `yay-bin` con `makepkg -si --noconfirm`).
- Si ese bootstrap falla, deja warning y continua con backup/link (no corta toda la ejecucion).

Detalle Docker Compose (Arch):

- En esta maquina, `docker` no incluye archivos `cli-plugins` de Compose.
- El paquete oficial `docker-compose` instala tanto `/usr/bin/docker-compose` como el plugin v2 en `/usr/lib/docker/cli-plugins/docker-compose`.
- Resultado practico: con `docker-compose` instalado, funciona `docker compose ...` (Compose v2) y tambien el comando legacy `docker-compose ...`.

## Como funciona `install.sh`

Modo por defecto: `dry-run` (seguro).

Comportamiento:

1. Ejecuta chequeos de entorno (`scripts/checks.sh`).
2. Ejecuta instalacion automatica de paquetes (`scripts/packages.sh`):
   - en `--dry-run`: muestra preview exacta de comandos.
   - en `--apply`: instala oficiales con `sudo pacman -S --needed --noconfirm`.
   - si hay AUR y falta `yay`, intenta bootstrap automatico de `yay-bin` (sin root para `makepkg`), y luego instala AUR con `yay -S --needed --noconfirm`.
3. Ejecuta backup de objetivos existentes (`scripts/backup.sh`).
4. Linkea configs por symlink (`scripts/link.sh`).
5. Ejecuta siempre post-setup Docker.

Post-instalacion Docker:

- Si hay `systemctl`: habilita y arranca Docker en boot (`sudo systemctl enable --now docker`).
- Si no hay systemd/systemctl: muestra warning y continua sin cortar la instalacion.
- Agregar usuario al grupo `docker` solo si aun no pertenece: `sudo usermod -aG docker "$USER"`
- Luego cerrar sesion y volver a entrar (o `newgrp docker`) para aplicar grupo.

Uso:

```bash
./install.sh
./install.sh --dry-run
./install.sh --apply
```

## Como funciona `sync.sh`

Direccion fija: **maquina actual -> repo**.

Mapeos permitidos:

- `~/.zshrc` -> `configs/zsh/.zshrc`
- `~/.tmux.conf` -> `configs/tmux/.tmux.conf`
- `~/.config/nvim/` -> `configs/nvim/`
- `~/.config/opencode/` -> `configs/opencode/`

Modos y flags:

- `--dry-run`: vista previa (default).
- `--apply`: aplica copias/actualizaciones.
- `--prune`: elimina del repo archivos que ya no existen en origen (solo con `--apply`).
- `--verbose`: salida detallada.

Backups de sync:

- Antes de sobreescribir o borrar en modo apply, guarda backup en `.sync-backup/<timestamp>/`.

Uso:

```bash
./sync.sh --dry-run
./sync.sh --apply
./sync.sh --apply --prune
```

Advertencia sobre `--prune`:

- Puede borrar archivos versionados del repo si no existen en la maquina origen.
- Recomendado correr primero `--dry-run` y revisar candidatos de borrado.

## Flujo recomendado

1. `./sync.sh --dry-run`
2. Revisar plan de cambios en consola.
3. Revisar `git diff`.
4. `./sync.sh --apply`
5. Revisar de nuevo `git diff` y recien ahi commit.

## Seguridad

Este repo esta pensado para ser publico. Regla base: **no subir secretos**.

Controles incluidos:

- `.gitignore` con exclusiones para `.env`, llaves, credenciales, historiales, cache y estado local.
- `scripts/sync-excludes.txt` para bloquear patrones sensibles durante sync.
- Filtros extra en `sync.sh` para nombres/patrones de riesgo (`token`, `secret`, `auth`, etc.).
- Backups previos a sobrescrituras y borrados en modo apply.

Cosas que no se versionan:

- Tokens/API keys/credenciales.
- Archivos de autenticacion (`auth*`, `tokens*`, `credentials*`).
- Claves privadas/certificados (`*.pem`, `*.key`, `*.p12`, etc.).
- Historiales, sesiones, state y caches.

## Uso en maquina nueva (paso a paso)

1. Clonar repo.
2. Entrar al directorio.
3. Revisar listas en `packages/official.txt` y `packages/aur.txt`.
4. Ejecutar `./install.sh` (dry-run) para previsualizar.
5. Verificar salida y luego `./install.sh --apply` para instalar + backup + link.
6. En `--apply`, el script tambien ejecuta post-setup Docker automaticamente.
7. Abrir `zsh`, `tmux`, `nvim` y validar que los symlinks quedaron bien.

## Mantenimiento

- Para actualizar paquetes declarados:
  - editar `packages/official.txt` y/o `packages/aur.txt`.
- Para actualizar configuraciones desde la maquina:
  - `./sync.sh --dry-run`
  - revisar `git diff`
  - `./sync.sh --apply`
  - commit
- Para agregar nuevas rutas versionables:
  - sumar mapping en `scripts/link.sh` y en `sync.sh`.
  - reforzar exclusiones en `scripts/sync-excludes.txt` y `.gitignore`.

## Troubleshooting basico

- `pacman` no encontrado:
  - estas fuera de Arch-family o falta el binario en PATH.
- `yay` no encontrado:
  - en `--apply`, el script intenta bootstrap automatico de `yay-bin`.
  - si falla bootstrap, muestra warning y deja pendientes los AUR.
- `sync.sh` no detecta cambios esperados:
  - correr con `--verbose`.
  - verificar si el archivo quedo excluido por seguridad.
- symlink no apunta a lo esperado:
  - revisar mapeos en `scripts/link.sh`.
  - re-ejecutar `./install.sh --apply`.

## Licencia

MIT (placeholder). Si todavia no existe `LICENSE`, agregarlo antes de distribuir formalmente.
