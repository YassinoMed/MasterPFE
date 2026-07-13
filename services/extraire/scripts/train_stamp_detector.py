"""
Train a YOLOv5 model to detect stamps / signatures in document images.

Usage:
    python scripts/train_stamp_detector.py --data dataset.yaml --epochs 50

Dataset format (YOLO):
    dataset/
      images/train/
      images/val/
      labels/train/
      labels/val/
"""

import argparse
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Train YOLOv5 stamp detector")
    parser.add_argument("--data", required=True, help="Path to dataset.yaml")
    parser.add_argument("--weights", default="yolov5s.pt", help="Pretrained weights")
    parser.add_argument("--epochs", type=int, default=50, help="Training epochs")
    parser.add_argument("--img-size", type=int, default=640, help="Input image size")
    parser.add_argument("--batch-size", type=int, default=16, help="Batch size")
    parser.add_argument("--project", default="runs/train", help="Output directory")
    args = parser.parse_args()

    if not Path(args.data).exists():
        print(f"Dataset YAML not found: {args.data}")
        sys.exit(1)

    repo = Path("yolov5")
    if not repo.exists():
        print("Cloning YOLOv5...")
        subprocess.run(
            ["git", "clone", "https://github.com/ultralytics/yolov5"], check=True
        )

    cmd = [
        sys.executable, str(repo / "train.py"),
        "--data", args.data,
        "--weights", args.weights,
        "--epochs", str(args.epochs),
        "--imgsz", str(args.img_size),
        "--batch-size", str(args.batch_size),
        "--project", args.project,
        "--name", "stamp_detector",
    ]
    subprocess.run(cmd, check=True)


if __name__ == "__main__":
    main()
