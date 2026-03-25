#!/usr/bin/env bash
# OS detection abstraction

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      arch|manjaro|endeavouros)
        echo "arch"
        ;;
      debian|ubuntu|linuxmint|pop)
        echo "debian"
        ;;
      *)
        echo "unknown"
        ;;
    esac
  else
    echo "unknown"
  fi
}

sys_install() {
  local os
  os="$(detect_os)"
  local -a packages=("$@")
  
  if [ "${#packages[@]}" -eq 0 ]; then
    return 0
  fi

  case "$os" in
    arch)
      sudo pacman -S --needed --noconfirm "${packages[@]}"
      ;;
    debian)
      sudo apt-get update -y && sudo apt-get install -y "${packages[@]}"
      ;;
    *)
      echo "Unsupported OS for sys_install: $os" >&2
      return 1
      ;;
  esac
}
