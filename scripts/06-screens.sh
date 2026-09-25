#!/bin/bash
# 06-screens.sh — два экрана: телевизор по HDMI основной слева, встроенная панель справа.
#
# ГЛАВНОЕ ПРАВИЛО (проверено): игра открывается на том экране, который стоит в
# координатах 0,0. Поэтому телевизор должен быть в 0,0 — иначе игра уйдёт на встроенный
# экран, а если телевизор выключен, окно вообще уедет за границу видимой области.
#
# Имена выходов узнать так:  wlr-randr
#   телевизор по HDMI — обычно HDMI-A-1, встроенная панель — DSI-1.
#
# Встроенная панель 800x480 меньше минимума игры (800x600), поэтому её масштаб 0.7
# поднимает логическое разрешение до 1144x686 — тогда игра запускается и на ней.
set -u

PANEL_SCALE="${PANEL_SCALE:-0.7}"
LOG="${LOG:-/tmp/screens-setup.log}"

echo "=== Выходы сейчас:"
wlr-randr 2>/dev/null | grep -E "^[A-Za-z]|current" | sed 's/^/    /'

HDMI=$(wlr-randr 2>/dev/null | awk '/^HDMI/{print $1; exit}')
PANEL=$(wlr-randr 2>/dev/null | awk '/^DSI/{print $1; exit}')
echo "=== Определено: телевизор='${HDMI:-нет}', встроенная панель='${PANEL:-нет}'"

if [ -n "$HDMI" ]; then
  wlr-randr --output "$HDMI" --on --scale 1 --pos 0,0 2>/dev/null \
    && echo "    $HDMI — позиция 0,0, масштаб 1 (основной)"
  if [ -n "$PANEL" ]; then
    wlr-randr --output "$PANEL" --on --scale "$PANEL_SCALE" --pos 1360,0 2>/dev/null \
      && echo "    $PANEL — позиция 1360,0, масштаб $PANEL_SCALE"
  fi
  echo "Экраны: телевизор $HDMI в 0,0, панель ${PANEL:-нет} справа" >> "$LOG"
else
  if [ -n "$PANEL" ]; then
    wlr-randr --output "$PANEL" --on --scale "$PANEL_SCALE" --pos 0,0 2>/dev/null \
      && echo "    $PANEL — позиция 0,0, масштаб $PANEL_SCALE (телевизора нет)"
  fi
  echo "Экраны: телевизора нет, панель ${PANEL:-нет} в 0,0" >> "$LOG"
fi
sleep 4

echo
echo "=== Результат:"
xrandr --listmonitors 2>/dev/null | sed 's/^/    /'
echo "    рабочий стол: $(xdotool getdisplaygeometry 2>/dev/null)"

echo
echo "=== Закрепляю в автозапуске рабочего стола"
mkdir -p "$HOME/.config/labwc"
cat > "$HOME/.config/labwc/autostart-screen.sh" <<'SH'
#!/bin/bash
# Настройка экранов для Disciples II.
# Игра открывается на экране в координатах 0,0. Телевизор подключён — он в 0,0,
# панель правее. Телевизора нет — панель в 0,0, иначе окно игры уедет за границу
# видимой области (игра идёт, звук есть, картинки не видно).
# Масштаб 0.7 поднимает логическое разрешение панели 800x480 до 1144x686,
# иначе игре не хватает минимума 800x600.
sleep 4

HDMI=$(wlr-randr 2>/dev/null | awk '/^HDMI/{print $1; exit}')
PANEL=$(wlr-randr 2>/dev/null | awk '/^DSI/{print $1; exit}')

if [ -n "$HDMI" ]; then
    wlr-randr --output "$HDMI" --on --scale 1 --pos 0,0 2>/dev/null
    if [ -n "$PANEL" ]; then
        wlr-randr --output "$PANEL" --on --scale 0.7 --pos 1360,0 2>/dev/null
    fi
    echo "Экраны: телевизор $HDMI в 0,0, панель $PANEL справа" >> /tmp/screens-setup.log
else
    if [ -n "$PANEL" ]; then
        wlr-randr --output "$PANEL" --on --scale 0.7 --pos 0,0 2>/dev/null
    fi
    echo "Экраны: телевизора нет, панель $PANEL в 0,0" >> /tmp/screens-setup.log
fi
SH
chmod +x "$HOME/.config/labwc/autostart-screen.sh"
A="$HOME/.config/labwc/autostart"
touch "$A"
grep -q "autostart-screen.sh" "$A" 2>/dev/null || echo "$HOME/.config/labwc/autostart-screen.sh &" >> "$A"
echo "    автозапуск:"
sed 's/^/      /' "$A"

echo
echo "ПРИМЕЧАНИЕ: включайте телевизор ДО запуска игры. Если выключать/включать его"
echo "во время игры, система перестраивает экраны и окно уезжает за границу области."
echo "В этом случае: выключите телевизор -> запустите 06-screens.sh заново -> запустите игру."
