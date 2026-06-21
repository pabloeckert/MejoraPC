#!/usr/bin/env python3
"""MejoraPC — monitor/monitor.py
Monitoreo de fondo COMPLETAMENTE INVISIBLE.
Usar pythonw.exe. Cero output a consola, todo a data/monitor.log.

Toma un sample cada 15 min -> SQLite data/mejorapc.db (usage_samples).
Si ram_pct > 85 -> ram_alerts.
Retención: borra registros > 30 días al arrancar.

Args:
  --install    crea scheduled task con pythonw.exe -WindowStyle Hidden cada 15min
  --uninstall  elimina la scheduled task
  --run        toma un sample ahora (testing manual, puede mostrar output)
"""
import json
import os
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
os.makedirs(DATA, exist_ok=True)
DB = os.path.join(DATA, "mejorapc.db")
LOG = os.path.join(DATA, "monitor.log")
STATUS = os.path.join(DATA, "status.json")
TASK_NAME = "MejoraPC-Monitor"


def log(msg):
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now().isoformat()}  [monitor] {msg}\n")
    except Exception:
        pass


def _connect():
    con = sqlite3.connect(DB)
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS usage_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT, cpu_pct REAL, ram_pct REAL, swap_pct REAL, top_processes TEXT
        );
        CREATE TABLE IF NOT EXISTS ram_alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT, top5_processes TEXT
        );
        """
    )
    return con


def purge_old(con):
    cutoff = (datetime.now() - timedelta(days=30)).isoformat()
    con.execute("DELETE FROM usage_samples WHERE timestamp < ?", (cutoff,))
    con.execute("DELETE FROM ram_alerts WHERE timestamp < ?", (cutoff,))
    con.commit()


def sample(verbose=False):
    try:
        import psutil
    except ImportError:
        subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "psutil"])
        import psutil

    now = datetime.now()
    cpu = psutil.cpu_percent(interval=1)
    vm = psutil.virtual_memory()
    sw = psutil.swap_memory()

    procs = []
    for p in psutil.process_iter(["name", "memory_info"]):
        try:
            procs.append((p.info["name"] or "?", p.info["memory_info"].rss))
        except (psutil.NoSuchProcess, psutil.AccessDenied, AttributeError):
            continue
    procs.sort(key=lambda x: x[1], reverse=True)
    top = [{"name": n, "rss_mb": round(r / 1024**2)} for n, r in procs[:10]]

    con = _connect()
    purge_old(con)
    con.execute(
        "INSERT INTO usage_samples (timestamp, cpu_pct, ram_pct, swap_pct, top_processes) VALUES (?,?,?,?,?)",
        (now.isoformat(), cpu, vm.percent, sw.percent, json.dumps(top)),
    )
    if vm.percent > 85:
        con.execute(
            "INSERT INTO ram_alerts (timestamp, top5_processes) VALUES (?,?)",
            (now.isoformat(), json.dumps(top[:5])),
        )
        log(f"RAM ALERT {vm.percent:.0f}%")
    con.commit()
    con.close()

    # actualizar status.json liviano
    try:
        with open(STATUS, "w", encoding="utf-8") as f:
            json.dump({
                "timestamp": now.isoformat(),
                "ram_free_gb": round(vm.available / 1024**3, 2),
                "ram_total_gb": round(vm.total / 1024**3, 2),
                "ram_pct": vm.percent,
                "last_scan": now.strftime("%Y-%m-%d %H:%M"),
            }, f, indent=2)
    except Exception:
        pass

    log(f"sample cpu={cpu:.0f}% ram={vm.percent:.0f}% swap={sw.percent:.0f}%")
    if verbose:
        print(f"cpu={cpu:.0f}% ram={vm.percent:.0f}% swap={sw.percent:.0f}%")
        print(f"top: {', '.join(p['name'] for p in top[:5])}")


def _pythonw():
    """Ruta a pythonw.exe (ejecutable invisible) junto al python actual."""
    cand = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")
    return cand if os.path.exists(cand) else sys.executable


def install():
    pyw = _pythonw()
    script = os.path.abspath(__file__)
    # schtasks: trigger cada 15 min, sin ventana. pythonw ya es invisible.
    cmd = [
        "schtasks", "/Create", "/F", "/TN", TASK_NAME,
        "/SC", "MINUTE", "/MO", "15",
        "/TR", f'"{pyw}" "{script}" --run',
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
    arg = sys.argv[1] if len(sys.argv) > 1 else "--run"
    if arg == "--install":
        install()
    elif arg == "--uninstall":
        uninstall()
    else:
        # --run (manual, verbose) o invocación de la task (silenciosa)
        sample(verbose=("--run" in sys.argv and sys.stdout is not None and sys.stdout.isatty()))
