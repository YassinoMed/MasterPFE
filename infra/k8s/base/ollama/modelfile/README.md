# Modelfile — infrastructure Ollama (MLSecOps LLM03 : Supply Chain)
# Source du modèle : Qwen/Qwen2.5-0.5B-Instruct-GGUF (HuggingFace)
# Fichier       : qwen2.5-0.5b-instruct-q4_k_m.gguf
# Taille        : 491 400 032 octets
# Import manuel : kubectl cp <gguf> <pod>:/ollama/ && ollama create -f Modelfile
#
# Le GGUF n'est PAS committé (491MB) : l'import est documenté et reproductible.
# Paramètres :
#   temperature 0.1 → déterminisme maximal pour l'analyse sécurité
#   num_ctx 1024     → borne mémoire (2Gi LimitRange) — anti OOM validé
