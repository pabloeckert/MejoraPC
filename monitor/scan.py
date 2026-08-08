#!/usr/bin/env python3
"""MejoraPC — monitor/scan.py
Escaneo de hardware MANUAL (muestra output en consola).
Auto-instala dependencias si faltan. Guarda en data/mejorapc.db (hardware_profile)
y en data/status.json (para el banner de run.ps1).

Perfil definitivo Pablo: 8GB RAM crítico, dev full-stack.
"""
import json
import os
import sqlite3
import subprocess
import sys
from datetime import datetime

# Salida UTF-8 robusta (consola legacy cp1252 rompe box-drawing/emojis)
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

# ── Auto-instalar dependencias ─────────────────────────────────────
def _ensure(pkgs):
    for mod, pip_name in pkgs:
        try:
            __import__(mod)
        except ImportError:
            subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", pip_name])

_ensure([("psutil", "psutil"), ("rich", "rich")])

import psutil  # noqa: E402
from rich.console import Console  # noqa: E402
from rich.table import Table  # noqa: E402
from rich.panel import Panel  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
os.makedirs(DATA, exist_ok=True)
DB = os.path.join(DATA, "mejorapc.db")
STATUS = os.path.join(DATA, "status.json")

console = Console()


def init_db():
    con = sqlite3.connect(DB)
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS hardware_profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT, ram_total_gb REAL, ram_free_gb REAL,
            cpu_model TEXT, score INTEGER, profile_json TEXT
        );
        CREATE TABLE IF NOT EXISTS usage_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT, cpu_pct REAL, ram_pct REAL, swap_pct REAL,
            top_processes TEXT
        );
        CREATE TABLE IF NOT EXISTS ram_alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT, top5_processes TEXT
        );
        CREATE TABLE IF NOT EXISTS smart_recommendations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT, priority TEXT, title TEXT, description TEXT,
            module TEXT, applied INTEGER DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS applied_actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT, action TEXT, detail TEXT
        );
        """
    )
    con.commit()
    return con


def get_disks():
    disks = []
    for part in psutil.disk_partitions(all=False):
        try:
            u = psutil.disk_usage(part.mountpoint)
            disks.append({
                "device": part.device,
                "mount": part.mountpoint,
                "fstype": part.fstype,
                "total_gb": round(u.total / 1024**3, 1),
                "used_gb": round(u.used / 1024**3, 1),
                "free_gb": round(u.free / 1024**3, 1),
                "used_pct": u.percent,
            })
        except (PermissionError, OSError):
            continue
    return disks


def get_gpu():
    gpus = []
    try:
        out = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "Get-CimInstance Win32_VideoController | "
             "Select-Object Name,@{n='VRAM';e={$_.AdapterRAM}},DriverVersion | ConvertTo-Json"],
            capture_output=True, text=True, timeout=20,
        ).stdout
        data = json.loads(out) if out.strip() else []
        if isinstance(data, dict):
            data = [data]
        for g in data:
            gpus.append({
                "model": g.get("Name"),
                "vram_gb": round((g.get("VRAM") or 0) / 1024**3, 1),
                "driver": g.get("DriverVersion"),
            })
    except Exception:
        pass
    return gpus


def compute_score(ram_total_gb, cores, disks):
    score = 100
    if ram_total_gb < 4:
        score -= 30
    elif ram_total_gb < 8:
        score -= 15
    elif ram_total_gb < 16:
        score -= 5
    if cores < 2:
        score -= 20
    elif cores < 4:
        score -= 10
    return max(0, min(100, score))


def main():
    con = init_db()
    now = datetime.now()

    vm = psutil.virtual_memory()
    sw = psutil.swap_memory()
    ram_total = vm.total / 1024**3
    ram_free = vm.available / 1024**3
    cpu_freq = psutil.cpu_freq()
    cores_phys = psutil.cpu_count(logical=False) or 0
    cores_log = psutil.cpu_count(logical=True) or 0
    cpu_pct = psutil.cpu_percent(interval=1)

    cpu_model = ""
    try:
        cpu_model = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "(Get-CimInstance Win32_Processor).Name"],
            capture_output=True, text=True, timeout=15,
        ).stdout.strip()
    except Exception:
        cpu_model = "Desconocido"

    disks = get_disks()
    gpus = get_gpu()
    score = compute_score(ram_total, cores_phys, disks)

    # Top 10 procesos por RAM
    procs = []
    for p in psutil.process_iter(["name", "memory_info"]):
        try:
            procs.append((p.info["name"] or "?", p.info["memory_info"].rss))
        except (psutil.NoSuchProcess, psutil.AccessDenied, AttributeError):
            continue
    procs.sort(key=lambda x: x[1], reverse=True)
    top10 = procs[:10]

    # ── Render ──
    console.print()
    console.print(Panel.fit("[bold cyan]MejoraPC — Escaneo de Hardware[/]", border_style="cyan"))

    score_color = "green" if score >= 70 else "yellow" if score >= 40 else "red"
    t = Table(show_header=False, box=None)
    t.add_row("CPU", f"{cpu_model}")
    t.add_row("Núcleos", f"{cores_phys} físicos / {cores_log} lógicos")
    t.add_row("Frecuencia", f"{cpu_freq.current:.0f} MHz" if cpu_freq else "?")
    t.add_row("Uso CPU", f"{cpu_pct:.0f}%")
    t.add_row("RAM total", f"{ram_total:.1f} GB")
    ram_color = "red" if ram_free < 2 else "yellow" if ram_free < 3 else "green"
    t.add_row("RAM libre", f"[{ram_color}]{ram_free:.2f} GB[/]")
    t.add_row("Swap", f"{sw.percent:.0f}%")
    t.add_row("Score", f"[{score_color}]{score}/100[/]")
    console.print(t)

    if gpus:
        gt = Table(title="GPU", title_style="cyan")
        gt.add_column("Modelo"); gt.add_column("VRAM"); gt.add_column("Driver")
        for g in gpus:
            gt.add_row(str(g["model"]), f"{g['vram_gb']} GB", str(g["driver"]))
        console.print(gt)

    dt = Table(title="Discos", title_style="cyan")
    dt.add_column("Unidad"); dt.add_column("Total"); dt.add_column("Usado"); dt.add_column("Libre"); dt.add_column("%")
    for d in disks:
        dt.add_row(d["mount"], f"{d['total_gb']}G", f"{d['used_gb']}G", f"{d['free_gb']}G", f"{d['used_pct']}%")
    console.print(dt)

    pt = Table(title="Top 10 procesos por RAM", title_style="cyan")
    pt.add_column("Proceso"); pt.add_column("RAM", justify="right")
    for name, rss in top10:
        pt.add_row(name, f"{rss/1024**2:.0f} MB")
    console.print(pt)

    # ── Alertas específicas del perfil ──
    alerts = []
    if ram_free < 2:
        alerts.append(("red", f"RAM libre {ram_free:.2f}GB < 2GB — CRÍTICO"))
    elif ram_free < 3:
        alerts.append(("yellow", f"RAM libre {ram_free:.2f}GB < 3GB — ADVERTENCIA"))

    names = {n.lower() for n, _ in procs}
    if any("ollama" in n for n in names):
        alerts.append(("yellow", "ollama.exe corriendo — Residuo, ejecutá módulo 02"))
    if any("bluestacks" in n or "ldplayer" in n or "dnplayer" in n for n in names):
        alerts.append(("yellow", "Emulador activo — ejecutá módulo 02"))
    browsers = {"chrome", "brave", "msedge", "opera", "vivaldi"}
    active_browsers = {b for b in browsers if any(b in n for n in names)}
    if len(active_browsers) > 3:
        alerts.append(("yellow", f"{len(active_browsers)} browsers activos: {', '.join(active_browsers)}"))
    py_versions = [n for n in names if n.startswith("python")]
    if len(set(py_versions)) > 1:
        alerts.append(("yellow", "Más de una versión Python activa — ejecutá módulo 10"))

    if alerts:
        console.print()
        for color, msg in alerts:
            console.print(f"  [{color}]![/] {msg}")

    # ── Tabla RAM recuperable ── data/tweaks.json es la fuente de verdad
    # (no hardcodear acá — si se agrega un tweak nuevo, este bloque tiene
    # que reflejarlo solo, para no repetir el desfasaje que tenía esta lista).
    console.print()
    console.print("[bold]═══ RAM POTENCIALMENTE RECUPERABLE ═══[/]")
    labels = {
        "game_bar_off": "Game Bar off",
        "browsers_background_off": "Browsers background off",
        "animaciones_off": "Animaciones off",
        "corel_helper_off": "CorelDRAW helper off",
        "superfetch_off": "Superfetch off",
        "roblox_autostart_off": "Roblox autostart off",
        "chrome_autolaunch_off": "Chrome autolaunch off",
        "canva_autolaunch_off": "Canva autolaunch off",
    }
    try:
        with open(os.path.join(DATA, "tweaks.json"), "r", encoding="utf-8") as f:
            estimate = json.load(f).get("ram_recoverable_estimate", {})
        for key, label in labels.items():
            if key in estimate:
                console.print(f"  {label + ':':<26} ~{estimate[key]}MB")
        if "total_mb" in estimate:
            console.print(f"  [bold]TOTAL ESTIMADO: ~{estimate['total_mb']}MB[/]")
    except Exception:
        pass

    # ── Persistir ──
    profile = {
        "timestamp": now.isoformat(),
        "cpu": {"model": cpu_model, "cores_phys": cores_phys, "cores_log": cores_log,
                "freq_mhz": round(cpu_freq.current) if cpu_freq else None, "usage_pct": cpu_pct},
        "ram": {"total_gb": round(ram_total, 2), "free_gb": round(ram_free, 2), "swap_pct": sw.percent},
        "gpu": gpus, "storage": disks,
        "top10": [{"name": n, "rss_mb": round(r / 1024**2)} for n, r in top10],
        "alerts": [m for _, m in alerts], "score": score,
    }
    con.execute(
        "INSERT INTO hardware_profile (timestamp, ram_total_gb, ram_free_gb, cpu_model, score, profile_json) "
        "VALUES (?,?,?,?,?,?)",
        (now.isoformat(), round(ram_total, 2), round(ram_free, 2), cpu_model, score, json.dumps(profile)),
    )
    con.commit()
    con.close()

    with open(STATUS, "w", encoding="utf-8") as f:
        json.dump({
            "timestamp": now.isoformat(),
            "ram_free_gb": round(ram_free, 2),
            "ram_total_gb": round(ram_total, 2),
            "score": score,
            "last_scan": now.strftime("%Y-%m-%d %H:%M"),
        }, f, indent=2)

    console.print(f"\n  [dim]Guardado en {DB} y {STATUS}[/]\n")


if __name__ == "__main__":
    main()
