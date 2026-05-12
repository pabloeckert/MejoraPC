#!/bin/bash
# push.sh — Push automático a GitHub
# Uso: ./push.sh "mensaje del commit" (opcional)
# Si no hay cambios, no hace nada.

cd "$(dirname "$0")"

MSG="${1:-auto: $(date '+%Y-%m-%d %H:%M')}"

# Verificar si hay cambios
if git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    echo "✅ Sin cambios para commitear."
    exit 0
fi

# Commit y push
git add -A
git commit -m "$MSG"
git push origin main

echo "✅ Push completado: $MSG"
