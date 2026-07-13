from pathlib import Path
from multiprocessing import Pool, cpu_count
from typing import Optional
from tqdm import tqdm
from src.engine import extract_pdf
from src.postprocessing.export import export_df
from src.utils.logger import setup_logger

logger = setup_logger("batch_processor")


def _process_single(args: tuple) -> None:
    pdf_path, output_dir, force_ocr, classify, use_pipeline, fmt = args
    try:
        df = extract_pdf(
            pdf_path,
            force_ocr=force_ocr,
            classify=classify,
            use_pipeline=use_pipeline,
        )
        if df.empty:
            logger.warning(f"No data extracted from {pdf_path}")
            return

        doc_type = df.attrs.get("doc_type", "unknown")
        base_name = Path(pdf_path).stem
        out_path = export_df(df, output_dir, base_name, fmt=fmt, doc_type=doc_type)
        logger.info(f"OK: {Path(pdf_path).name} -> {out_path} [{doc_type}]")
    except Exception as e:
        logger.error(f"FAILED: {Path(pdf_path).name} — {e}")


def process_single_pdf(
    pdf_path: str,
    output_dir: str,
    force_ocr: bool = False,
    classify: bool = True,
    use_pipeline: bool = True,
    fmt: str = "xlsx",
) -> None:
    _process_single((pdf_path, output_dir, force_ocr, classify, use_pipeline, fmt))


def process_batch(
    pdf_paths: list[str],
    output_dir: str,
    workers: Optional[int] = None,
    force_ocr: bool = False,
    classify: bool = True,
    use_pipeline: bool = True,
    fmt: str = "xlsx",
) -> None:
    workers = workers or max(1, cpu_count() - 1)
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    args_list = [
        (p, output_dir, force_ocr, classify, use_pipeline, fmt) for p in pdf_paths
    ]

    if workers == 1:
        for a in tqdm(args_list, desc="Processing PDFs"):
            _process_single(a)
    else:
        with Pool(processes=workers) as pool:
            list(
                tqdm(
                    pool.imap_unordered(_process_single, args_list),
                    total=len(args_list),
                    desc="Processing PDFs",
                )
            )
