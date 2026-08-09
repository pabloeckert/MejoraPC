#!/usr/bin/env python3
"""MejoraPC — monitor/auto_adjust.py
Promueve recomendaciones ya validadas de smart_recommendations a
data/profile-local.json. NUNCA ejecuta un cambio directamente — solo
escribe una entrada nueva en startup_disable. En la corrida SIGUIENTE,
modules/03-performance.ps1 la aplica con su mecanismo normal (buscar,
confirmar, remover, releer) — este script nunca toca el registro.

Solo actúa si data/profile-local.json ya existe en esta máquina (autonomía
total ya aceptada — misma decisión que incluir Bloque B en el pipeline
automático). Sin ese archivo, no hay autonomía para escribir tweaks nuevos:
mismo principio de seguridad que el resto del sistema.

Alcance acotado: solo promueve auto_action.type == "startup_disable_candidate"
(procesos no-dev consistentes CON una entrada de autoarranque detectable vía
registro). Si no hay entrada de autoarranque real, no se promueve nada —
nunca actúa sobre software no reconocido ni inventa acciones.
"""
import json
import os
import re
import sqlite3
import sys
from datetime import datetime

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

try:
    import winreg
except ImportError:
    winreg = None

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
DB = os.path.join(DATA, "mejorapc.db")
PROFILE_LOCAL = os.path.join(DATA, "profile-local.json")

sys.path.insert(0, HERE)
import record_run  # noqa: E402


def _find_run_key_value(process_name):
    """Busca una entrada en HKCU/HKLM Run cuyo nombre o valor contenga el
    proceso (sin .exe). Devuelve el nombre exacto del value, o None."""
    if not winreg:
        return None
    needle = process_name.lower().replace(".exe", "")
    for hive in (winreg.HKEY_CURRENT_USER, winreg.HKEY_LOCAL_MACHINE):
        try:
            with winreg.OpenKey(hive, r"Software\Microsoft\Windows\CurrentVersion\Run") as key:
                i = 0
                while True:
                    try:
                        name, value, _ = winreg.EnumValue(key, i)
                    except OSError:
                        break
                    if needle in name.lower() or needle in str(value).lower():
                        return name
                    i += 1
        except OSError:
            continue
    return None


def run():
    if not os.path.exists(PROFILE_LOCAL):
        print("Auto-ajuste: sin profile-local.json en esta máquina — sin autonomía para escribir tweaks nuevos.")
        return
    if not os.path.exists(DB):
        return

    con = sqlite3.connect(DB)
    try:
        rows = con.execute(
            "SELECT module, auto_action FROM smart_recommendations "
            "WHERE applied = 0 AND auto_action IS NOT NULL"
        ).fetchall()
    except sqlite3.OperationalError:
        rows = []
    con.close()

    if not rows:
        print("Auto-ajuste: sin recomendaciones con auto_action pendientes.")
        return

    with open(PROFILE_LOCAL, "r", encoding="utf-8") as f:
        profile = json.load(f)
    profile.setdefault("startup_disable", {})

    added = []
    for _module, auto_action_raw in rows:
        try:
            action = json.loads(auto_action_raw)
        except (TypeError, ValueError):
            continue
        if action.get("type") != "startup_disable_candidate":
            continue
        for proc in action.get("processes", []):
            key_name = "auto_" + re.sub(r"[^a-z0-9]+", "_", proc.lower().replace(".exe", "")).strip("_")
            if key_name in profile["startup_disable"]:
                continue  # ya promovido en una corrida anterior
            run_key_name = _find_run_key_value(proc)
            if not run_key_name:
                continue  # sin autoarranque detectable — no se promueve nada
            profile["startup_disable"][key_name] = {
                "_desc": f"Auto-aprendido: {proc} consume RAM seguido en samples del monitor y tiene autoarranque detectado.",
                "run_keys": [
                    "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run",
                    "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
                ],
                "match": re.escape(run_key_name),
                "ram_estimate_mb": 0,
            }
            added.append(proc)

    if added:
        if "_meta" in profile:
            profile["_meta"]["updated"] = datetime.now().strftime("%Y-%m-%d")
        with open(PROFILE_LOCAL, "w", encoding="utf-8") as f:
            json.dump(profile, f, indent=2, ensure_ascii=False)
        detail = f"{len(added)} candidato(s) promovido(s) a startup_disable: {', '.join(added)}"
        print(f"Auto-ajuste: {detail}")
        record_run.record(action="auto-adjust", detail=detail)
    else:
        print("Auto-ajuste: sin candidatos nuevos con autoarranque detectable.")


if __name__ == "__main__":
    run()
