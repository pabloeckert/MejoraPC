#!/usr/bin/env python3
"""MejoraPC — monitor/report.py
Dashboard MANUAL en consola (rich). Muestra:
  1. Hardware summary con semáforo
  2. Gráfico de barras ASCII RAM últimas 24hs por hora
  3. Top 5 procesos consumidores de la semana
  4. Recomendaciones pendientes
  5. Score salud 0-100
  6. Historial de optimizaciones aplicadas
"""
import json
import os
import sqlite3
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
except ImportError:
    import subprocess
    import sys
    subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "rich"])
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
DB = os.path.join(DATA, "mejorapc.db")
LOGS = os.path.join(HERE, "..", "logs")
REPORT_FILE = os.path.join(LOGS, "ultimo-informe.txt")
console = Console(record=True)


def main():
    if not os.path.exists(DB):
        console.print("\n  [yellow]No hay datos. Ejecutá el Escaneo de hardware (opción 7) primero.[/]\n")
        return

    con = sqlite3.connect(DB)

    # ── 1 + 5. Hardware summary + score (con delta antes/después) ──
    hw_rows = con.execute(
        "SELECT timestamp, ram_total_gb, ram_free_gb, cpu_model, score, profile_json "
        "FROM hardware_profile ORDER BY id DESC LIMIT 2"
    ).fetchall()
    hw = hw_rows[0] if hw_rows else None

    console.print()
    console.print(Panel.fit("[bold cyan]MejoraPC — Dashboard[/]", border_style="cyan"))

    if hw:
        ts, total, free, cpu, score, pj = hw
        sc_color = "green" if score >= 70 else "yellow" if score >= 40 else "red"
        ram_color = "red" if free < 2 else "yellow" if free < 3 else "green"
        t = Table(show_header=False, box=None)
        t.add_row("CPU", str(cpu))
        ram_line = f"[{ram_color}]{free:.2f} GB libres[/] / {total:.1f} GB"
        if len(hw_rows) > 1:
            delta = free - hw_rows[1][2]
            if abs(delta) >= 0.05:
                d_color = "green" if delta > 0 else "red"
                d_sign = "+" if delta > 0 else ""
                ram_line += f"  [{d_color}]({d_sign}{delta:.2f} GB)[/]"
        t.add_row("RAM", ram_line)
        t.add_row("Score salud", f"[{sc_color}]{score}/100[/]")
        t.add_row("Último scan", ts[:16].replace("T", " "))
        console.print(t)

        if free < 2.5:
            console.print(
                f"\n  [bold red]⚠ MEMORIA CRÍTICA[/] — {free:.2f} GB libres. "
                f"Correr [bold]run.ps1[/] o [bold].\\modules\\12-workflow-optimizer.ps1[/] "
                f"(sesión dev) para liberar RAM."
            )

    # ── Última verificación real (13-verify.ps1) ──
    verify_path = os.path.join(DATA, "last-verify.json")
    if os.path.exists(verify_path):
        try:
            with open(verify_path, "r", encoding="utf-8") as f:
                v = json.load(f)
            vt = str(v.get("timestamp", ""))[:16].replace("T", " ")
            console.print(
                f"\n[bold]Última verificación real[/] ({vt}): "
                f"[green]{v.get('verificado', 0)} verificado[/] · "
                f"[yellow]{v.get('pendiente', 0)} pendiente[/] · "
                f"[red]{v.get('fallido', 0)} fallido[/]"
            )
        except Exception:
            pass

    # ── 2. Gráfico RAM últimas 24hs por hora ──
    cutoff = (datetime.now() - timedelta(hours=24)).isoformat()
    rows = con.execute(
        "SELECT timestamp, ram_pct FROM usage_samples WHERE timestamp >= ? ORDER BY timestamp",
        (cutoff,),
    ).fetchall()
    if rows:
        by_hour = defaultdict(list)
        for ts, ram in rows:
            by_hour[datetime.fromisoformat(ts).hour].append(ram)
        console.print("\n[bold]RAM % por hora (últimas 24h)[/]")
        for h in sorted(by_hour):
            avg = sum(by_hour[h]) / len(by_hour[h])
            filled = int(avg / 100 * 30)
            color = "red" if avg >= 85 else "yellow" if avg >= 60 else "green"
            bar = "█" * filled + "░" * (30 - filled)
            console.print(f"  {h:02d}h [{color}]{bar}[/] {avg:.0f}%")
    else:
        console.print("\n  [dim]Sin samples de uso aún (instalá el monitor, opción 12).[/]")

    # ── 3. Top 5 procesos de la semana ──
    wk = (datetime.now() - timedelta(days=7)).isoformat()
    proc_rows = con.execute(
        "SELECT top_processes FROM usage_samples WHERE timestamp >= ?", (wk,)
    ).fetchall()
    if proc_rows:
        counter = Counter()
        for (tj,) in proc_rows:
            for p in json.loads(tj or "[]"):
                counter[p["name"]] += p.get("rss_mb", 0)
        pt = Table(title="\nTop 5 procesos (RAM acumulada, semana)", title_style="cyan")
        pt.add_column("Proceso"); pt.add_column("RAM acum.", justify="right")
        for name, total_mb in counter.most_common(5):
            pt.add_row(name, f"{total_mb} MB")
        console.print(pt)

    # ── 4. Recomendaciones pendientes ──
    try:
        recs = con.execute(
            "SELECT priority, title, description, module FROM smart_recommendations WHERE applied = 0"
        ).fetchall()
    except sqlite3.OperationalError:
        recs = []
    if recs:
        console.print("\n[bold]Recomendaciones pendientes[/]")
        for pr, title, desc, mod in recs:
            color = {"Alta": "red", "Media": "yellow"}.get(pr, "green")
            console.print(f"  [{color}][{pr}][/] {title} (módulo {mod})")
            console.print(f"        [dim]{desc}[/]")
    else:
        console.print("\n  [green]Sin recomendaciones pendientes.[/]")

    # ── 6. Historial de optimizaciones ──
    try:
        acts = con.execute(
            "SELECT timestamp, action, detail FROM applied_actions ORDER BY id DESC LIMIT 10"
        ).fetchall()
    except sqlite3.OperationalError:
        acts = []
    if acts:
        at = Table(title="\nHistorial de optimizaciones", title_style="cyan")
        at.add_column("Fecha"); at.add_column("Acción"); at.add_column("Detalle")
        for ts, action, detail in acts:
            at.add_row(ts[:16].replace("T", " "), action, detail or "")
        console.print(at)

    con.close()
    console.print()

    os.makedirs(LOGS, exist_ok=True)
    console.save_text(REPORT_FILE)
    console.print(f"  [dim]Informe guardado en: {REPORT_FILE}[/]")


if __name__ == "__main__":
    main()
