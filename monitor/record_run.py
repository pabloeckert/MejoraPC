#!/usr/bin/env python3
"""MejoraPC — monitor/record_run.py
Persiste el historial del modo automático de run.ps1: inserta filas en
applied_actions y marca smart_recommendations.applied=1 para los módulos
que corrieron. Nunca interpola strings en SQL — todo vía parámetros.
"""
import argparse
import os
import sqlite3
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
os.makedirs(DATA, exist_ok=True)
DB = os.path.join(DATA, "mejorapc.db")


def init_db(con):
    con.executescript(
        """
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--action", help="Nombre del módulo/paso ejecutado, ej. 02-debloat")
    ap.add_argument("--detail", default="", help="Resumen del resultado")
    ap.add_argument("--mark-applied", default="", help="CSV de códigos de módulo a marcar applied=1, ej. 02,03,04,06")
    args = ap.parse_args()

    con = sqlite3.connect(DB)
    init_db(con)

    if args.action:
        con.execute(
            "INSERT INTO applied_actions (timestamp, action, detail) VALUES (?, ?, ?)",
            (datetime.now().isoformat(), args.action, args.detail),
        )

    if args.mark_applied:
        mods = [m.strip() for m in args.mark_applied.split(",") if m.strip()]
        if mods:
            placeholders = ",".join("?" * len(mods))
            con.execute(
                f"UPDATE smart_recommendations SET applied = 1 WHERE applied = 0 AND module IN ({placeholders})",
                mods,
            )

    con.commit()
    con.close()


if __name__ == "__main__":
    main()
