import cv2
import numpy as np


def deskew(image: np.ndarray) -> np.ndarray:
    coords = np.column_stack(np.where(image > 0))
    if len(coords) < 100:
        return image
    angle = cv2.minAreaRect(coords)[-1]
    if angle < -45:
        angle = 90 + angle
    if abs(angle) < 0.5:
        return image
    h, w = image.shape[:2]
    center = (w // 2, h // 2)
    mat = cv2.getRotationMatrix2D(center, angle, 1.0)
    return cv2.warpAffine(
        image, mat, (w, h),
        flags=cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_REPLICATE
    )


def enhance_image(image: np.ndarray) -> np.ndarray:
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    else:
        gray = image

    denoised = cv2.fastNlMeansDenoising(gray, h=10)
    deskewed = deskew(denoised)
    sharp = cv2.filter2D(deskewed, -1, np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]]))
    return cv2.threshold(sharp, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]


def enhance_for_layout(image: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if len(image.shape) == 3 else image
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(gray)
