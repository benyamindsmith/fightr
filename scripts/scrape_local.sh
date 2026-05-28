#!/usr/bin/env bash
# Run all UFC scrapers locally (ufcstats.com blocks GitHub Actions IPs).
# After this completes, commit data/*.csv and push — Actions will handle cleaning.
#
# Usage:
#   cd scripts
#   ./scrape_local.sh

set -e

# Resolve absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# CRITICAL: Change working directory to the project root.
# This ensures your Python scripts save to repo_root/data/ instead of scripts/data/
cd "$ROOT_DIR"

echo "=== UFC Scraper — Local Run ==="
echo "Working Directory: $(pwd)"
echo "Output directory: $ROOT_DIR/data"
mkdir -p data

echo ""
echo "[1/3] Scraping UFC athlete bios (ufc.com)..."
python scripts/scrape_ufc.py

echo ""
echo "[2/3] Scraping fighter stats (ufcstats.com)..."
python scripts/scrape_ufcstats.py

echo ""
echo "[3/3] Scraping fight history (ufcstats.com)..."
python scripts/scrape_fight_history.py

echo ""
echo "=== Done. Next steps: ==="
echo "  git add data/*.csv"
echo "  git commit -m 'Update raw UFC data'"
echo "  git push"
echo ""
echo "GitHub Actions will then run the R cleaning step automatically."
