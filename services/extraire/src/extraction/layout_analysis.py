import cv2
import numpy as np
from src.text_extraction import extract_text_fallback

LayoutBlock = dict


def _merge_nearby_blocks(blocks: list[LayoutBlock], y_thresh: int = 15, x_thresh: int = 30) -> list[LayoutBlock]:
    if not blocks:
        return []
    sorted_b = sorted(blocks, key=lambda b: (b["y"], b["x"]))
    merged = [sorted_b[0]]
    for b in sorted_b[1:]:
        last = merged[-1]
        if (abs(b["y"] - last["y"]) < y_thresh and
                b["x"] - (last["x"] + last["w"]) < x_thresh and
                last["type"] == b["type"] == "Text"):
            new_w = (b["x"] + b["w"]) - last["x"]
            new_h = max(last["h"], b["h"])
            merged[-1] = {
                "type": "Text",
                "text": (last["text"] + " " + b["text"]).strip(),
                "x": last["x"], "y": last["y"], "w": new_w, "h": new_h,
            }
        else:
            merged.append(b)
    return merged


def _classify_block(w: int, h: int, text_len: int, area_ratio: float) -> str:
    if text_len < 3:
        return "Noise"
    if h < 15:
        return "Header"
    if h < 35 and text_len < 30:
        return "Title" if text_len > 3 else "Header"
    if w > 200 and h < 40:
        return "Title"
    if area_ratio > 0.3:
        return "Figure"
    return "Text"


def detect_layout_elements(image: np.ndarray) -> list[LayoutBlock]:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]

    kernel_block = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 15))
    blocks = cv2.dilate(thresh, kernel_block, iterations=2)

    contours, _ = cv2.findContours(blocks, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    elements = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        if w < 40 or h < 10:
            continue
        area_ratio = (w * h) / (image.shape[0] * image.shape[1])
        if area_ratio < 0.0005:
            continue

        roi = image[y: y + h, x: x + w]
        text = extract_text_fallback(roi)

        block_type = _classify_block(w, h, len(text.strip()), area_ratio)
        if block_type == "Noise" and text.strip():
            block_type = "Text"

        elements.append({
            "type": block_type,
            "text": text.strip(),
            "x": x, "y": y, "w": w, "h": h,
        })

    elements = [e for e in elements if e["type"] != "Noise"]
    elements = _merge_nearby_blocks(elements)
    return sorted(elements, key=lambda e: (e["y"], e["x"]))
