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

HDMI="${HDMI:-HDMI-A-1}"
PANEL="${PANEL:-DSI-1}"
PANEL_SCALE="${PANEL_SCALE:-0.7}"

echo "=== Текущее состояние:"
wlr-randr 2>/dev/null | grep -E "^[A-Za-z]|current|Scale|Position" | sed 's/^/    /'

echo
echo "=== Ставлю: телевизор в 0,0, панель справа"
if wlr-randr --output "$HDMI" --on --scale 1 --pos 0,0 2>/dev/null; then
  echo "    $HDMI — позиция 0,0, масштаб 1"
else
  echo "    $HDMI не найден (телевизор выключен?) — пропускаю"
fi

# панель ставим за телевизором; если телевизора нет, панель обязана быть в 0,0
if wlr-randr --output "$PANEL" --on --scale "$PANEL_SCALE" --pos 1360,0 2>/dev/null; then
  echo "    $PANEL — позиция 1360,0, масштаб $PANEL_SCALE"
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
# Экраны: телевизор слева основной, встроенная панель справа с масштабом 0.7.
# Масштаб панели нужен, чтобы её логическое разрешение (1144x686) было не меньше
# 800x600 — иначе Disciples II не инициализируется на встроенном экране.
sleep 3
wlr-randr --output HDMI-A-1 --on --scale 1 --pos 0,0 2>/dev/null
wlr-randr --output DSI-1 --on --scale 0.7 --pos 1360,0 2>/dev/null
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
