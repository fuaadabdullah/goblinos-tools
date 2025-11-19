import json
from pathlib import Path
from datetime import datetime


class ReportGenerator:
    def __init__(self, reports_dir: Path):
        self.reports_dir = reports_dir
        self.reports_dir.mkdir(parents=True, exist_ok=True)

    def write_report(self, payload: dict) -> str:
        ts = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        fname = f"goblin-email-purge-report-{ts}.json"
        path = self.reports_dir / fname
        with path.open("w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)
        return str(path.resolve())
