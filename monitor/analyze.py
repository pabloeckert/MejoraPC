#!/usr/bin/env python3
"""MejoraPC — monitor/analyze.py
Análisis semanal COMPLETAMENTE INVISIBLE (scheduled task domingos 3AM).
Usar pythonw.exe. Cero output, todo a data/monitor.log.

Lee 7 días de usage_samples y genera smart_recommendations:
  - Hora pico de RAM por hora del día
  - Procesos top5 consistentes que NO son dev tools -> candidatos
  - ram_alerts > 3/día -> recomendar módulo 12

Args:
  --install    crea scheduled task semanal (domingos 3AM) con pythonw.exe
  --uninstall  elimina la scheduled task
  --run        ejecuta ahora con output visible (testing manual)
"""
import json
import os
import sqlite3
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
DB = os.path.join(DATA, "mejorapc.db")
LOG = os.path.join(DATA, "monitor.log")
TASK_NAME = "MejoraPC-Analyze"

DEV_TOOLS = {"code", "node", "python", "pythonw", "chrome", "brave", "msedge",
             "git", "bash", "powershell", "windowsterminal", "explorer", "claude"}


def log(msg):
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now().isoformat()}  [analyze] {msg}\n")
    except Exception:
        pass


def is_dev(name):
    n = name.lower().replace(".exe", "")
    return any(d in n for d in DEV_TOOLS)


def analyze(verbose=False):
    if not os.path.exists(DB):
        log("DB no existe, nada que analizar")
        if verbose:
            print("No hay base de datos. Instalá el monitor (opción 12) primero.")
        return

    con = sqlite3.connect(DB)
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS smart_recommendations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT, priority TEXT, title TEXT, description TEXT,
            module TEXT, applied INTEGER DEFAULT 0
        );
        """
    )
    cutoff = (datetime.now() - timedelta(days=7)).isoformat()
    rows = con.execute(
        "SELECT timestamp, ram_pct, top_processes FROM usage_samples WHERE timestamp >= ?",
        (cutoff,),
    ).fetchall()

    if not rows:
        log("sin samples en 7 días")
        if verbose:
            print("Sin datos suficientes (esperá a que el monitor junte samples).")
        con.close()
        return

    # Hora pico de RAM
    by_hour = defaultdict(list)
    proc_counter = Counter()
    for ts, ram, top_json in rows:
        try:
            hour = datetime.fromisoformat(ts).hour
            by_hour[hour].append(ram)
            for p in json.loads(top_json or "[]"):
                if not is_dev(p["name"]):
                    proc_counter[p["name"]] += 1
        except Exception:
            continue

    peak_hour = max(by_hour, key=lambda h: sum(by_hour[h]) / len(by_hour[h])) if by_hour else None
    peak_avg = (sum(by_hour[peak_hour]) / len(by_hour[peak_hour])) if peak_hour is not None else 0

    # ram_alerts por día
    alert_rows = con.execute(
        "SELECT timestamp FROM ram_alerts WHERE timestamp >= ?", (cutoff,)
    ).fetchall()
    alerts_per_day = defaultdict(int)
    for (ts,) in alert_rows:
        alerts_per_day[ts[:10]] += 1
    avg_alerts = (sum(alerts_per_day.values()) / max(1, len(alerts_per_day))) if alerts_per_day else 0

    # ── Generar recomendaciones ──
    now = datetime.now().isoformat()
    con.execute("DELETE FROM smart_recommendations WHERE applied = 0")
    recs = []

    if peak_hour is not None:
        recs.append(("Baja", f"Hora pico de RAM: {peak_hour:02d}:00",
                     f"Promedio {peak_avg:.0f}% de RAM a las {peak_hour:02d}h. "
                     f"Evitá tareas pesadas en esa franja.", "08"))

    top_candidates = [n for n, c in proc_counter.most_common(5) if c >= len(rows) * 0.3]
    if top_candidates:
        recs.append(("Media", "Procesos no-dev consistentes",
                     f"Consumen RAM seguido: {', '.join(top_candidates)}. "
                     f"Revisá si los necesitás (módulo 02 debloat).", "02"))

    if avg_alerts > 3:
        recs.append(("Alta", "Alertas de RAM frecuentes",
                     f"{avg_alerts:.1f} alertas/día de RAM >85%. "
                     f"Corré el Workflow Optimizer antes de trabajar (módulo 12).", "12"))

    for pr, title, desc, mod in recs:
        con.execute(
            "INSERT INTO smart_recommendations (timestamp, priority, title, description, module, applied) "
            "VALUES (?,?,?,?,?,0)",
            (now, pr, title, desc, mod),
        )
    con.commit()
    con.close()

    log(f"analyze ok: {len(recs)} recomendaciones, peak_hour={peak_hour}, avg_alerts={avg_alerts:.1f}")
    if verbose:
        print(f"\nAnálisis completo — {len(recs)} recomendación(es):\n")
        for pr, title, desc, mod in recs:
            print(f"  [{pr}] {title} (módulo {mod})")
            print(f"        {desc}\n")


def _pythonw():
    cand = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")
    return cand if os.path.exists(cand) else sys.executable


def install():
    pyw = _pythonw()
    script = os.path.abspath(__file__)
    cmd = [
        "schtasks", "/Create", "/F", "/TN", TASK_NAME,
        "/SC", "WEEKLY", "/D", "SUN", "/ST", "03:00",
        "/TR", f'"{pyw}" "{script}"',
        "/RL", "LIMITED",
    ]
    r = subprocess.run(cmd, capture_output=True, text=True)
    print(r.stdout or r.stderr)
    log(f"install -> {r.returncode}")


def uninstall():
    r = subprocess.run(["schtasks", "/Delete", "/F", "/TN", TASK_NAME], capture_output=True, text=True)
    print(r.stdout or r.stderr)
    log(f"uninstall -> {r.returncode}")


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    if arg == "--install":
        install()
    elif arg == "--uninstall":
        uninstall()
    elif arg == "--run":
        analyze(verbose=True)
    else:
        analyze(verbose=False)
