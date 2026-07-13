import os
import sys
from pathlib import Path
from flask import Flask, render_template, request, send_file, flash, redirect, url_for

_BASE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_BASE))

from pipeline.batch_processor import process_single_pdf

app = Flask(__name__)
app.secret_key = os.urandom(24).hex()

UPLOAD_DIR = _BASE / "uploads"
OUTPUT_DIR = _BASE / "results"
UPLOAD_DIR.mkdir(exist_ok=True)
OUTPUT_DIR.mkdir(exist_ok=True)

FORMATS = ["xlsx", "json", "txt", "xml"]

def _find_results():
    exts = ["*.xlsx", "*.json", "*.txt", "*.xml"]
    files = []
    for ext in exts:
        files.extend(OUTPUT_DIR.glob(ext))
    return sorted((p.name for p in files), reverse=True)


@app.route("/")
def index():
    return redirect(url_for('upload'))

@app.route("/dashboard")
def dashboard():
    return render_template("dashboard.html")

@app.route("/upload", methods=["GET", "POST"])
def upload():
    if request.method == "POST":
        f = request.files.get("file")
        # In the prototype, format isn't easily submitted without modifying the JS or wrapping everything in a form. 
        # We will assume a default format or parse it if the user modifies the prototype form correctly.
        fmt = request.form.get("format", "xlsx")

        if not f or not f.filename.lower().endswith(".pdf"):
            flash("Please upload a PDF file", "error")
            return render_template("upload.html", formats=FORMATS, files=_find_results())

        name = secure_filename(f.filename)
        in_path = UPLOAD_DIR / name
        f.save(str(in_path))

        try:
            process_single_pdf(str(in_path), str(OUTPUT_DIR), fmt=fmt)
            flash(f"Done: {name} ({fmt})", "success")
        except Exception as e:
            flash(f"Error: {e}", "error")

    return render_template("upload.html", formats=FORMATS, files=_find_results())

@app.route("/history")
def history():
    return render_template("history.html", files=_find_results())

@app.route("/settings")
def settings():
    return render_template("settings.html")


@app.route("/download/<name>")
def download(name: str):
    return send_file(str(OUTPUT_DIR / name), as_attachment=True)


def main():
    app.run(host="0.0.0.0", port=5000, debug=False)


if __name__ == "__main__":
    main()
