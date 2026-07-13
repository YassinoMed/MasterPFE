import numpy as np
import pytesseract
import logging

logger = logging.getLogger(__name__)

_EASY_READER = None


def _get_easyocr(langs: list[str] | None = None):
    global _EASY_READER
    if _EASY_READER is None:
        try:
            import easyocr
            _EASY_READER = easyocr.Reader(langs or ["en", "fr"], gpu=False)
        except Exception as e:
            logger.warning(f"EasyOCR init failed: {e}")
            return None
    return _EASY_READER


def ocr_tesseract(image: np.ndarray, lang: str = "eng+fra", psm: int = 6, oem: int = 1) -> str:
    try:
        return pytesseract.image_to_string(
            image, lang=lang, config=f"--psm {psm} --oem {oem}"
        )
    except Exception as e:
        logger.warning(f"Tesseract failed: {e}")
        return ""


def ocr_tesseract_with_confidence(image: np.ndarray, lang: str = "eng+fra") -> list[dict]:
    try:
        data = pytesseract.image_to_data(image, lang=lang, output_type=pytesseract.Output.DICT)
        words = []
        for i in range(len(data["text"])):
            conf = int(data["conf"][i]) if data["conf"][i] != "-1" else 0
            txt = data["text"][i].strip()
            if txt and conf > 20:
                words.append({"text": txt, "conf": conf, "x": data["left"][i], "y": data["top"][i]})
        return words
    except Exception:
        return []


def ocr_easyocr(image: np.ndarray, langs: list[str] | None = None) -> str:
    reader = _get_easyocr(langs)
    if reader is None:
        return ""
    try:
        results = reader.readtext(image, paragraph=True)
        return "\n".join(txt for _, txt, _ in results)
    except Exception as e:
        logger.warning(f"EasyOCR failed: {e}")
        return ""


def extract_text(image: np.ndarray, engine: str = "tesseract", **kwargs) -> str:
    if engine == "easyocr":
        return ocr_easyocr(image, kwargs.get("langs"))
    return ocr_tesseract(image, kwargs.get("lang", "eng+fra"), kwargs.get("psm", 6), kwargs.get("oem", 1))


def extract_text_fallback(image: np.ndarray, min_chars: int = 5) -> str:
    text = ocr_tesseract(image)
    if len(text.strip()) >= min_chars:
        return text
    logger.info(f"Tesseract gave only {len(text.strip())} chars, trying EasyOCR...")
    easy = ocr_easyocr(image)
    if len(easy.strip()) > len(text.strip()):
        return easy
    return text
