#!/usr/bin/env python3
"""MejoraPC — monitor/dashboard_data.py
Recolecta los datos para el dashboard HTML (monitor/html_report.py).
Mismas queries que ya usa monitor/report.py (dashboard de consola) —
código separado a propósito: cero acoplamiento, no arriesga el dashboard
de consola que ya funciona.
"""
import json
import os
import sqlite3
from collections import Counter, defaultdict
from datetime import datetime, timedelta

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
DB = os.path.join(DATA, "mejorapc.db")


def collect():
    data = {
        "hardware": None,
        "ram_delta": None,
        "top_processes": [],
        "recommendations": [],
        "history": [],
        "last_verify": None,
        "discovery": None,
        "restore_point": None,
    }

    if not os.path.exists(DB):
        return data

    con = sqlite3.connect(DB)

    hw_rows = con.execute(
        "SELECT timestamp, ram_total_gb, ram_free_gb, cpu_model, score "
        "FROM hardware_profile ORDER BY id DESC LIMIT 2"
    ).fetchall()
    if hw_rows:
        ts, total, free, cpu, score = hw_rows[0]
        data["hardware"] = {
            "timestamp": ts, "ram_total_gb": total, "ram_free_gb": free,
            "cpu_model": cpu, "score": score,
        }
        if len(hw_rows) > 1:
            data["ram_delta"] = round(free - hw_rows[1][2], 2)

    wk = (datetime.now() - timedelta(days=7)).isoformat()
    proc_rows = con.execute(
        "SELECT top_processes FROM usage_samples WHERE timestamp >= ?", (wk,)
    ).fetchall()
    counter = Counter()
    for (tj,) in proc_rows:
        for p in json.loads(tj or "[]"):
            counter[p["name"]] += p.get("rss_mb", 0)
    data["top_processes"] = [{"name": n, "ram_mb": m} for n, m in counter.most_common(5)]

    try:
        recs = con.execute(
            "SELECT priority, title, description, module FROM smart_recommendations WHERE applied = 0"
        ).fetchall()
        data["recommendations"] = [
            {"priority": p, "title": t, "description": d, "module": m} for p, t, d, m in recs
        ]
    except sqlite3.OperationalError:
        pass

    try:
        acts = con.execute(
            "SELECT timestamp, action, detail FROM applied_actions ORDER BY id DESC LIMIT 10"
        ).fetchall()
        data["history"] = [{"timestamp": t, "action": a, "detail": d or ""} for t, a, d in acts]
        for row in data["history"]:
            if row["action"] == "01-backup":
                data["restore_point"] = row["timestamp"][:19].replace("T", " ")
                break
    except sqlite3.OperationalError:
        pass

    con.close()

    verify_path = os.path.join(DATA, "last-verify.json")
    if os.path.exists(verify_path):
        try:
            with open(verify_path, "r", encoding="utf-8") as f:
                data["last_verify"] = json.load(f)
        except Exception:
            pass

    discovery_path = os.path.join(DATA, "discovery-report.json")
    if os.path.exists(discovery_path):
        try:
            with open(discovery_path, "r", encoding="utf-8") as f:
                data["discovery"] = json.load(f)
        except Exception:
            pass

    return data
