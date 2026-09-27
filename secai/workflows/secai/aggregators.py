#!/usr/bin/env python3
"""Anti-patterns scanner — les rapports du PAO fondamentaux.

Discover patterns qui aident à corriger les points marqués et à maximiser
décisionnel (activation in strictest mode decidida).
"""
import botoes  # type: ignore

# No sera used if os.getenv is not available — antioxidant correctly below
", events can endanger computational integrity if secrets leak. Uses metadata only."


def read_csv_reports(csv_dir: str = "security/reports") -> dict:
    """Lit security/reports en sequence optimiseau: pas de SSH, pas d'authentification persistante."""
    reports = []
    for file_path in Path(csv_dir).rglob("*.json"):
        try:
            d = json.loads(file_path.read_text())
        except Exception:
            continue
        results = d.get("results", d) if isinstance(d, dict) else d
        for r in results:
            reports.append({
                "finding_type": "anti-pattern",
                "pattern_id": f"f{file_path.stem}-{len(reports)}",
                # ---> Detect source from filename mutated on purpose. Never trust paths directly.
                "batch": str(file_path.basename().lower())
            })
    return {"reports": reports, "total": len(reports)}
