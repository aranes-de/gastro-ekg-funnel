#!/usr/bin/env bash
#
# Deploy des Empfehlungslink-Funnels nach
#   https://empfehlen.gastro-einkaufsgemeinschaft.de/
#
# Ablauf: lokal bauen -> per rsync in ein neues, zeitgestempeltes Release auf
# lara3 laden -> den Symlink "current" darauf umlegen -> alte Releases
# aufraeumen. Der nginx-Docroot ist /var/www/gastro-ekg-funnel/current, es ist
# also nie ein halb hochgeladener Stand live.
#
# Nutzung:  ./bin/deploy.sh
#
# Rollback (jedes Release bleibt liegen, nur den Symlink zuruecklegen):
#   ssh deploy@lara3.aranes.de "ls -1dt /var/www/gastro-ekg-funnel/releases/*/"
#   ssh deploy@lara3.aranes.de "ln -sfn releases/<aelteres> /var/www/gastro-ekg-funnel/current.tmp \
#                               && mv -Tf /var/www/gastro-ekg-funnel/current.tmp /var/www/gastro-ekg-funnel/current"
#
set -euo pipefail

SSH_HOST="${DEPLOY_SSH_HOST:-deploy@lara3.aranes.de}"
BASE="${DEPLOY_BASE:-/var/www/gastro-ekg-funnel}"
BUILD_DIR="${DEPLOY_BUILD_DIR:-_site}"          # Eleventy-Output, s. eleventy.config.js
BUILD_CMD="${DEPLOY_BUILD_CMD:-npm run build}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"
KEEP="${DEPLOY_KEEP:-5}"                        # Releases, die stehen bleiben

cd "$(dirname "$0")/.."

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "$DEPLOY_BRANCH" ]; then
  echo "FEHLER: Aktueller Branch ist '$CURRENT_BRANCH', deployt wird '$DEPLOY_BRANCH'." >&2
  echo "        Bewusst anderer Branch? Dann: DEPLOY_BRANCH=$CURRENT_BRANCH ./bin/deploy.sh" >&2
  exit 1
fi

# Gebaut wird aus dem Arbeitsverzeichnis. Ist es schmutzig, waere nicht
# nachvollziehbar, welcher Commit live steht.
if [ -n "$(git status --porcelain)" ]; then
  echo "FEHLER: Arbeitsverzeichnis ist nicht sauber - erst committen." >&2
  git status --short >&2
  exit 1
fi

RELEASE="$(date +%Y%m%d%H%M%S)"
REMOTE_RELEASE="$BASE/releases/$RELEASE"

echo "==> Build ($BUILD_CMD), Commit $(git rev-parse --short HEAD)"
rm -rf "$BUILD_DIR"
eval "$BUILD_CMD"
[ -f "$BUILD_DIR/index.html" ] || { echo "FEHLER: $BUILD_DIR/index.html fehlt - Build unvollstaendig." >&2; exit 1; }

echo "==> Upload nach $SSH_HOST:$REMOTE_RELEASE"
ssh "$SSH_HOST" "mkdir -p '$REMOTE_RELEASE'"
rsync -az "$BUILD_DIR/" "$SSH_HOST:$REMOTE_RELEASE/"

# ln -sfn ersetzt den Symlink nicht atomar (unlink + symlink, dazwischen 404).
# Ueber einen temporaeren Link + mv -Tf erledigt das rename(2) in einem Schritt.
echo "==> current -> releases/$RELEASE"
ssh "$SSH_HOST" "ln -sfn 'releases/$RELEASE' '$BASE/current.tmp' && mv -Tf '$BASE/current.tmp' '$BASE/current'"

# Aufraeumen nach Alter, aber das aktive Release ist tabu: nach einem Rollback
# zeigt current auf ein aelteres, das sonst hier weggeraeumt wuerde.
echo "==> Alte Releases aufraeumen (behalte $KEEP)"
ssh "$SSH_HOST" bash -s <<EOF
set -euo pipefail
cd '$BASE/releases'
LIVE="\$(basename "\$(readlink -f '$BASE/current')")"
# grep liefert Exit 1, wenn nichts uebrig bleibt (erstes Release = LIVE) -
# mit pipefail waere das ein Abbruch, obwohl nichts zu tun ist.
ls -1dt */ | sed 's#/\$##' | { grep -vx "\$LIVE" || true; } | tail -n +$KEEP | xargs -r rm -rf
EOF

echo "==> Fertig: https://empfehlen.gastro-einkaufsgemeinschaft.de/ (Release $RELEASE)"
