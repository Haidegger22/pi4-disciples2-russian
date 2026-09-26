#!/usr/bin/env python3
# build-install.py — дописывает в INSTALL.md раздел с полным кодом всех файлов.
# Запускать ПОСЛЕ правок текстовой части INSTALL.md (он добавляет блоки в конец).
import io, os, sys

D = os.path.dirname(os.path.abspath(__file__))

def rd(p):
    return io.open(p, encoding="utf-8").read()

def blk(src, dst):
    body = rd(src)
    if not body.endswith("\n"):
        body += "\n"
    return ("```bash\nmkdir -p $(dirname %s)\ncat > %s << 'SCRIPT_EOF'\n%s"
            "SCRIPT_EOF\nchmod +x %s 2>/dev/null || true\n```\n\n"
            % (dst, dst, body, dst))

ITEMS = [
    ("01-install-hangover.sh", "Wine под arm64 (Hangover)", "$HOME/d2-scripts/01-install-hangover.sh"),
    ("02-install-game.sh",     "Данные игры из установщика GOG", "$HOME/d2-scripts/02-install-game.sh"),
    ("03-install-mod.sh",      "Мод против розовых текстур", "$HOME/d2-scripts/03-install-mod.sh"),
    ("04-russianize.sh",       "Русификация (текст, озвучка, ролики)", "$HOME/d2-scripts/04-russianize.sh"),
    ("05-audio-buffer.sh",     "Звуковой буфер (убирает щелчки)", "$HOME/d2-scripts/05-audio-buffer.sh"),
    ("06-screens.sh",          "Два экрана: телевизор слева, панель справа", "$HOME/d2-scripts/06-screens.sh"),
    ("07-ru-case-fix.py",      "Поиск и удаление двойников имён (регистр)", "$HOME/d2-scripts/07-ru-case-fix.py"),
    ("08-check.sh",            "Проверка установки", "$HOME/d2-scripts/08-check.sh"),
    ("09-game-speed.sh",       "Скорость боя и карты", "$HOME/d2-scripts/09-game-speed.sh"),
    ("10-audio.sh",            "Звук: громкость и выбор выхода", "$HOME/d2-scripts/10-audio.sh"),
    ("disciples2.sh",          "Запуск игры (ярлык)", "$HOME/disciples2.sh"),
]

h = rd(os.path.join(D, "INSTALL.md"))
marker = "## Полный код файлов (установка без git)"
if marker in h:
    h = h.split(marker)[0].rstrip() + "\n"

h += "\n---\n\n" + marker + "\n\n"
h += ("Ниже — полное содержимое каждого файла. Если `git clone` недоступен, вставляйте эти блоки\n"
      "в терминал по порядку: каждый создаёт файл и делает его исполняемым.\n\n")

for i, (name, title, dst) in enumerate(ITEMS, 1):
    src = os.path.join(D, "scripts", name)
    if not os.path.exists(src):
        print("НЕТ ФАЙЛА: " + src, file=sys.stderr)
        continue
    h += "### %d. %s\n\n" % (i, title)
    h += "Файл: `%s`\n\n" % dst.replace("$HOME", "~")
    h += blk(src, dst)

io.open(os.path.join(D, "INSTALL.md"), "w", encoding="utf-8").write(h)
print("INSTALL.md: строк %d, блоков SCRIPT_EOF %d" % (h.count("\n"), h.count("SCRIPT_EOF")))
