from setuptools import setup, find_packages

setup(
    name="pdf-data-extractor",
    version="0.3.0",
    description="Extract structured text, tables, and images from typed and scanned PDFs",
    url="https://github.com/moffat-kagiri/pdf-extraction",
    packages=find_packages(include=["src", "src.*", "pipeline", "configs", "scripts"]),
    include_package_data=True,
    python_requires=">=3.9",
    install_requires=[
        "PyPDF2",
        "pdf2image",
        "pdfplumber",
        "PyYAML",
        "opencv-python",
        "Pillow",
        "pytesseract",
        "easyocr",
        "pandas",
        "openpyxl",
        "xlsxwriter",
        "numpy",
        "tqdm",
        "flask",
        "werkzeug",
    ],
    extras_require={
        "dev": ["mypy", "pytest", "pytest-cov", "black", "isort", "flake8", "fpdf2"],
    },
    entry_points={
        "console_scripts": [
            "pdf-extract=src.cli:main",
            "pdf-web=src.webapp:main",
        ],
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Topic :: Text Processing :: General",
    ],
)
