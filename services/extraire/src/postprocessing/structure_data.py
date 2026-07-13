import pandas as pd


def to_structured_table(layout_elements: list[dict]) -> pd.DataFrame:
    rows = []
    for el in layout_elements:
        rows.append(
            {
                "type": el.get("type", "Text"),
                "content": el.get("text", ""),
                "x": el.get("x", 0),
                "y": el.get("y", 0),
                "width": el.get("w", 0),
                "height": el.get("h", 0),
            }
        )
    return pd.DataFrame(rows)
