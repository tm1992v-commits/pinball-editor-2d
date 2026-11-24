#!/usr/bin/env python3
"""Builds the ready-to-use Pinball Editor 2D packages for WINDOWS and LINUX (for the GitHub release).

Each package = the official Godot 4.7.2 editor binary (MIT licence, downloaded from the official Godot release and
checked against its SHA-512) + this project + a double-click launcher. Inside it everything works as from source:
the editor, GIOCA, exports and the official release (the game export templates are installed from the editor,
📦 ESPORTA → "Installa i modelli di esportazione").

Usage:  python3 tools/pacchetto_editor.py VERSION [OUTPUT_DIR]      (e.g. python3 tools/pacchetto_editor.py 0.26.0)
"""
import hashlib, io, os, shutil, stat, sys, urllib.request, zipfile

GODOT = "4.7.2-stable"
URL = "https://github.com/godotengine/godot/releases/download/%s/" % GODOT
BINARI = {"linux": "Godot_v%s_linux.x86_64.zip" % GODOT, "windows": "Godot_v%s_win64.exe.zip" % GODOT}
QUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))          # repository root
ESCLUSI = {".git", ".godot", "build", "gioco", "progetti", "libreria_elementi", "__pycache__", "dist"}

LANCIO_LINUX = """#!/bin/bash
# Pinball Editor 2D – double-click (or run) to start the editor.
cd "$(dirname "$0")"
[ -d progetto/.godot ] || ./%(b)s --headless --path progetto --import
exec ./%(b)s --path progetto res://editor/editor.tscn "$@"
"""
LANCIO_WINDOWS = """@echo off
rem Pinball Editor 2D - double-click to start the editor.
if not exist "%%~dp0progetto\\.godot" "%%~dp0%(b)s" --headless --path "%%~dp0progetto" --import
start "" "%%~dp0%(b)s" --path "%%~dp0progetto" res://editor/editor.tscn
"""
LEGGIMI = """Pinball Editor 2D %s – ready-to-use package for %s
Created by Carmelo Vadalà · Open Source Community Project · source code: folder "progetto"

START: %s
The first time you export a game: 📦 ESPORTA → "Installa i modelli di esportazione" (download from godotengine.org).
For the official release of a pinball you also need git (and the GitHub CLI "gh" to publish on GitHub).

Inside: Godot Engine %s (MIT licence, unmodified official binary: LICENSES/Godot-MIT.txt) and the editor
(GNU GPL v3 or later: LICENSE). The complete source code of the editor is in the folder "progetto".
"""


def scarica(nome):
    print("download", nome)
    with urllib.request.urlopen(URL + nome) as r:
        return r.read()


def controlla(nome, dati, somme):
    atteso = None
    for riga in somme.splitlines():
        if riga.strip().endswith(nome):
            atteso = riga.split()[0]
    if atteso is None or hashlib.sha512(dati).hexdigest() != atteso:
        raise SystemExit("SHA-512 check failed for " + nome)


def copia_progetto(dest):
    for radice, dirs, files in os.walk(QUI):
        dirs[:] = [d for d in dirs if d not in ESCLUSI and not os.path.join(radice, d).startswith(os.path.join(QUI, "dist"))]
        rel = os.path.relpath(radice, QUI)
        if rel.split(os.sep)[0] in ESCLUSI or rel.startswith("dist"):
            continue
        for f in files:
            d = os.path.join(dest, rel, f)
            os.makedirs(os.path.dirname(d), exist_ok=True)
            shutil.copy2(os.path.join(radice, f), d)


def importa(cartella_progetto, godot_linux):
    """Prepares Godot's import cache (.godot) once, so the editor opens immediately on any system."""
    import subprocess
    subprocess.run([godot_linux, "--headless", "--path", cartella_progetto, "--import"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)


def pacchetto(sistema, versione, uscita, dati_godot, godot_linux=None):
    nome = "PinballEditor2D-%s-%s" % (versione, sistema)
    tmp = os.path.join(uscita, nome)
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    with zipfile.ZipFile(io.BytesIO(dati_godot)) as z:
        z.extractall(tmp)
    binario = [f for f in os.listdir(tmp) if f.startswith("Godot_v") and "console" not in f][0]
    copia_progetto(os.path.join(tmp, "progetto"))
    if godot_linux:
        importa(os.path.join(tmp, "progetto"), godot_linux)
    for f in ("LICENSE", "COPYRIGHT.md", "CREDITS.md"):
        shutil.copy2(os.path.join(QUI, f), os.path.join(tmp, f))
    shutil.copytree(os.path.join(QUI, "LICENSES"), os.path.join(tmp, "LICENSES"))
    if sistema == "linux":
        avvio = "Pinball Editor 2D.sh"
        open(os.path.join(tmp, avvio), "w").write(LANCIO_LINUX % {"b": binario})
        for f in (avvio, binario):
            p = os.path.join(tmp, f)
            os.chmod(p, os.stat(p).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    else:
        avvio = "Pinball Editor 2D.bat"
        open(os.path.join(tmp, avvio), "w", newline="\r\n").write(LANCIO_WINDOWS % {"b": binario})
    open(os.path.join(tmp, "LEGGIMI.txt"), "w").write(LEGGIMI % (versione, sistema, avvio, GODOT))
    archivio = shutil.make_archive(os.path.join(uscita, nome), "zip", uscita, nome)
    shutil.rmtree(tmp)
    print("ok", archivio, "%.0f MB" % (os.path.getsize(archivio) / 1048576))
    return archivio


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    versione = sys.argv[1]
    uscita = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join(QUI, "dist"))
    os.makedirs(uscita, exist_ok=True)
    somme = scarica("SHA512-SUMS.txt").decode()
    dati = {}
    for sistema, file in BINARI.items():
        dati[sistema] = scarica(file)
        controlla(file, dati[sistema], somme)
    # Godot for Linux (to prepare the import cache on the build machine)
    gl = os.path.join(uscita, "_godot_linux")
    shutil.rmtree(gl, ignore_errors=True)
    with zipfile.ZipFile(io.BytesIO(dati["linux"])) as z:
        z.extractall(gl)
    godot_linux = os.path.join(gl, [f for f in os.listdir(gl) if f.startswith("Godot_v")][0])
    os.chmod(godot_linux, os.stat(godot_linux).st_mode | stat.S_IXUSR)
    for sistema in BINARI:
        pacchetto(sistema, versione, uscita, dati[sistema], godot_linux)
    shutil.rmtree(gl, ignore_errors=True)


if __name__ == "__main__":
    main()
