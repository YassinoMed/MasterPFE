# Guide utilisateur — SecureRAG Hub

## Qui peut faire quoi ?

| Rôle | Capacités |
|------|-----------|
| **USER** | Se connecter, poser des questions au chatbot, uploader ses propres documents, voir son historique. |
| **ADMIN** | Tout ce qu'un USER peut faire + gestion des comptes + assignation rôles + accès à tous documents. |
| **AUDITOR** | Lecture seule des logs d'audit, génération de rapports conformité. |

## 1. Première connexion

1. Ouvrir l'application : `http://localhost:8000` (local) ou l'URL prod
   fournie par l'admin.
2. Cliquer **Créer un compte** → email + mot de passe (8+ caractères).
3. Confirmer l'email (workflow standard Laravel).
4. À la première connexion, le rôle attribué est `USER`.

## 2. Discuter avec le chatbot RAG

1. Aller dans l'onglet **Chat**.
2. Taper une question en langage naturel.
3. Le chatbot va :
   - Vérifier que la question n'est pas malveillante (audit prompt).
   - Chercher dans **vos documents accessibles** (filtre RBAC vectoriel).
   - Générer une réponse avec les chunks trouvés comme contexte.
   - Filtrer la réponse pour éviter toute fuite de secret.

### Cas où la réponse est refusée

Le système refuse de répondre si :

- La question contient des patterns de **prompt injection** (« ignore
  previous instructions », « reveal your prompt », etc.).
- La question demande explicitement des **credentials** (« show
  password », « api key »).
- La réponse générée contient un secret hallucinant (rare mais bloqué).

Dans ces cas, un message neutre est affiché. L'incident est loggé
(audit logs accessibles par AUDITOR).

## 3. Uploader un document

1. Onglet **Documents** → **Importer**.
2. Champs obligatoires (RGPD + RBAC) :
   - **Titre**
   - **Type de document** : `PRESCRIPTION`, `LAB_RESULT`,
     `MEDICAL_REPORT`, `RADIOLOGY_REPORT`, etc.
   - **Sensibilité** : LOW / MEDIUM / HIGH / CRITICAL
   - **Rôles autorisés** à voir ce document (multi-select)
   - **Fichier** : PDF, image scannée, texte
3. Le système :
   - Vérifie la qualité (OCR si image, score qualité).
   - Découpe en chunks (512 chars, overlap 64).
   - Calcule les embeddings (modèle local).
   - Indexe dans Qdrant avec les métadonnées RBAC.
4. Confirmation à l'écran avec ID du document.

## 4. Consulter mon historique de chat

- Onglet **Historique** → liste des conversations.
- Cliquer sur une conversation pour relire les messages.
- L'historique est limité aux **6 derniers tours** pour la génération
  (pour ne pas saturer le contexte LLM).

## 5. Sécurité — bonnes pratiques utilisateur

- ✅ Utiliser un mot de passe fort (≥ 12 caractères, mix).
- ✅ Ne **jamais** copier-coller un mot de passe ou clé API dans le chat.
- ✅ Si un document devient obsolète, le supprimer (onglet Documents → ⋯ → Supprimer).
- ✅ Signaler tout comportement étrange à l'admin.

## 6. Admin — gestion utilisateurs

### Créer un utilisateur

```text
Onglet Admin → Utilisateurs → Nouveau
```

### Promouvoir un utilisateur en ADMIN ou AUDITOR

```text
Utilisateur → Modifier → Rôle = ADMIN / AUDITOR
```

### Révoquer

```text
Utilisateur → Désactiver (la session JWT existante reste valide jusqu'à
expiration ≈ 1h ; pour une révocation immédiate, voir « Forcer logout »).
```

### Forcer logout d'un utilisateur

```text
Utilisateur → Forcer logout → invalide tous les tokens Sanctum
```

## 7. Auditor — consultation des logs

### Voir les événements bloqués (audit prompt = BLOCKED)

```text
Onglet Audit → Filter action = BLOCKED → période souhaitée
```

### Exporter un rapport conformité

```text
Onglet Audit → Rapport → CSV ou PDF
Période → Génère
```

Le rapport contient les hash de prompt/réponse (pas le contenu brut)
+ user_id + role + score + action + timestamp.

## 8. Limites connues

| Limite | Contournement |
|--------|---------------|
| Latence LLM ~2s | Acceptable pour usage humain |
| Pas de citations dans la réponse | Source URI visible en debug (à exposer en UI v2) |
| Historique max 6 tours | Configurable via `LLM_HISTORY_MAX_TURNS` |
| Pas de MFA | Perspective post-soutenance |
| Pas d'export complet de ses données | Bouton « Mes données » à venir (RGPD) |

## FAQ utilisateur

**Q : Le chatbot voit-il mes documents privés ?**
Non. Le filtre RBAC est appliqué côté Qdrant **avant** que le LLM ne
reçoive le contexte. Un autre USER ne peut pas voir vos documents même
en jouant avec les prompts.

**Q : Mes prompts sont-ils stockés ?**
Non en clair. Seul un **hash sha256** est stocké dans les audit logs.
Le contenu brut est purgé après traitement.

**Q : Que se passe-t-il si je tape un secret par erreur ?**
Le système le détecte (pattern `password`, `api key`, etc.) et bloque
la requête. L'incident est loggé sans le contenu.

**Q : Puis-je supprimer mon compte ?**
Demander à un ADMIN. Procédure RGPD complète en perspective.
