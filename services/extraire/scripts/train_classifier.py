"""
Train a TF-IDF + Logistic Regression document classifier.

Usage:
    python scripts/train_classifier.py --data samples.json --output model.pkl

Sample data format (JSON):
    [
        {"text": "BANK STATEMENT ...", "label": "bank_statement"},
        {"text": "INVOICE ...", "label": "invoice"},
        ...
    ]
"""

import argparse
import json
import pickle
from pathlib import Path

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report


def main():
    parser = argparse.ArgumentParser(description="Train document classifier")
    parser.add_argument("--data", required=True, help="JSON training data")
    parser.add_argument("--output", default="models/classifier.pkl", help="Output model path")
    parser.add_argument("--test-size", type=float, default=0.2, help="Test split ratio")
    args = parser.parse_args()

    with open(args.data) as f:
        samples = json.load(f)

    texts = [s["text"] for s in samples]
    labels = [s["label"] for s in samples]

    X_train, X_test, y_train, y_test = train_test_split(
        texts, labels, test_size=args.test_size, random_state=42
    )

    pipeline = Pipeline([
        ("tfidf", TfidfVectorizer(max_features=5000, ngram_range=(1, 3), stop_words="english")),
        ("clf", LogisticRegression(max_iter=1000, multi_class="multinomial")),
    ])

    pipeline.fit(X_train, y_train)
    acc = pipeline.score(X_test, y_test)
    print(f"Accuracy: {acc:.3f}")
    print(classification_report(y_test, pipeline.predict(X_test)))

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "wb") as f:
        pickle.dump(pipeline, f)
    print(f"Model saved to {out_path}")


if __name__ == "__main__":
    main()
