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

PANEL=$(wlr-randr 2>/dev/null | awk '/^DSI/{print $1; exit}')
HDMI=$(wlr-randr 2>/dev/null | awk '/^HDMI/{print $1; exit}')

# Возврат нормального разрешения — на любой выход (обычный, Ctrl+C, kill).
restore() {
  if [ -n "$HDMI" ]; then
    wlr-randr --output "$HDMI" --on --scale 1 --pos 0,0 2>/dev/null
    [ -n "$PANEL" ] && wlr-randr --output "$PANEL" --on --scale 1 --pos 1360,0 2>/dev/null
  elif [ -n "$PANEL" ]; then
    wlr-randr --output "$PANEL" --on --scale 1 --pos 0,0 2>/dev/null
  fi
}
trap restore EXIT INT TERM

# Масштаб поднимаем ТОЛЬКО когда играем на встроенной панели без телевизора.
# Панель 800x480 отдаёт единственный физический режим 800x480, а игре нужно не меньше
# 800x600. Масштаб 0.8 даёт логически 1003x602 — окно игры уменьшено до 1000x600,
# поэтому помещается. (Замеры: 1.0 -> 800x480 мало; 0.8 -> 1003x602; 0.75 -> 1066x640
# с большим запасом, но картинка мельче; 0.7 -> 1144x686 мелко.)
if [ -z "$HDMI" ] && [ -n "$PANEL" ]; then
  wlr-randr --output "$PANEL" --on --scale 0.8 --pos 0,0 2>/dev/null
  sleep 3

  # Окно игры должно помещаться в логическое разрешение (1003x602 при масштабе 0.8).
  # По умолчанию игра просит 1063x600 — это шире, поэтому выставляем 1000x600.
  INI="$GAME/Disciple.ini"
  if [ -f "$INI" ] && ! grep -qaE '^DisplayWidth=1000' "$INI"; then
    cp -a "$INI" "$INI.bak-window" 2>/dev/null
    python3 - "$INI" <<'PY'
import io, re, sys
p = sys.argv[1]
raw = io.open(p, "rb").read().decode("cp1251", "replace")
parts = re.split(r'(\[[^\]]+\])', raw)
out, cur = [], None
for part in parts:
    if re.fullmatch(r'\[[^\]]+\]', part):
        cur = part; out.append(part); continue
    if cur == "[Wrapper]":
        part = re.sub(r'(?im)^(\s*DisplayWidth\s*=\s*).*$', r'\g<1>1000', part, count=1)
        part = re.sub(r'(?im)^(\s*DisplayHeight\s*=\s*).*$', r'\g<1>600', part, count=1)
    out.append(part)
res = "".join(out).replace("\r\n", "\n").replace("\n", "\r\n")
io.open(p, "wb").write(res.encode("cp1251", "replace"))
PY
    echo "Окно игры выставлено 1000x600 (под масштаб 0.8)"
  fi
fi

G=$(xdotool getdisplaygeometry 2>/dev/null)
W=${G% *}; H=${G#* }
if [ "${W:-0}" -lt 1000 ] || [ "${H:-0}" -lt 600 ]; then
  MSG="Экран ${W}x${H} — игре нужно не меньше 800x600.
Подключите телевизор/монитор по HDMI либо выполните scripts/06-screens.sh."
  command -v zenity >/dev/null 2>&1 && zenity --warning --title="Disciples II" --text="$MSG" 2>/dev/null
  echo "ВНИМАНИЕ: $MSG"
fi

cd "$GAME" || exit 1
# Без exec: иначе возврат масштаба после выхода из игры не сработает
wine Discipl2.exe
echo "Игра закрыта — возвращаю нормальное разрешение"
