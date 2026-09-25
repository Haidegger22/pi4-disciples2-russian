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
