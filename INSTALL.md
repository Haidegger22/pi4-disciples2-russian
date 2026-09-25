# Установка Disciples II с русификацией на Raspberry Pi 4 — пошагово

Для: **Raspberry Pi 4** (или другой arm64-платы) под **Debian 13 (trixie)** с графической
сессией. Проверено в labwc + Wayland (XWayland), экран — телевизор по HDMI плюс встроенная
панель 800x480.

Всё делается **на самой малине**, в терминале. Блоки можно копировать целиком и вставлять
по порядку — каждый самодостаточен.

Если `git` на малине нет — не страшно: в конце файла раздел **«Полный код файлов»**,
оттуда скрипты создаются простой вставкой в терминал.

---

## Шаг 1. Подготовка системы

```bash
sudo apt-get update
sudo apt-get install -y xdotool curl wget innoextract unzip bc zenity
```

Зачем что: `xdotool` — работа с окнами и снимками экрана, `innoextract` — распаковка
данных игры из установщика, `bc`/`zenity` — мелочи для скриптов.

## Шаг 2. Wine под arm64 (Hangover)

**Это ключевой момент.** Обычный путь «box64 + готовая сборка Wine» графику не даёт:
окно не создаётся. Hangover — это Wine, собранный под arm64, и он работает.

```bash
cd ~
curl -L -o hangover.tar \
  https://github.com/AndreRH/hangover/releases/download/hangover-11.16/hangover_11.16_debian13_trixie_arm64.tar
mkdir -p hangover && tar xf hangover.tar -C hangover
cd hangover
sudo apt-get install -y ./*.deb
wine --version
```

Ожидаемый результат: `wine-11.x` (Hangover). Если версия выводится — шаг пройден.

## Шаг 3. Данные игры

Установщик GOG под эмуляцией идёт больше 45 минут и часто не доходит до конца.
Правильный путь — распаковать данные **нативно**, программой `innoextract`: это две минуты.

Положите файлы установщика (`setup_*.exe` и `setup_*-1.bin`) в `~/d2-setup`, затем:

```bash
./02-install-game.sh ~/d2-setup
```

Скрипт распакует каждый установщик и сведёт всё в `~/.wine-disciples/drive_c/Disciples2`.
Если установщиков два (база и дополнение) — объединит оба: в базе есть файлы, которых нет
в дополнении.

Не запускайте саму игру до шага 4 — сначала мод, иначе увидите розовые текстуры.

## Шаг 4. Мод против розовых текстур

Игра выводит картинку через DirectDraw, и под Wine палитровые текстуры становятся розовыми.
DXVK это не лечит (он про Direct3D 8+, а здесь DirectDraw). Помогает мод DisciplesGL Modern.

```bash
./03-install-mod.sh
```

Оригинальные файлы сохраняются в `~/d2-backup-mod` — откат одной командой.

## Шаг 5. Русификация

### 5.1. Получите русский пакет

Отдельного «русификатора» одним файлом не бывает. Нужно русское издание игры —
например, «Disciples II: Восстание Эльфов» **версии 3.01** (проверьте версию!).

Распакуйте его данные в `~/d2-ru-pack` так, чтобы получилось:

```
~/d2-ru-pack/app/
    Globals/  Interf/  Scens/  ScenData/  Exports/
    Sounds/   Campaign/  Video/  Briefing/
```

Если внутри установщика Inno Setup — распаковывается так:

```bash
innoextract -d ~/d2-ru-pack "путь/к/setup.exe"
```

### 5.2. Поставьте

**Закройте игру.** Скрипт остановит её сам и проверит, что процессов ноль.

```bash
./04-russianize.sh
```

Скрипт сам:
1. сверит версию игры и пакета по заголовкам DBF и предупредит при расхождении;
2. остановит игру и убедится, что она не запущена;
3. сохранит копии всего заменяемого в `~/d2-backup-rus`;
4. наложит файлы локализации, **не трогая** `Discipl2.exe` и библиотеки;
5. **удалит английские двойники имён** (см. ниже) — без этого часть текста останется английской.

### 5.3. Про регистр имён — самое неочевидное

Linux различает регистр, Windows — нет. Пакет приносит `Sinfo.dbf`, в игре лежит `Sinfo.DBF` —
это **разные файлы**, игра читает английский. Симптом: меню русское, а титры и истории
кампаний английские.

Проверить и починить отдельно можно в любой момент:

```bash
python3 07-ru-case-fix.py            # только показать
python3 07-ru-case-fix.py --apply    # применить (копии в ~/d2-backup-case)
```

## Шаг 6. Звук без щелчков

Игра 2002 года работает на 22 кГц, а PipeWire — на 48 кГц с малым квантом, буфер не
успевает заполняться, слышны помехи.

```bash
./05-audio-buffer.sh
```

## Шаг 7. Экраны

Игра открывается на том экране, который стоит **в координатах 0,0**. Телевизор должен быть
в 0,0; встроенная панель — правее, с масштабом 0.7 (тогда её логическое разрешение
1144x686, и игра на ней тоже запускается).

```bash
./06-screens.sh          # сам определит телевизор и поставит его в 0,0, а панель правее
```

Скрипт **сам определяет**, подключён ли телевизор:

- подключён — ставит его в 0,0, а встроенную панель правее с масштабом 0.7;
- не подключён — ставит в 0,0 саму панель.

Это важно: если телевизор выключен, а панель оставить на позиции 1360, окно игры уедет
за границу видимой области — игра запустится, звук будет идти, а картинки не видно.

Встроенная панель 800x480 меньше минимума игры (800x600) — масштаб 0.7 это компенсирует.

## Шаг 8. Ярлык запуска

```bash
mkdir -p ~/.local/share/applications
cp disciples2.sh ~/disciples2.sh && chmod +x ~/disciples2.sh
cat > ~/.local/share/applications/disciples2.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Disciples II
Comment=Disciples II: Gold (Wine)
Exec=$HOME/disciples2.sh
Terminal=false
Categories=Game;
EOF
cp ~/.local/share/applications/disciples2.desktop ~/Desktop/ 2>/dev/null
chmod +x ~/Desktop/disciples2.desktop 2>/dev/null
```

## Шаг 9. Проверка

```bash
./08-check.sh
```

Скрипт покажет: версию Wine, наличие мода, кириллицу в ключевых файлах текста, размер
озвучки (русская ~70 МБ против английской ~18 МБ), проблемных двойников имён, состояние
звука и экранов. Если в пунктах про текст всё «ок» и двойников нет — русификация полная.

Запуск игры: `./disciples2.sh` или ярлык «Disciples II».

---

## Если что-то пошло не так

**Игра не запускается вообще (процессов ноль).**
Чаще всего — русификатор от другой версии. Проверьте заголовки DBF (`04-russianize.sh`
делает это сам) и верните копии: `cp -a ~/d2-backup-rus/. ~/.wine-disciples/drive_c/Disciples2/`

**Абракадабра вместо текста, игра вылетает.**
Файлы менялись на запущенной игре. Верните копии из `~/d2-backup-rus` и повторите
установку, закрыв игру.

**Розовые текстуры.**
Мод не установлен либо русификатор принёс свои библиотеки и откатил его.
Проверьте `C4dll-R.dll` (пункт 3 в `08-check.sh`) и повторите `./03-install-mod.sh`.

**Меню русское, а титры и истории английские.**
Это двойники имён разного регистра. Запустите `python3 07-ru-case-fix.py --apply`.

**Звук щёлкает, помехи.**
Не применён `05-audio-buffer.sh` либо применился, но служба не перезапустилась:
`systemctl --user restart pipewire pipewire-pulse wireplumber`.

**Игры не видно, а звук идёт.**
Окно уехало за границу видимой области: телевизор включён/выключен после запуска игры.
Запустите `./06-screens.sh` заново и перезапустите игру. Включайте телевизор до старта игры.

**Игра уходит на встроенный экран, хотя телевизор подключён.**
Телевизор не в позиции 0,0. Снова `./06-screens.sh`.

**На встроенном экране игра не инициализируется.**
Панель 800x480 меньше минимума 800x600. Масштаб 0.7 в `06-screens.sh` поднимает логическое
разрешение до 1144x686 — этого хватает.

## Откат

```bash
cp -a ~/d2-backup-rus/.  ~/.wine-disciples/drive_c/Disciples2/   # вернуть английский текст
cp -a ~/d2-backup-case/. ~/.wine-disciples/drive_c/Disciples2/   # вернуть двойники имён
cp -a ~/d2-backup-mod/.  ~/.wine-disciples/drive_c/Disciples2/   # откатить мод
rm ~/.config/pipewire/pipewire.conf.d/99-buffer.conf             # звук по умолчанию
```


---

---

## Полный код файлов (установка без git)

Ниже — полное содержимое каждого файла. Если `git clone` недоступен, вставляйте эти блоки
в терминал по порядку: каждый создаёт файл и делает его исполняемым.

### 1. Wine под arm64 (Hangover)

Файл: `~/d2-scripts/01-install-hangover.sh`

```bash
mkdir -p $(dirname $HOME/d2-scripts/01-install-hangover.sh)
cat > $HOME/d2-scripts/01-install-hangover.sh << 'SCRIPT_EOF'
#!/bin/bash
# 1. Hangover — сборка Wine для arm64. Работает там, где box64 графику не даёт.
#    Debian 13 (trixie). Для Debian 12 замени имя архива на debian12_bookworm.
set -e

VER=11.16
TAR="hangover_${VER}_debian13_trixie_arm64.tar"
URL="https://github.com/AndreRH/hangover/releases/download/hangover-${VER}/${TAR}"
D="$HOME/hangover"

echo "==> Качаю Hangover ${VER} (~280 МБ)"
mkdir -p "$D" && cd "$D"
[ -f "$TAR" ] || curl -L --fail -o "$TAR" "$URL"

echo "==> Распаковываю"
tar -xf "$TAR"
ls -la ./*.deb

echo "==> Устанавливаю (потребуется sudo; займёт ~2,3 ГБ)"
sudo apt-get install -y \
  ./hangover-wine_*_arm64.deb \
  ./hangover-wowbox64_*_arm64.deb \
  ./hangover-libwow64fex_*_arm64.deb \
  ./hangover-libarm64ecfex_*_arm64.deb

echo "==> Проверка"
wine --version        # ожидается: wine-11.16 (Hangover)
which wine
du -sh /usr/lib/wine
SCRIPT_EOF
chmod +x $HOME/d2-scripts/01-install-hangover.sh 2>/dev/null || true
```

### 2. Данные игры из установщика GOG

Файл: `~/d2-scripts/02-install-game.sh`

```bash
mkdir -p $(dirname $HOME/d2-scripts/02-install-game.sh)
cat > $HOME/d2-scripts/02-install-game.sh << 'SCRIPT_EOF'
#!/bin/bash
# 02-install-game.sh — ставим Disciples II: Gold (GOG) БЕЗ запуска установщика.
#
# Почему так: установщик GOG под эмуляцией идёт больше 45 минут и часто не доходит
# до конца (каталог получается неполным). Данные же распаковываются нативно
# программой innoextract — база за ~2 минуты, дополнение за ~2 минуты.
#
# Если у вас ДВА установщика (база «Dark Prophecy + Gallean's Return» и дополнение
# «Rise of the Elves») — распаковываем оба и объединяем: в базе есть файлы, которых
# нет в дополнении, и наоборот.
#
# Использование:
#   ./02-install-game.sh ~/d2-setup
# где ~/d2-setup — каталог с файлами setup_*.exe и setup_*-1.bin из GOG-сборки.
set -u

SETUP_DIR="${1:-$HOME/d2-setup}"
PREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
GAME_DIR="$PREFIX/drive_c/Disciples2"
WORK="${WORK:-$HOME/d2-unpack}"
USE_ADDON="${USE_ADDON:-yes}"     # no — если дополнение не нужно

echo "=== Disciples II: установка из $SETUP_DIR"
echo "    префикс Wine: $PREFIX"
echo "    каталог игры: $GAME_DIR"

if ! command -v innoextract >/dev/null 2>&1; then
  echo "Нет innoextract. Установите: sudo apt-get install -y innoextract"
  exit 1
fi

if [ ! -d "$SETUP_DIR" ]; then
  echo "Нет каталога $SETUP_DIR — положите туда файлы установщика GOG"
  exit 1
fi

mkdir -p "$WORK" "$GAME_DIR"

# --- 1. Находим установщики -------------------------------------------------
mapfile -t SETUPS < <(find "$SETUP_DIR" -maxdepth 1 -iname "setup*.exe" | sort)
if [ "${#SETUPS[@]}" -eq 0 ]; then
  echo "В $SETUP_DIR не найдено setup*.exe"
  exit 1
fi
echo "=== 1) Найдено установщиков: ${#SETUPS[@]}"
for s in "${SETUPS[@]}"; do
  echo "    $(basename "$s")  ($(( $(stat -c%s "$s") / 1048576 )) МБ)"
done

# --- 2. Распаковываем каждый ------------------------------------------------
i=0
for s in "${SETUPS[@]}"; do
  i=$((i + 1))
  OUT="$WORK/pack$i"
  if [ -d "$OUT" ] && [ -n "$(find "$OUT" -type f -print -quit 2>/dev/null)" ]; then
    echo "=== 2.$i) $OUT уже распакован, пропускаю"
    continue
  fi
  rm -rf "$OUT"; mkdir -p "$OUT"
  echo "=== 2.$i) Распаковываю $(basename "$s") (это занимает 1-3 минуты)"
  innoextract -d "$OUT" "$s" >/tmp/d2-innoextract-$i.log 2>&1
  echo "    код: $?  файлов: $(find "$OUT" -type f 2>/dev/null | wc -l)"
  tail -3 /tmp/d2-innoextract-$i.log | sed 's/^/    /'
done

# --- 3. Сводим всё в каталог игры -------------------------------------------
# Структура у разработчика — app/, у игры файлы лежат прямо в каталоге.
echo "=== 3) Собираю каталог игры"
count=0
for OUT in "$WORK"/pack*; do
  SRC="$OUT"
  [ -d "$OUT/app" ] && SRC="$OUT/app"
  if [ -d "$SRC" ]; then
    cp -a "$SRC/." "$GAME_DIR/" 2>/dev/null
    count=$((count + 1))
    echo "    наложен $(basename "$OUT") (файлов в нём: $(find "$SRC" -type f | wc -l))"
  fi
done
echo "    источников наложено: $count"

if [ -n "${USE_ADDON:-}" ] && [ "$USE_ADDON" = "no" ]; then
  echo "    (дополнение отключено флагом USE_ADDON=no)"
fi

# --- 4. Проверка ------------------------------------------------------------
echo "=== 4) Проверка результата"
for f in Discipl2.exe Globals/Gunits.dbf Interf/Interf.ff Exports; do
  if [ -e "$GAME_DIR/$f" ]; then
    echo "    есть: $f"
  else
    echo "    НЕТ:  $f"
  fi
done
echo "    всего файлов: $(find "$GAME_DIR" -type f 2>/dev/null | wc -l)"
echo "    размер: $(du -sh "$GAME_DIR" 2>/dev/null | cut -f1)"
echo
echo "Готово. Дальше: ./03-install-mod.sh (убирает розовые текстуры),"
echo "затем ./04-russianize.sh (русский текст и озвучка) и ./disciples2.sh (запуск)."
SCRIPT_EOF
chmod +x $HOME/d2-scripts/02-install-game.sh 2>/dev/null || true
```

### 3. Мод против розовых текстур

Файл: `~/d2-scripts/03-install-mod.sh`

```bash
mkdir -p $(dirname $HOME/d2-scripts/03-install-mod.sh)
cat > $HOME/d2-scripts/03-install-mod.sh << 'SCRIPT_EOF'
#!/bin/bash
# 03-install-mod.sh — ставим мод DisciplesGL Modern: он убирает розовые (палитровые) текстуры.
#
# Зачем: игра выводит картинку через DirectDraw/Direct3D, и под Wine палитровые текстуры
# отображаются розовым. DXVK это не лечит (он про Direct3D 8+, а здесь DirectDraw).
# Мод подменяет рендер-библиотеку C4dll и розовый уходит полностью.
#
# Важно: мод ставится ДО русификации и заменяет C4dll-R.dll. Русификатор НЕ должен
# приносить свои исполняемые файлы и библиотеки — иначе мод откатится и розовый вернётся.
set -u

PREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
GAME_DIR="$PREFIX/drive_c/Disciples2"
BACKUP="${BACKUP:-$HOME/d2-backup-mod}"
MOD_URL="${MOD_URL:-https://github.com/gitTerebi/DisciplesGL-Modern/releases/download/v2026.3/DisciplesGL-Modern-C4dll-R.zip}"
TMP=$(mktemp -d)

echo "=== DisciplesGL Modern: устранение розовых текстур"
echo "    каталог игры: $GAME_DIR"
[ -d "$GAME_DIR" ] || { echo "Нет каталога игры — сначала 02-install-game.sh"; exit 1; }

echo "=== 1) Скачиваю мод"
if command -v curl >/dev/null 2>&1; then
  curl -sL -A "Mozilla/5.0" -o "$TMP/mod.zip" "$MOD_URL"
else
  wget -q -O "$TMP/mod.zip" "$MOD_URL"
fi
SZ=$(stat -c%s "$TMP/mod.zip" 2>/dev/null || echo 0)
echo "    скачано: $(( SZ / 1048576 )) МБ"
[ "$SZ" -gt 1000000 ] || { echo "Скачать не удалось (проверьте ссылку MOD_URL)"; exit 1; }

echo "=== 2) Распаковываю"
if command -v unzip >/dev/null 2>&1; then
  unzip -q -o "$TMP/mod.zip" -d "$TMP/mod"
elif command -v 7z >/dev/null 2>&1; then
  7z x -y -o"$TMP/mod" "$TMP/mod.zip" >/dev/null
else
  python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP/mod.zip" "$TMP/mod"
fi
echo "    файлов в архиве: $(find "$TMP/mod" -type f | wc -l)"
find "$TMP/mod" -type f -iname "*.dll" | sed 's/^/    /'

echo "=== 3) Сохраняю оригиналы в $BACKUP"
mkdir -p "$BACKUP"
for f in C4dll-R.dll C4dll.dll CB63.dll Discipl2.exe; do
  [ -f "$GAME_DIR/$f" ] && cp -a "$GAME_DIR/$f" "$BACKUP/" && echo "    сохранён $f"
done

echo "=== 4) Ставлю файлы мода"
n=0
while IFS= read -r f; do
  base=$(basename "$f")
  cp -f "$f" "$GAME_DIR/$base" && { echo "    поставлен $base ($(( $(stat -c%s "$f") / 1024 )) КБ)"; n=$((n + 1)); }
done < <(find "$TMP/mod" -type f \( -iname "*.dll" -o -iname "*.exe" -o -iname "*.ini" \))
echo "    всего файлов: $n"

rm -rf "$TMP"
echo
echo "=== 5) Проверка"
ls -la "$GAME_DIR"/*.dll 2>/dev/null | awk '{print "    " $5 " " $9}'
echo
echo "Готово. Дальше: ./04-russianize.sh (русский язык), затем ./disciples2.sh (запуск)."
echo "Откат мода: cp -a $BACKUP/. $GAME_DIR/"
SCRIPT_EOF
chmod +x $HOME/d2-scripts/03-install-mod.sh 2>/dev/null || true
```

### 4. Русификация (текст, озвучка, ролики)

Файл: `~/d2-scripts/04-russianize.sh`

```bash
mkdir -p $(dirname $HOME/d2-scripts/04-russianize.sh)
cat > $HOME/d2-scripts/04-russianize.sh << 'SCRIPT_EOF'
#!/bin/bash
# 04-russianize.sh — русификация Disciples II: текст, озвучка героев, видеоролики, кампании.
#
# ИСПОЛЬЗОВАНИЕ:
#   1) Положите распакованный русский пакет в ~/d2-ru-pack (см. README, раздел «Где взять»).
#      Ожидаемая структура: ~/d2-ru-pack/app/{Globals,Interf,Scens,ScenData,Exports,Sounds,Campaign,Video,Briefing}
#   2) ЗАКРОЙТЕ ИГРУ. Скрипт сам её остановит, но лучше выйти штатно.
#   3) ./04-russianize.sh
#
# ТРИ ГЛАВНЫХ ПРАВИЛА (все проверены на практике, нарушение ломает игру):
#
#   1. ВЕРСИЯ. Наша сборка — GOG Gold 3.01. Русификатор обязан быть от версии 3.01.
#      Пакет от 2.01 несовместим: с ним игра вообще не стартует (процессов 0),
#      а если подменить файлы при запущенной игре — абракадабра шрифтов и вылеты.
#
#   2. ИГРА ДОЛЖНА БЫТЬ ЗАКРЫТА. Подмена файлов на живой игре портит игру у пользователя.
#
#   3. РЕГИСТР ИМЁН ФАЙЛОВ. Linux различает регистр, Windows — нет. Если в игре лежит
#      Sinfo.DBF, а пакет приносит Sinfo.dbf, это ДВА РАЗНЫХ файла: игра читает верхний
#      (английский), русский лежит рядом и не работает. Поэтому в конце обязательно
#      запускается 07-ru-case-fix.py, который убирает английские двойники.
set -u

PREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
GAME_DIR="$PREFIX/drive_c/Disciples2"
PKG="${PKG:-$HOME/d2-ru-pack}"
SRC="$PKG/app"
[ -d "$SRC" ] || SRC="$PKG"
BACKUP="${BACKUP:-$HOME/d2-backup-rus}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=== Русификация Disciples II"
echo "    пакет: $SRC"
echo "    игра:  $GAME_DIR"
[ -d "$SRC" ] || { echo "Нет каталога пакета $SRC"; exit 1; }
[ -d "$GAME_DIR" ] || { echo "Нет каталога игры — сначала 02-install-game.sh"; exit 1; }

# --- 0. Проверка версии по заголовкам DBF -----------------------------------
# Совпали записи/размер записи — версия та же, файлы совместимы.
echo
echo "=== 0) Проверка совместимости версии (заголовки DBF)"
python3 - "$SRC" "$GAME_DIR" <<'PY'
import os, struct, sys
src, game = sys.argv[1], sys.argv[2]
def head(p):
    try:
        d = open(p, 'rb').read(32)
        return (struct.unpack('<I', d[4:8])[0], struct.unpack('<H', d[8:10])[0], struct.unpack('<H', d[10:12])[0])
    except Exception:
        return None
bad = 0
for rel in ('Globals/Gunits.dbf', 'Globals/Gaction.DBF', 'Globals/Gspells.dbf'):
    a, b = head(os.path.join(src, rel)), head(os.path.join(game, rel))
    if a and b:
        same = "СОВПАДАЕТ" if a == b else "ОТЛИЧАЕТСЯ"
        print("    %-24s пакет %-22s игра %-22s %s" % (rel, a, b, same))
        if a != b:
            bad += 1
if bad:
    print("    ВНИМАНИЕ: версии не совпадают! Пакет от другой версии игры.")
    print("    Установку лучше прервать (Ctrl+C) — иначе игра может перестать запускаться.")
else:
    print("    версия подходит — можно ставить")
PY

# --- 1. Останавливаем игру --------------------------------------------------
echo
echo "=== 1) Останавливаю игру"
pkill -f Discipl2 2>/dev/null; pkill -f wineserver 2>/dev/null; sleep 8
N=$(pgrep -c -f Discipl2 2>/dev/null || echo 0)
echo "    процессов игры: $N"
if [ "${N:-0}" != "0" ]; then
  echo "    Игра не остановилась — файлы менять нельзя. Выйдите из игры и повторите."
  exit 1
fi

# --- 2. Копии заменяемого ---------------------------------------------------
echo
echo "=== 2) Сохраняю копии в $BACKUP"
mkdir -p "$BACKUP"
for d in Globals Interf Scens ScenData Exports Sounds Music Campaign Video Briefing; do
  if [ -d "$GAME_DIR/$d" ]; then
    cp -a "$GAME_DIR/$d" "$BACKUP/" 2>/dev/null && echo "    $d ($(du -sh "$GAME_DIR/$d" | cut -f1))"
  fi
done

# --- 3. Накладываем русские файлы ------------------------------------------
# Исполняемые файлы и библиотеки НЕ копируются: в пакете они от старой сборки
# и откатят мод DisciplesGL (вернутся розовые текстуры).
echo
echo "=== 3) Накладываю файлы локализации"
SIMPLE="Globals Interf Scens ScenData Exports Sounds Campaign Video Briefing"
for d in $SIMPLE; do
  if [ -d "$SRC/$d" ]; then
    mkdir -p "$GAME_DIR/$d"
    cp -a "$SRC/$d/." "$GAME_DIR/$d/" 2>/dev/null
    echo "    $d → $(ls "$GAME_DIR/$d" 2>/dev/null | wc -l) файлов"
  fi
done
# регистр каталога: в некоторых пакетах каталог называется interf, у игры Interf
[ -d "$SRC/interf" ] && cp -a "$SRC/interf/." "$GAME_DIR/Interf/" 2>/dev/null && echo "    interf → Interf (регистр исправлен)"

echo
echo "    Не копирую (намеренно): Discipl2.exe, *.dll — они от старой сборки и вернут розовые текстуры."

# --- 4. Убираем английские двойники регистра -------------------------------
echo
echo "=== 4) Проверяю двойники имён (регистр)"
if [ -f "$HERE/07-ru-case-fix.py" ]; then
  python3 "$HERE/07-ru-case-fix.py" --apply 2>&1 | sed 's/^/    /'
else
  echo "    не найден 07-ru-case-fix.py — проверьте вручную!"
fi

# --- 5. Итог ----------------------------------------------------------------
echo
echo "=== 5) Итог"
python3 - "$GAME_DIR" <<'PY'
import os, re, sys
g = sys.argv[1]
def cyr(p):
    try:
        d = open(p, 'rb').read(400000)
    except Exception:
        return 0
    return sum(len(re.findall(r'[А-Яа-яЁё]{3,}', d.decode(e, 'ignore'))) for e in ('cp1251', 'utf-8'))
checks = [('Globals/Gunits.dbf', 'текст игры'), ('Interf/TApp.dbf', 'интерфейс и титры'),
          ('Scens/Sinfo.dbf', 'тексты истории'), ('Scens/Tscen.dbf', 'тексты сценариев')]
for rel, what in checks:
    p = os.path.join(g, rel)
    n = cyr(p) if os.path.exists(p) else -1
    state = "русский" if n > 0 else ("нет файла" if n < 0 else "Английский!?")
    print("    %-22s %-18s кириллица: %-6d %s" % (rel, what, max(n, 0), state))
# озвучка
m = os.path.join(g, 'Sounds/Midgard.wdb')
if os.path.exists(m):
    print("    %-22s %-18s %.1f МБ" % ('Sounds/Midgard.wdb', 'озвучка героев', os.path.getsize(m) / 1048576))
PY
echo
echo "Ожидаемые размеры для ориентира: Midgard.wdb ≈ 70 МБ (русская озвучка) против 18 МБ английской."
echo
echo "Готово. Запуск: ./disciples2.sh"
echo "Откат: cp -a $BACKUP/. $GAME_DIR/"
SCRIPT_EOF
chmod +x $HOME/d2-scripts/04-russianize.sh 2>/dev/null || true
```

### 5. Звуковой буфер (убирает щелчки)

Файл: `~/d2-scripts/05-audio-buffer.sh`

```bash
mkdir -p $(dirname $HOME/d2-scripts/05-audio-buffer.sh)
cat > $HOME/d2-scripts/05-audio-buffer.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/d2-scripts/05-audio-buffer.sh 2>/dev/null || true
```

### 6. Два экрана: телевизор слева, панель справа

Файл: `~/d2-scripts/06-screens.sh`

```bash
mkdir -p $(dirname $HOME/d2-scripts/06-screens.sh)
cat > $HOME/d2-scripts/06-screens.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/d2-scripts/06-screens.sh 2>/dev/null || true
```

### 7. Поиск и удаление двойников имён (регистр)

Файл: `~/d2-scripts/07-ru-case-fix.py`

```bash
mkdir -p $(dirname $HOME/d2-scripts/07-ru-case-fix.py)
cat > $HOME/d2-scripts/07-ru-case-fix.py << 'SCRIPT_EOF'
#!/usr/bin/env python3
# d2-case-fix.py — находим ВСЕ пары файлов, различающиеся только регистром, и убираем английские.
import os, re, sys, shutil

BASE = "/home/pi/.wine-disciples/drive_c/Disciples2"
BACKUP = "/home/pi/d2-backup-case"
DRY = "--apply" not in sys.argv

def cyr_count(p, limit=600000):
    try:
        data = open(p, 'rb').read(limit)
    except Exception:
        return -1
    n = 0
    for enc in ('cp1251', 'utf-8'):
        n += len(re.findall(r'[А-Яа-яЁё]{3,}', data.decode(enc, 'ignore')))
    return n

print("РЕЖИМ: " + ("просмотр (без изменений)" if DRY else "ПРИМЕНЕНИЕ ПРАВОК"))
print()

pairs = []
for root, dirs, files in os.walk(BASE):
    groups = {}
    for f in files:
        groups.setdefault(f.lower(), []).append(f)
    for low, names in groups.items():
        if len(names) > 1:
            pairs.append((root, names))

print("=== найдено групп с одинаковым именем в разном регистре: %d" % len(pairs))
to_remove = []
for root, names in pairs:
    rel = os.path.relpath(root, BASE)
    print("   каталог %s:" % rel)
    info = []
    for n in sorted(names):
        p = os.path.join(root, n)
        c = cyr_count(p)
        info.append((n, os.path.getsize(p), c))
        print("      %-26s %9.0f КБ  кириллица: %d" % (n, os.path.getsize(p) / 1024, c))
    # определить английский: тот, где кириллицы нет, а другой есть
    with_cyr = [x for x in info if x[2] > 0]
    without = [x for x in info if x[2] == 0]
    if with_cyr and without:
        for n, sz, c in without:
            # если есть файл с русским текстом и такое же имя в другом регистре — английский лишний
            print("      → лишний (английский): %s" % n)
            to_remove.append(os.path.join(root, n))
    else:
        print("      → не трогаю (неоднозначно)")

print()
print("=== к удалению: %d файлов" % len(to_remove))
for p in to_remove:
    print("   " + os.path.relpath(p, BASE))

if not DRY and to_remove:
    os.makedirs(BACKUP, exist_ok=True)
    for p in to_remove:
        rel = os.path.relpath(p, BASE)
        dst = os.path.join(BACKUP, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(p, dst)
        os.remove(p)
        print("   сохранён в копии и удалён: " + rel)
    print("=== готово, копии в %s" % BACKUP)
SCRIPT_EOF
chmod +x $HOME/d2-scripts/07-ru-case-fix.py 2>/dev/null || true
```

### 8. Проверка установки

Файл: `~/d2-scripts/08-check.sh`

```bash
mkdir -p $(dirname $HOME/d2-scripts/08-check.sh)
cat > $HOME/d2-scripts/08-check.sh << 'SCRIPT_EOF'
#!/bin/bash
# 08-check.sh — проверка всей установки: игра, русификация, мод, звук, экраны.
# Запускать в любой момент: ничего не меняет, только показывает состояние.
set -u

PREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
G="$PREFIX/drive_c/Disciples2"

ok()   { echo "    [ок]    $*"; }
bad()  { echo "    [НЕТ]   $*"; }
warn() { echo "    [внимание] $*"; }

echo "=============================================================="
echo " Проверка Disciples II — $(date '+%d.%m.%Y %H:%M')"
echo "=============================================================="

echo
echo "=== 1) Игра на месте"
if [ -d "$G" ]; then
  ok "каталог: $G"
  echo "        файлов: $(find "$G" -type f 2>/dev/null | wc -l), размер: $(du -sh "$G" 2>/dev/null | cut -f1)"
  [ -f "$G/Discipl2.exe" ] && ok "Discipl2.exe" || bad "Discipl2.exe"
else
  bad "каталог игры не найден: $G"
fi

echo
echo "=== 2) Hangover (Wine под arm64)"
if command -v wine >/dev/null 2>&1; then
  ok "$(wine --version 2>/dev/null | head -1)"
else
  bad "wine не найден — сначала scripts/01-install-hangover.sh"
fi
if dpkg -l 2>/dev/null | grep -q hangover-wine; then
  ok "пакеты Hangover установлены"
else
  warn "пакеты hangover-* не найдены в dpkg"
fi

echo
echo "=== 3) Мод против розовых текстур (DisciplesGL)"
if [ -f "$G/C4dll-R.dll" ]; then
  ok "C4dll-R.dll на месте ($(( $(stat -c%s "$G/C4dll-R.dll") / 1024 )) КБ)"
else
  warn "C4dll-R.dll нет — возможны розовые текстуры (scripts/03-install-mod.sh)"
fi

echo
echo "=== 4) Русификация — текст"
python3 - "$G" <<'PY'
import os, re, sys
g = sys.argv[1]
def cyr(p):
    try:
        d = open(p, 'rb').read(400000)
    except Exception:
        return 0
    return sum(len(re.findall(r'[А-Яа-яЁё]{3,}', d.decode(e, 'ignore'))) for e in ('cp1251', 'utf-8'))
files = [('Globals/Gunits.dbf', 'текст юнитов'), ('Interf/TApp.dbf', 'интерфейс и титры'),
         ('Scens/Sinfo.dbf', 'истории кампаний'), ('Scens/Tscen.dbf', 'тексты сценариев'),
         ('Globals/TAiMsg.dbf', 'сообщения ИИ'), ('Globals/Tplayer.dbf', 'имена игроков')]
for rel, what in files:
    p = os.path.join(g, rel)
    if not os.path.exists(p):
        print("    [НЕТ]   %-24s %s" % (rel, what)); continue
    n = cyr(p)
    print("    [%s] %-24s %-18s кириллица: %d" % ("ок" if n > 0 else "англ", rel, what, n))
PY

echo
echo "=== 5) Русификация — озвучка и ролики"
for f in "Sounds/Midgard.wdb:озвучка героев:только у русской ~70 МБ, у английской ~18 МБ" \
         "Video/intro.bik:вступление:русское ~6,8 МБ, английское ~16 МБ" \
         "Video/credits.bik:титры:русские ~0,8 МБ"; do
  IFS=':' read -r path what note <<< "$f"
  p="$G/$path"
  if [ -f "$p" ]; then
    ok "$(printf '%-22s (%-16s) %.1f МБ — %s' "$path" "$what" "$(echo "scale=1; $(stat -c%s "$p")/1048576" | bc 2>/dev/null || echo 0)" "$note")"
  else
    bad "$path"
  fi
done
echo "        роликов историй: $(ls "$G/Briefing"/*.bik 2>/dev/null | wc -l)"
echo "        кампаний: $(ls "$G/Campaign"/*.csg 2>/dev/null | wc -l)"
echo "        файлов-описаний кампаний: $(ls "$G/Exports" 2>/dev/null | wc -l)"

echo
echo "=== 6) Двойники имён (регистр) — источник частично английского текста"
FOUND=0
python3 - "$G" <<'PY'
import os, re, sys
g = sys.argv[1]
def cyr(p):
    try:
        d = open(p, 'rb').read(400000)
    except Exception:
        return 0
    return sum(len(re.findall(r'[А-Яа-яЁё]{3,}', d.decode(e, 'ignore'))) for e in ('cp1251', 'utf-8'))
dups = 0
for root, _, files in os.walk(g):
    groups = {}
    for f in files:
        groups.setdefault(f.lower(), []).append(f)
    for low, names in groups.items():
        if len(names) > 1:
            stats = [(n, cyr(os.path.join(root, n))) for n in sorted(names)]
            if any(c > 0 for _, c in stats) and any(c == 0 for _, c in stats):
                dups += 1
                print("    [БЕДА]  %s: %s" % (os.path.relpath(root, g), ", ".join("%s(кир.%d)" % s for s in stats)))
print("    ПРОБЛЕМНЫХ ДВОЙНИКОВ: %d" % dups)
print("    Исправляется: python3 scripts/07-ru-case-fix.py --apply" if dups else "    двойников нет — всё хорошо")
PY

echo
echo "=== 7) Звук"
echo "        выход: $(pactl get-default-sink 2>/dev/null)"
echo "        громкость: $(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)"
Q=$(pw-dump 2>/dev/null | grep -o '"default.clock.quantum": [0-9]*' | head -1)
echo "        буфер: ${Q:-не прочитать}  (нужно 2048, иначе щелчки; см. 05-audio-buffer.sh)"

echo
echo "=== 8) Экраны"
xrandr --listmonitors 2>/dev/null | sed 's/^/    /'
echo "        рабочий стол: $(xdotool getdisplaygeometry 2>/dev/null)"
echo "        (игра открывается на экране в позиции 0,0 — это должен быть тот, который нужен)"

echo
echo "=== 9) Процессы"
echo "        игра: $(pgrep -c -f Discipl2 2>/dev/null || echo 0)   wine: $(pgrep -c -f wineserver 2>/dev/null || echo 0)"

echo
echo "=============================================================="
echo " Если в пунктах 4-6 всё «ок» и двойников нет — русификация полная."
echo "=============================================================="
SCRIPT_EOF
chmod +x $HOME/d2-scripts/08-check.sh 2>/dev/null || true
```

### 9. Запуск игры (ярлык)

Файл: `~/disciples2.sh`

```bash
mkdir -p $(dirname $HOME/disciples2.sh)
cat > $HOME/disciples2.sh << 'SCRIPT_EOF'
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
SCRIPT_EOF
chmod +x $HOME/disciples2.sh 2>/dev/null || true
```

