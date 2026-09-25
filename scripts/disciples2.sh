#!/bin/bash
# disciples2.sh — запуск Disciples II в один клик.
#
# Ставится как ярлык на рабочий стол и в меню. Поднимает нужные переменные Wine,
# проверяет размер экрана (игре нужно не меньше 1000x600 логических) и запускает игру.
#
# Установка ярлыка:
#   mkdir -p ~/Desktop ~/.local/share/applications
#   cp disciples2.sh ~/disciples2.sh && chmod +x ~/disciples2.sh
#   cat > ~/Desktop/disciples2.desktop <<EOF
#   [Desktop Entry]
#   Type=Application
#   Name=Disciples II
#   Exec=$HOME/disciples2.sh
#   Icon=$HOME/.wine-disciples/drive_c/Disciples2/Disciples2RotE.ico
#   Terminal=false
#   Categories=Game;
#   EOF
#   chmod +x ~/Desktop/disciples2.desktop
set -u

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
export WINEDLLOVERRIDES="mscoree,mshtml="
export WINEDEBUG=-all
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

GAME="$WINEPREFIX/drive_c/Disciples2"
if [ ! -d "$GAME" ]; then
  echo "Нет каталога игры: $GAME"
  echo "Сначала выполните scripts/02-install-game.sh"
  exit 1
fi

# Игре нужно не меньше 800x600; на встроенной панели 800x480 выручает масштаб 0.7
# (см. 06-screens.sh) — тогда логическое разрешение становится 1144x686.
G=$(xdotool getdisplaygeometry 2>/dev/null)
W=${G% *}; H=${G#* }
if [ "${W:-0}" -lt 1000 ] || [ "${H:-0}" -lt 600 ]; then
  MSG="Экран ${W}x${H} — игре нужно не меньше 800x600.
Подключите телевизор/монитор по HDMI либо выполните scripts/06-screens.sh,
он поднимет логическое разрешение встроенной панели до 1144x686."
  if command -v zenity >/dev/null 2>&1; then
    zenity --warning --title="Disciples II" --text="$MSG" 2>/dev/null
  fi
  echo "ВНИМАНИЕ: $MSG"
fi

cd "$GAME" || exit 1
exec wine Discipl2.exe
