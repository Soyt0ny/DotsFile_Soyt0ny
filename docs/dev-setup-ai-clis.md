# Setup de AI CLIs en Linux (sin autenticacion)

## Proposito

Este setup instala de forma reproducible los principales CLIs de IA para desarrollo local en Linux, sin iniciar sesion ni configurar credenciales durante la instalacion.

## Que instala

El script `scripts/install-ai-clis-linux.sh` realiza:

1. Validacion de entorno Linux.
2. Verificacion de requisitos minimos (`bash`, `curl`).
3. Instalacion de `nvm` (si no existe).
4. Instalacion de Node LTS por `nvm`.
5. Instalacion de gestores de paquetes JS: `pnpm` y `bun` (instaladores oficiales).
6. Instalacion de `pyenv` en Debian (en Arch viene del AUR, capa `lang-python`).
7. Instalacion por npm global de:
   - `@openai/codex`
8. Instalacion por metodos oficiales de script de:
   - OpenCode (`https://opencode.ai/install`)
   - GitHub Copilot CLI (`https://gh.io/copilot-install`)
   - Claude Code (`https://claude.ai/install.sh`)
   - Antigravity CLI / `agy` (`https://antigravity.google/cli/install.sh`)
     — reemplaza a Gemini CLI, dado de baja por Google el 2026-06-18.

## Que NO hace

- No ejecuta login en OpenAI, Google, GitHub, Anthropic ni OpenCode.
- No setea API keys.
- No modifica configuraciones de dotfiles del repo.

## Como ejecutar

Desde la raiz del repo:

```bash
./scripts/install-ai-clis-linux.sh
```

Si no tenes permisos de ejecucion:

```bash
chmod +x ./scripts/install-ai-clis-linux.sh
./scripts/install-ai-clis-linux.sh
```

## Como verificar

El script imprime un resumen final con estado/version de cada binario detectado.

Verificacion manual opcional:

```bash
codex --version
opencode --version
agy --version
copilot --version
claude --version
pnpm --version
bun --version
```

## Troubleshooting basico

- **Error: no es Linux**
  - El script esta restringido a Linux y aborta en otros sistemas.

- **`curl` o `bash` faltante**
  - Instala los paquetes con tu package manager y reintenta.

- **`copilot` no instalado**
  - Revisa conectividad y que `curl` pueda descargar `https://gh.io/copilot-install`.
  - Reejecuta el script para reintentar la instalacion oficial.

- **Binarios no visibles en shell actual**
  - Abri una nueva terminal o recarga tu shell (`source ~/.bashrc` o `source ~/.zshrc`).
  - Verifica que `nvm` y los paths de binarios esten en `PATH`.

- **Fallo descargando instaladores oficiales**
  - Revisa conectividad de red, proxy corporativo y certificados TLS.
