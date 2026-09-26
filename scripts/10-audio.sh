#!/bin/bash
# 10-audio.sh — звук Disciples II под Wine: почему «ползунок не влияет» и как настроить.
#
# Проверено на Пятнице 26.09.2026. Игра (Miles Sound System, Mss32.dll) в Wine идёт через
# winepulse, то есть системная громкость ей подчиняется. Если кажется иначе — причина почти
# всегда в том, что регулируется НЕ тот выход:
#   у Пятницы активным был Bluetooth-выход на 100%, а громкость крутили у встроенного аудио (18%).
#   Отсюда «ползунок и mute не действуют» — они применялись к другому устройству.
#
# Второй факт: у Bluetooth-колонок аппаратной громкости обычно нет, работает программная —
# она управляется штатно (pactl set-sink-volume). Никаких module-combine-sink не требуется,
# современный PipeWire отдаёт громкость BT сам. Старая схема с combine-sink была мёртвой.
set -u
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
GAME="$WINEPREFIX/drive_c/Disciples2"
TARGET="${TARGET_VOLUME:-35}"

echo "=== 1) какой выход основной — его и регулирует ползунок в панели:"
pactl get-default-sink 2>/dev/null | sed 's/^/   /'
echo "   --- все выходы и их громкость:"
pactl list sinks 2>/dev/null | grep -E "Description:|Mute:|Volume:" | sed 's/^/      /'

echo
echo "=== 2) выставляю громкость ВСЕХ выходов на ${TARGET}% (иначе легко крутить не тот):"
for s in $(pactl list short sinks 2>/dev/null | awk '{print $2}'); do
  pactl set-sink-volume "$s" "${TARGET}%" 2>/dev/null && echo "   $s → ${TARGET}%"
done

echo
echo "=== 3) настройки звука самой игры (это проценты):"
if [ -f "$GAME/Disciple.ini" ]; then
  grep -aE "MusicVolume|FxVolume|Music=|SoundFX=" "$GAME/Disciple.ini" | sed 's/^/   /'
  echo "   MusicVolume и FxVolume можно снизить, если всё ещё громко (10-15 = тихо)"
else
  echo "   нет $GAME/Disciple.ini — сначала установите игру (scripts/02-install-game.sh)"
fi

echo
echo "=== 4) аудиодрайвер Wine:"
grep -a "winepulse\|winealsa" "$WINEPREFIX/user.reg" 2>/dev/null | head -3 | sed 's/^/   /'
echo "   winepulse = через PipeWire, системная громкость действует (это правильный вариант)"

echo
echo "=== 5) если звук щёлкает или хрипит — увеличенный квант PipeWire:"
echo "   конфиг: /etc/pipewire/pipewire.conf.d/*.conf → default.clock.quantum = 2048"
ls /etc/pipewire/pipewire.conf.d/ 2>/dev/null | sed 's/^/   /' || echo "   (каталога нет — квант по умолчанию)"

echo
echo "=== 6) проверка: подать короткий тест на текущий выход:"
if [ -f /usr/share/sounds/alsa/Front_Center.wav ]; then
  paplay /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null && echo "   тестовый звук подан"
else
  echo "   тестового файла нет, проверьте вручную в игре"
fi