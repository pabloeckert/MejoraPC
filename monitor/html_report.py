#!/usr/bin/env python3
"""MejoraPC — monitor/html_report.py
Genera el dashboard visual (HTML, marca Mejora Continua) del pipeline
automático. Se abre solo en el navegador default al final de
Invoke-AutoOptimize (run.ps1). No depende de monitor/report.py (dashboard
de consola) — datos propios vía dashboard_data.py, cero riesgo de romper
el dashboard existente.
"""
import os
import sys
import webbrowser
from datetime import datetime

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

from dashboard_data import collect  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
LOGS = os.path.join(HERE, "..", "logs")
OUT_PATH = os.path.join(LOGS, "dashboard.html")
CSS_PATH = os.path.join(HERE, "assets", "dashboard.css")


def _esc(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _badge(count, kind, label):
    return f'<span class="badge badge-{kind}">{count}</span> {label}'


def render(data):
    with open(CSS_PATH, "r", encoding="utf-8") as f:
        css = f.read()

    hw = data.get("hardware")
    hw_html = ""
    if hw:
        delta = data.get("ram_delta")
        delta_html = ""
        if delta is not None and abs(delta) >= 0.05:
            sign = "+" if delta > 0 else ""
            cls = "delta-up" if delta > 0 else "delta-down"
            delta_html = f' <span class="{cls}">({sign}{delta} GB)</span>'
        hw_html = f'''
        <div class="card">
          <h2>Estado del equipo</h2>
          <div class="kv"><span>CPU</span><strong>{_esc(hw["cpu_model"])}</strong></div>
          <div class="kv"><span>RAM libre</span><strong>{hw["ram_free_gb"]:.2f} GB / {hw["ram_total_gb"]:.1f} GB{delta_html}</strong></div>
          <div class="kv"><span>Score de salud</span><strong>{hw["score"]}/100</strong></div>
          <div class="kv"><span>Último scan</span><strong>{_esc(hw["timestamp"][:16].replace("T", " "))}</strong></div>
        </div>'''

    verify = data.get("last_verify")
    verify_html = ""
    if verify:
        badges = (
            _badge(verify.get("verificado", 0), "ok", "verificado")
            + " &nbsp; " + _badge(verify.get("pendiente", 0), "pending", "pendiente")
            + " &nbsp; " + _badge(verify.get("fallido", 0), "fail", "fallido")
        )
        verify_html = f'<div class="card"><h2>Última verificación real</h2><div class="badges">{badges}</div></div>'

    discovery = data.get("discovery")
    discovery_html = ""
    if discovery:
        discovery_html = f'''
        <div class="card">
          <h2>Descubrimiento inicial de esta máquina</h2>
          <div class="kv"><span>Software detectado</span><strong>{discovery.get("installed_count", 0)}</strong></div>
          <div class="kv"><span>Coincide con catálogo universal</span><strong>{discovery.get("universal_matches", 0)}</strong></div>
          <div class="kv"><span>No reconocido (se dejó intacto)</span><strong>{discovery.get("unrecognized_count", 0)}</strong></div>
        </div>'''

    restore_point = data.get("restore_point")
    if restore_point:
        restore_msg = f'Se creó un punto de restauración de Windows el <strong>{_esc(restore_point)}</strong>, antes de cualquier cambio.'
    else:
        restore_msg = "No se encontró un punto de restauración reciente en el historial."
    revert_html = f'''
    <div class="card card-accent">
      <h2>Qué se cambió / Cómo revertir</h2>
      <p>{restore_msg}</p>
      <p class="muted">Para revertir: Panel de Control &rarr; Recuperación &rarr; Restaurar sistema, y elegí ese punto.
      También podés correr <code>modules\\05-rescate.ps1</code> para restaurar servicios, registro o el plan de energía puntualmente.</p>
    </div>'''

    recs = data.get("recommendations", [])
    if recs:
        items = "".join(
            f'<li class="rec rec-{r["priority"].lower()}"><strong>[{_esc(r["priority"])}]</strong> {_esc(r["title"])}'
            f'<div class="rec-desc">{_esc(r["description"])}</div></li>'
            for r in recs
        )
        recs_html = f'<div class="card"><h2>Recomendaciones pendientes</h2><ul class="rec-list">{items}</ul></div>'
    else:
        recs_html = '<div class="card"><h2>Recomendaciones pendientes</h2><p class="muted">Sin recomendaciones pendientes.</p></div>'

    history = data.get("history", [])
    history_html = ""
    if history:
        rows = "".join(
            f'<tr><td>{_esc(h["timestamp"][:16].replace("T", " "))}</td><td>{_esc(h["action"])}</td><td>{_esc(h["detail"])}</td></tr>'
            for h in history
        )
        history_html = f'''
        <div class="card">
          <h2>Historial de optimizaciones</h2>
          <table><thead><tr><th>Fecha</th><th>Acción</th><th>Detalle</th></tr></thead><tbody>{rows}</tbody></table>
        </div>'''

    generated = datetime.now().strftime("%Y-%m-%d %H:%M")

    return f'''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MejoraPC — Informe</title>
<style>{css}</style>
</head>
<body>
  <header>
    <div class="wordmark">Mejora<span class="accent">PC</span></div>
    <div class="tagline">Sistema de mantenimiento y análisis · generado {generated}</div>
  </header>
  <main>
    {hw_html}
    {verify_html}
    {discovery_html}
    {revert_html}
    {recs_html}
    {history_html}
  </main>
  <footer>MejoraPC — parte de <a href="https://mejoraok.com" target="_blank" rel="noopener">Mejora Continua</a></footer>
</body>
</html>'''


def main():
    data = collect()
    html = render(data)
    os.makedirs(LOGS, exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Dashboard guardado en: {OUT_PATH}")
    try:
        webbrowser.open(f"file://{os.path.abspath(OUT_PATH)}")
    except Exception:
        pass


if __name__ == "__main__":
    main()
