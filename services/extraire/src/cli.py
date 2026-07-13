import argparse
import os
import sys
from glob import glob
from itertools import islice

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pipeline.batch_processor import process_batch


def batched(iterable, batch_size: int = 10):
    it = iter(iterable)
    while batch := list(islice(it, batch_size)):
        yield batch


def main() -> None:
    parser = argparse.ArgumentParser(
        description="PDF Data Extractor — Extract text and tables from PDFs"
    )
    parser.add_argument("input", help="PDF file(s) or directory")
    parser.add_argument("--output", "-o", default="./output", help="Output directory")
    parser.add_argument("--workers", "-w", type=int, help="Parallel workers")
    parser.add_argument("--batch-size", type=int, default=10, help="Batch size")
    parser.add_argument("--force-ocr", action="store_true", help="Force OCR")
    parser.add_argument("--no-classify", action="store_true", help="Disable document classification")
    parser.add_argument("--no-pipeline", action="store_true", help="Disable specialized extraction")
    parser.add_argument(
        "--format", "-f", default="xlsx", choices=["xlsx", "json", "txt", "xml"],
        help="Output format (default: xlsx)"
    )
    args = parser.parse_args()

    if os.path.isdir(args.input):
        pdf_paths = glob(os.path.join(args.input, "*.pdf"))
    else:
        pdf_paths = glob(args.input)

    if not pdf_paths:
        print(f"No PDF files found for: {args.input}")
        sys.exit(1)

    print(f"Found {len(pdf_paths)} PDF(s) — fmt={args.format} OCR={args.force_ocr}")
    for batch in batched(pdf_paths, args.batch_size):
        process_batch(
            batch, args.output, args.workers,
            force_ocr=args.force_ocr,
            classify=not args.no_classify,
            use_pipeline=not args.no_pipeline,
            fmt=args.format,
        )


if __name__ == "__main__":
    main()
