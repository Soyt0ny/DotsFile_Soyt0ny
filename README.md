# DotsFile Soyt0ny

**[ Arch Linux · Debian/Ubuntu/Parrot ] [ Zsh ] [ Terminal-Focused ]**

One command to set up your entire Linux terminal environment. Auto-detects your OS, installs modern CLI tools, configures your shell, and symlinks your dotfiles.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Soyt0ny/DotsFile_Soyt0ny/main/bootstrap.sh)"
```

---

## Quick Start

### One-liner (recommended)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Soyt0ny/DotsFile_Soyt0ny/main/bootstrap.sh)"
```

This installs `git`, clones the repo, and runs the full installer.

### Manual

```bash
# 1. Clone
git clone https://github.com/Soyt0ny/DotsFile_Soyt0ny.git ~/DotsFile_Soyt0ny
cd ~/DotsFile_Soyt0ny

# 2. Install everything
./setup.sh --yes

# 3. Reload
exec zsh
```

---

## Usage

```bash
./setup.sh --yes          # full install, no prompts
./setup.sh                # same as --yes (installs everything)
./setup.sh --dry-run      # preview only, no changes
./setup.sh --update --yes # incremental update (skip backups, only missing packages)
./scripts/uninstall.sh    # remove dotfiles
```

### Setup flags

| Flag | Description |
|------|-------------|
| *(no flags)* | Install everything (non-interactive) |
| `--yes`, `-y` | Install all modules, non-interactive |
| `--dry-run` | Preview everything without making changes |
| `--update` | Incremental update (skip backups, only missing packages) |
| `--only <module>` | Run a single module |
| `--skip <m1,m2>` | Skip modules |
| `--skip-conflict-check` | Skip conflict detection |
| `-h`, `--help` | Show help |

### Modules

| Module | What it does |
|--------|-------------|
| `devtools` | System packages + language toolchains (gcc, python, php) |
| `project` | Backs up existing configs, symlinks dotfiles from this repo |
| `ai-clis` | Installs AI CLI tools (claude, opencode, copilot, codex, agy) |
| `system` | Post-setup: enables Docker, sets zsh as default shell |

### Examples

```bash
./setup.sh --yes                  # full install, no prompts
./setup.sh --dry-run              # preview only
./setup.sh --update --yes         # update existing install
./setup.sh --only ai-clis --yes   # install only AI CLIs
./setup.sh --skip ai-clis,system  # skip modules
```

---

## What gets installed

### Core (always)
| Tool | Replaces | OS |
|------|----------|----|
| `bat` | `cat` | apt / pacman |
| `eza` | `ls` | brew / pacman |
| `fzf` | find | brew / pacman |
| `ripgrep` | grep | brew / pacman |
| `fd` | find | brew / pacman |
| `zoxide` | cd | brew / pacman |
| `atuin` | shell history | brew / pacman |
| `btop` | top/htop | apt / pacman |
| `fastfetch` | neofetch | brew / pacman |
| `git-delta` | git diff | brew / pacman |

### Dev tools
- **Git**: `lazygit`, `github-cli`
- **Docker**: `docker`, `docker-compose`, `lazydocker`
- **Shell**: `zsh` + `powerlevel10k` + plugins (autocomplete, syntax-highlighting, autosuggestions)
- **Editor**: VS Code + `nano` (default `$EDITOR`)
- **Terminal**: `kitty` (Kanagawa theme)

### Languages
- **Python**: `python`, `pip`, `pyenv`
- **C/C++**: `gcc`, `gdb`, `cmake`, `valgrind`
- **PHP**: `php`, `composer`
- **Node.js**: `nvm` + `pnpm` + `bun`

### AI CLIs
`claude` · `opencode` · `copilot` · `codex` · `agy`

### Dotfiles managed
- `~/.zshrc` — Zsh config (Powerlevel10k, aliases, plugins)
- `~/.p10k.zsh` — Prompt theme
- `~/.tmux.conf` — Tmux multiplexer
- `~/.config/kitty/` — Kitty terminal
- `~/.config/ghostty/` — Ghostty terminal
- `~/.config/git/config` — Git aliases + delta
- `~/.config/atuin/` — Shell history
- `~/.config/btop/` — System monitor
- `~/.config/fastfetch/` — System info
- `~/.config/Code/User/settings.json` — VS Code

---

## Updating

When the repo has new changes, update without reinstalling everything:

```bash
cd ~/DotsFile_Soyt0ny
git pull origin main
./setup.sh --update --yes
```

The `--update` flag:
- Skips backups (your configs are already backed up)
- Only installs **missing** packages (incremental)
- Re-applies dotfile symlinks with latest versions

---

## How it works

### Progress output
All package manager output (`apt`, `pacman`, `brew`) is hidden behind a **spinner**. You only see:

```
⠋ Installing 23 system packages (git docker zsh bat kitty +18 more)
✔ Installed 23 system packages (45s)
```

If something fails, the last 30 lines of the log are shown. Full logs live in `~/.dotfiles-logs/`.

### Install state
The setup tracks what you installed in `~/.config/dotsfile/state.json`. Future runs know what's already there.

### Architecture
```
bootstrap.sh     → one-liner entry point (installs git, clones repo, runs setup)
setup.sh         → main orchestrator (pre-flight checks, modules)
install.sh       → layer-based package + dotfile installer
scripts/
  spinner.sh     → progress indicators + output hiding
  state.sh       → install state persistence
  packages.sh    → OS-aware package manager (pacman/apt/brew)
  link.sh        → symlink dotfiles
  backup.sh      → backup existing configs
  os-detect.sh   → detect Arch vs Debian
  check-requirements.sh → pre-flight validation
  detect-conflicts.sh   → conflict detection
  uninstall.sh          → remove symlinks + restore backups
packages/
  layers/        → per-OS package manifests
  profiles/      → install profiles
configs/         → dotfile templates
```

---

## Uninstall

Removes symlinks and restores your original configs (does NOT uninstall system packages):

```bash
./scripts/uninstall.sh
```

---

## Syncing configs back to the repo

If you modify your local dotfiles and want to push changes back:

```bash
./sync.sh --dry-run    # preview
./sync.sh --apply      # apply
```

Sync direction: **machine → repo**.

---

## Troubleshooting

**Setup fails at requirements check**
- Unsupported OS? Needs Arch or Debian/Ubuntu.
- No internet? Check `ping 8.8.8.8`.
- Running as root? Run as normal user with `sudo`.

**Homebrew fails on Debian**
If brew can't create its sandbox, run `./setup.sh --update` — it retries with the fixes from the latest repo version.

**Tmux colors look broken**
Tmux caches old sessions. Kill the server:
```bash
tmux kill-server
```

**Need to see raw logs**
```bash
ls ~/.dotfiles-logs/
cat ~/.dotfiles-logs/setup-*.log
```
