#!/usr/bin/env python3
"""MejoraPC — monitor/analyze.py
Análisis semanal COMPLETAMENTE INVISIBLE (scheduled task domingos 3AM).
Usar pythonw.exe. Cero output, todo a data/monitor.log.

Motor de reglas: cada regla en RULES lee de un contexto compartido (ctx) y
devuelve una lista de Recommendation. Agregar una regla nueva es agregar una
función a la lista, no editar una función monolítica.

Reglas actuales:
  - rule_peak_hour: hora pico de RAM por hora del día
  - rule_non_dev_processes: procesos top consistentes que NO son dev tools
  - rule_ram_alerts: ram_alerts > 3/día -> recomendar módulo 12
  - rule_ram_trend: RAM libre bajando en las últimas 3 corridas de scan.py

auto_action marca recomendaciones que monitor/auto_adjust.py puede promover
automáticamente a data/profile-local.json (solo en máquinas con ese archivo
— autonomía ya aceptada) en vez de esperar acción manual.

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
from collections import Counter, defaultdict, namedtuple
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

Recommendation = namedtuple("Recommendation", "priority title description module auto_action")


def log(msg):
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now().isoformat()}  [analyze] {msg}\n")
    except Exception:
        pass


def is_dev(name):
    n = name.lower().replace(".exe", "")
    return any(d in n for d in DEV_TOOLS)


# ── Reglas ────────────────────────────────────────────────────────
def rule_peak_hour(ctx):
    by_hour = ctx["by_hour"]
    if not by_hour:
        return []
    peak_hour = max(by_hour, key=lambda h: sum(by_hour[h]) / len(by_hour[h]))
    peak_avg = sum(by_hour[peak_hour]) / len(by_hour[peak_hour])
    return [Recommendation(
        "Baja", f"Hora pico de RAM: {peak_hour:02d}:00",
        f"Promedio {peak_avg:.0f}% de RAM a las {peak_hour:02d}h. Evitá tareas pesadas en esa franja.",
        "08", None,
    )]


def rule_non_dev_processes(ctx):
    candidates = [n for n, c in ctx["proc_counter"].most_common(5) if c >= ctx["n_rows"] * 0.3]
    confirmed = ctx.get("confirmed_active", set())
    top_candidates = [n for n in candidates if not any(a in n.lower() for a in confirmed)]
    if not top_candidates:
        return []
    auto_action = json.dumps({"type": "startup_disable_candidate", "processes": top_candidates})
    return [Recommendation(
        "Media", "Procesos no-dev consistentes",
        f"Consumen RAM seguido: {', '.join(top_candidates)}. Revisá si los necesitás (módulo 02 debloat).",
        "02", auto_action,
    )]


def rule_ram_alerts(ctx):
    if ctx["avg_alerts"] <= 3:
        return []
    return [Recommendation(
        "Alta", "Alertas de RAM frecuentes",
        f"{ctx['avg_alerts']:.1f} alertas/día de RAM >85%. Corré el Workflow Optimizer antes de trabajar (módulo 12).",
        "12", None,
    )]


def rule_ram_trend(ctx):
    rows = ctx["con"].execute(
        "SELECT ram_free_gb FROM hardware_profile ORDER BY id DESC LIMIT 3"
    ).fetchall()
    if len(rows) < 3:
        return []
    vals = [r[0] for r in rows]  # vals[0] = más reciente
    if not (vals[0] < vals[1] < vals[2]):
        return []
    return [Recommendation(
        "Media", "Tendencia de RAM a la baja",
        f"RAM libre bajó en las últimas 3 corridas ({vals[2]:.1f} -> {vals[1]:.1f} -> {vals[0]:.1f} GB). "
        f"Revisá qué se está acumulando en el arranque.",
        "03", None,
    )]


RULES = [rule_peak_hour, rule_non_dev_processes, rule_ram_alerts, rule_ram_trend]


def ensure_schema(con):
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS smart_recommendations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT, priority TEXT, title TEXT, description TEXT,
            module TEXT, applied INTEGER DEFAULT 0, auto_action TEXT
        );
        """
    )
    cols = [r[1] for r in con.execute("PRAGMA table_info(smart_recommendations)").fetchall()]
    if "auto_action" not in cols:
        con.execute("ALTER TABLE smart_recommendations ADD COLUMN auto_action TEXT")


def analyze(verbose=False):
    if not os.path.exists(DB):
        log("DB no existe, nada que analizar")
        if verbose:
            print("No hay base de datos. Instalá el monitor (opción 12) primero.")
        return

    con = sqlite3.connect(DB)
    ensure_schema(con)

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

    alert_rows = con.execute(
        "SELECT timestamp FROM ram_alerts WHERE timestamp >= ?", (cutoff,)
    ).fetchall()
    alerts_per_day = defaultdict(int)
    for (ts,) in alert_rows:
        alerts_per_day[ts[:10]] += 1
    avg_alerts = (sum(alerts_per_day.values()) / max(1, len(alerts_per_day))) if alerts_per_day else 0

    confirmed_active = set()
    profile_local_path = os.path.join(DATA, "profile-local.json")
    if os.path.exists(profile_local_path):
        try:
            with open(profile_local_path, "r", encoding="utf-8") as f:
                survey = json.load(f).get("survey", {})
            confirmed_active = {a.lower() for a in survey.get("confirmed_active_apps", [])}
        except Exception:
            pass

    ctx = {
        "con": con,
        "by_hour": by_hour,
        "proc_counter": proc_counter,
        "n_rows": len(rows),
        "avg_alerts": avg_alerts,
        "confirmed_active": confirmed_active,
    }

    now = datetime.now().isoformat()
    con.execute("DELETE FROM smart_recommendations WHERE applied = 0")

    recs = []
    for rule in RULES:
        recs.extend(rule(ctx))

    for r in recs:
        con.execute(
            "INSERT INTO smart_recommendations (timestamp, priority, title, description, module, applied, auto_action) "
            "VALUES (?,?,?,?,?,0,?)",
            (now, r.priority, r.title, r.description, r.module, r.auto_action),
        )
    con.commit()
    con.close()

    log(f"analyze ok: {len(recs)} recomendaciones")
    if verbose:
        print(f"\nAnálisis completo — {len(recs)} recomendación(es):\n")
        for r in recs:
            print(f"  [{r.priority}] {r.title} (módulo {r.module})")
            print(f"        {r.description}\n")


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
