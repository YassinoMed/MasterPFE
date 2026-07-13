"""
Export annotations from Label Studio for YOLO training.

Usage:
    python scripts/annotate.py --project-id 1 --output ./annotations
"""

import argparse
import json
from pathlib import Path


def convert_label_studio_to_yolo(export_path: str, output_dir: str):
    """
    Convert Label Studio JSON export to YOLO format.

    Expected Label Studio export format with image bounding boxes.
    """
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / "labels").mkdir(exist_ok=True)

    with open(export_path) as f:
        tasks = json.load(f)

    for task in tasks:
        image_path = task.get("data", {}).get("image", "")
        if not image_path:
            continue

        img_name = Path(image_path).stem
        img_w, img_h = task.get("data", {}).get("image_width", 1), task.get("data", {}).get("image_height", 1)

        annotations = []
        for ann in task.get("annotations", []) or []:
            for result in ann.get("result", []):
                if result.get("type") != "rectanglelabels":
                    continue
                val = result.get("value", {})
                x = val["x"] / 100 * img_w
                y = val["y"] / 100 * img_h
                w = val["width"] / 100 * img_w
                h = val["height"] / 100 * img_h
                label = val.get("rectanglelabels", ["stamp"])[0]
                cx, cy = (x + w / 2) / img_w, (y + h / 2) / img_h
                nw, nh = w / img_w, h / img_h
                annotations.append(f"0 {cx:.6f} {cy:.6f} {nw:.6f} {nh:.6f}")

        if annotations:
            (out / "labels" / f"{img_name}.txt").write_text("\n".join(annotations))

    print(f"Converted {len(tasks)} tasks to YOLO format in {output_dir}")


def main():
    parser = argparse.ArgumentParser(description="Export Label Studio annotations")
    parser.add_argument("--export", required=True, help="Label Studio JSON export file")
    parser.add_argument("--output", default="./yolo_annotations", help="Output directory")
    args = parser.parse_args()
    convert_label_studio_to_yolo(args.export, args.output)


if __name__ == "__main__":
    main()
