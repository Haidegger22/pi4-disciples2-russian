#!/bin/bash
# 05-audio-buffer.sh — убираем щелчки и помехи в звуке.
#
# Причина: игра 2002 года работает на 22 кГц, а PipeWire по умолчанию стоит на 48 кГц
# с малым квантом 1024 — буфер не успевает заполняться, слышны щёлкающие артефакты.
# Лечение: увеличить буфер. Правка ПОЛЬЗОВАТЕЛЬСКАЯ, системные файлы не трогаются.
set -u

echo "=== До настройки:"
pw-dump 2>/dev/null | grep -o '"default.clock.quantum": [0-9]*' | head -1 | sed 's/^/    /' || echo "    (не удалось прочитать)"

echo "=== Создаю конфиг буфера"
mkdir -p "$HOME/.config/pipewire/pipewire.conf.d"
cat > "$HOME/.config/pipewire/pipewire.conf.d/99-buffer.conf" <<'CONF'
# Увеличенный звуковой буфер: старая игра (22 кГц) даёт щелчки при малом кванте.
context.properties = {
    default.clock.quantum = 2048
    default.clock.min-quantum = 1024
    default.clock.max-quantum = 8192
}
CONF
cat "$HOME/.config/pipewire/pipewire.conf.d/99-buffer.conf" | sed 's/^/    /'

echo "=== Перезапускаю звуковую службу"
systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null && echo "    перезапущено"
sleep 6

echo "=== После настройки:"
Q=$(pw-dump 2>/dev/null | grep -o '"default.clock.quantum": [0-9]*' | head -1)
echo "    $Q"
case "$Q" in
  *2048*) echo "    буфер увеличен — готово" ;;
  *)      echo "    ВНИМАНИЕ: значение не изменилось, проверьте конфиг вручную" ;;
esac

echo
echo "Откат: rm ~/.config/pipewire/pipewire.conf.d/99-buffer.conf && systemctl --user restart pipewire wireplumber"
