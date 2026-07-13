# Rapport complet — PDF Data Extractor

> **Version :** 0.3.0  
> **Licence :** MIT  
> **Auteur :** Moffat Kagiri  
> **Stack :** Python 3.9+ | Tesseract OCR | EasyOCR | OpenCV | pdfplumber | Flask

---

## 1. Présentation

**PDF Data Extractor** est un pipeline Python d'extraction structurée de données depuis des fichiers PDF. Il prend en charge les documents **typés** (texte natif), **scannés** (images + OCR) et **manuscrits**, et produit des fichiers exploitables dans 4 formats : **Excel**, **JSON**, **TXT** et **XML**.

### Fonctionnalités clés

| Fonctionnalité | Statut |
|---|---|
| Extraction PDF typés (pdfplumber) | ✅ |
| OCR Tesseract + fallback EasyOCR | ✅ |
| Détection de layout par contours OpenCV | ✅ |
| Classification automatique de documents | ✅ |
| Pipelines d'extraction spécialisés | ✅ |
| Export multi-format (xlsx, json, txt, xml) | ✅ |
| Interface web Flask (upload + téléchargement) | ✅ |
| Traitement par lots (multiprocessing) | ✅ |
| Packaging pip installable | ✅ |
| Scripts d'entraînement (classifieur + YOLO) | ✅ |
| CI/CD (GitHub Actions) | ✅ |

---

## 2. Architecture du projet

```
pdf-extraction/
│
├── configs/                    # Configuration YAML
│   ├── ocr_config.yaml         #   Langues, PSM, OEM
│   ├── layout_config.yaml      #   Seuils de détection
│   └── stamp_detection.yaml    #   Paramètres YOLO
│
├── pipeline/
│   └── batch_processor.py      # Traitement parallèle par lots
│
├── scripts/
│   ├── train_classifier.py     # Entraînement classifieur (TF-IDF + LR)
│   ├── train_stamp_detector.py # Entraînement détecteur de tampons (YOLOv5)
│   └── annotate.py             # Export annotations Label Studio → YOLO
│
├── src/
│   ├── cli.py                  # Interface en ligne de commande
│   ├── webapp.py               # Interface web Flask
│   ├── engine.py               # Moteur d'extraction unifié
│   ├── text_extraction.py      # OCR (Tesseract + EasyOCR)
│   │
│   ├── classification/
│   │   ├── document_classifier.py  # Classifieur par règles + ML
│   │   └── pipelines.py            # Pipelines spécialisés par type
│   │
│   ├── extraction/
│   │   ├── layout_analysis.py  # Détection de blocs texte
│   │   └── table_handling.py   # Extraction de tableaux
│   │
│   ├── preprocessing/
│   │   ├── pdf_to_image.py     # Conversion PDF → images
│   │   └── image_enhancement.py # Amélioration d'image (deskew, denoise)
│   │
│   ├── postprocessing/
│   │   ├── export.py           # Export xlsx / json / txt / xml
│   │   ├── structure_data.py   # Structuration en DataFrame
│   │   └── text_cleaner.py     # Nettoyage de texte
│   │
│   └── utils/
│       ├── config_loader.py    # Chargement YAML
│       └── logger.py           # Logger structuré
│
├── tests/                      # 24 tests unitaires
│   ├── test_classification.py
│   ├── test_export.py
│   ├── test_pdf_processing.py
│   └── test_table_extraction.py
│
├── Dockerfile                  # Image Docker (Tesseract + Poppler)
├── setup.py                    # Packaging pip
├── pyproject.toml              # Métadonnées projet
└── requirements.txt            # Dépendances
```

---

## 3. Pipeline d'extraction

```
                    ┌─────────────┐
                    │  Fichier    │
                    │    PDF      │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Détection  │
                    │  typé/scanné│
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐    │    ┌───────▼───────┐
       │  PDF typé   │    │    │  PDF scanné   │
       │ pdfplumber  │    │    │ OCR (image)   │
       └──────┬──────┘    │    └───────┬───────┘
              │           │            │
              └───┬───────┘    ┌───────▼───────┐
                  │            │  Enhancement  │
                  │            │ deskew+denoise│
                  │            └───────┬───────┘
                  │                    │
                  │            ┌───────▼───────┐
                  │            │  OCR          │
                  │            │ Tesseract     │
                  │            │ └→ EasyOCR    │
                  │            └───────┬───────┘
                  │                    │
                  └────────┬───────────┘
                           │
                    ┌──────▼──────┐
                    │  Texte brut │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Classif.   │ ← banque, facture, contrat...
                    │  doc_type   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Pipeline   │
                    │  spécialisé │ ← extrait champs structurés
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Export    │
                    │ xlsx/json   │
                    │ txt/xml     │
                    └─────────────┘
```

---

## 4. Classification automatique

Le classifieur identifie le type de document par analyse de motifs textuels.

### Types supportés

| Type | Exemples de motifs détectés |
|---|---|
| `bank_statement` | account number, transaction, balance, IBAN |
| `invoice` | invoice number, VAT, total due, facture |
| `contract` | agreement, party, confidentiality, governing law |
| `article` | abstract, methodology, DOI, ISSN, references |
| `form` | section, applicant, signature, checkbox |
| `receipt` | receipt, total, cash, thank you |
| `letter` | dear sir, sincerely, to whom it may concern |
| `other` | fallback par défaut |

### Pipelines spécialisés

Chaque type possède son propre extracteur de champs :

| Type | Champs extraits |
|---|---|
| `bank_statement` | account_number, balance, period, transactions |
| `invoice` | invoice_number, date, due_date, total, vat |
| `contract` | parties, date |
| `article` | title, abstract |
| `form` | field lists |
| `receipt` | store, total |
| `letter` | recipient, sender |

### Entraînement ML (optionnel)

```bash
python scripts/train_classifier.py --data samples.json --output models/classifier.pkl
```

Utilise TF-IDF + Régression Logistique (sklearn). Accuracy typique : > 90 %.

---

## 5. Formats d'export

| Format | Extension | Description |
|---|---|---|
| **Excel** | `.xlsx` | Tableau avec onglets, compatible Excel/LibreOffice |
| **JSON** | `.json` | Structuré, clé-valeur, `null` pour les champs vides |
| **TXT** | `.txt` | Lisible, colonnes séparées par `\|` |
| **XML** | `.xml` | Hiérarchique, balise `<documents>` racine |

### Exemples

**JSON :**
```json
[
  {"type": "paragraph", "content": "BANK STATEMENT", "page": 0.0},
  {"type": "document_type", "content": "bank_statement", "page": null}
]
```

**TXT :**
```
type | content | page
------------------------------------------------------------
paragraph | BANK STATEMENT | 0.0
document_type | bank_statement |
```

**XML :**
```xml
<documents>
  <item><type>paragraph</type><content>BANK STATEMENT</content><page>0.0</page></item>
</documents>
```

---

## 6. Interface web

L'interface Flask propose :

- Upload de fichiers PDF
- Sélecteur de format (xlsx / json / txt / xml)
- Extraction automatique
- Téléchargement du résultat

```bash
pdf-web
# → http://localhost:5000
```

---

## 7. Tests

**24 tests unitaires — 100 % de succès**

```
tests/test_classification.py ........ 11 tests
tests/test_export.py ............... 7 tests
tests/test_pdf_processing.py ...... 1 test
tests/test_table_extraction.py .... 5 tests
```

### Couverture de code

| Module | Couverture |
|---|---|
| `src/classification/` | 93 % |
| `src/postprocessing/export.py` | 94 % |
| `src/utils/logger.py` | 100 % |
| `src/preprocessing/pdf_to_image.py` | 100 % |
| **Moyenne générale** | **46 %** |

> *Note : La couverture moyenne est basse car les modules CLI, webapp et layout_analysis sont peu testés automatiquement (nécessitent des fichiers PDF réels).*

---

## 8. Dépendances

### Production

| Package | Rôle |
|---|---|
| `pdfplumber` | Extraction texte + tableaux des PDF typés |
| `pdf2image` | Conversion PDF → images |
| `pytesseract` | OCR Tesseract |
| `easyocr` | OCR fallback (deep learning) |
| `opencv-python` | Traitement d'image (deskew, seuillage, contours) |
| `pandas` | Structuration des données |
| `openpyxl` / `xlsxwriter` | Export Excel |
| `flask` | Interface web |
| `PyYAML` | Configuration |
| `tqdm` | Barres de progression |

### Développement

| Package | Rôle |
|---|---|
| `pytest` / `pytest-cov` | Tests + couverture |
| `mypy` | Vérification de types |
| `black` / `isort` / `flake8` | Formatage |
| `fpdf2` | Génération PDF de test |
| `scikit-learn` | Entraînement classifieur ML |
| `torch` / `yolov5` | Détection de tampons |

---

## 9. Installation

### Local

```bash
git clone https://github.com/moffat-kagiri/pdf-extraction.git
cd pdf-extraction
pip install -e .
```

Prérequis système :
- **Tesseract OCR** (téléchargement : [UB-Mannheim](https://github.com/UB-Mannheim/tesseract/wiki))
- **Poppler** (pour pdf2image)

### Docker

```bash
docker build -t pdf-data-extractor .
docker run -v $(pwd)/pdfs:/data -v $(pwd)/output:/output pdf-data-extractor
```

---

## 10. Utilisation

### CLI

```bash
# Extraction simple
pdf-extract document.pdf -o results

# Traitement par lots (dossier)
pdf-extract dossier_pdfs/ -o results -w 4 --format json

# Forcer l'OCR (même pour les PDF typés)
pdf-extract scan.pdf --force-ocr -f txt

# Désactiver la classification
pdf-extract doc.pdf --no-classify -f xml
```

### Web UI

```bash
pdf-web
# → http://localhost:5000
```

### Python

```python
from src.engine import extract_pdf

df = extract_pdf("document.pdf")
print(df)
# → DataFrame avec colonnes : type, content, page
```

---

## 11. Entraînement

### Classifieur de documents

```bash
# 1. Préparer les données (JSON)
cat > samples.json << 'EOF'
[
  {"text": "BANK STATEMENT account 12345", "label": "bank_statement"},
  {"text": "INVOICE INV-001 total 1500", "label": "invoice"}
]
EOF

# 2. Entraîner
python scripts/train_classifier.py --data samples.json --output models/classifier.pkl
```

### Détecteur de tampons (YOLOv5)

```bash
# 1. Annoter avec Label Studio
python scripts/annotate.py --export annotations.json --output yolo_data/

# 2. Entraîner YOLO
python scripts/train_stamp_detector.py --data dataset.yaml --epochs 50
```

---

## 12. Travail futur

| Amélioration | Priorité |
|---|---|
| Intégration LLM (Ollama) pour extraction structurée | Haute |
| Table Transformer (HuggingFace) pour tableaux complexes | Haute |
| API REST asynchrone avec files d'attente | Moyenne |
| Support cloud (Google Drive, S3) | Moyenne |
| Dashboard temps réel (WebSocket) | Basse |
| Plugin system pour formats personnalisés | Basse |

---

## 13. État des lieux du projet original (corrections appliquées)

| Problème original | Correction |
|---|---|
| `detectron2` non installable sur Windows | Remplacement par contours OpenCV + OCR |
| `postprocessing/structure_data.py` vide | Implémenté |
| `postprocessing/text_cleaner.py` vide | Implémenté |
| `layout_analysis.py` bloqué sur Detectron2 | Rewrite complet |
| `batch_processor.py` : lambda non pickleable + `del img` bug | Fonction module-level |
| `cli.py` : `sys.path` non configuré | Correction du PYTHONPATH |
| `requirements.txt` : noms invalides (`PIL`, `ow`, `Tesseract`) | Nettoyage |
| `pyproject.toml` : nom `name-unrelated` | Renommage en `pdf-data-extractor` |
| `.gitignore` vide | Ajouté |
| Workflows GitHub : secrets incorrects | Corrigé |
| Test `test_pdf_conversion()` : `sample.pdf` manquant | Fixture pytest avec generation |
| Modules `table_handling.py` : import relatif cassé | Corrigé |
| `utils/logger.py` : duplicate handlers à chaque appel | Pattern singleton |
| OCR : Tesseract uniquement, pas de fallback | EasyOCR en fallback |
| Pas de classification document | Module `classification/` ajouté |
| Pas d'export multi-format | Module `export.py` (xlsx/json/txt/xml) |
| Pas de packaging pip | `setup.py` + entry points |
| Pas d'interface web | Flask `webapp.py` |
| Pas de scripts d'entraînement ML | `train_classifier.py` + `train_stamp_detector.py` |
| Pas de preprocessing image avancé | Deskew + CLAHE + sharpening |

---

## 14. Licence

MIT © 2024 Moffat Kagiri. Voir [LICENSE](LICENSE).
