<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>SecureRAG Hub Portal</title>
    <style>
        :root {
            color-scheme: light;
            --bg: #f3f6fb;
            --panel: #ffffff;
            --text: #10233f;
            --muted: #5f718d;
            --border: #d8e0eb;
            --primary: #163e73;
            --primary-soft: #eaf1fb;
            --success: #1d7a53;
            --warning: #ad6a00;
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
            background:
                radial-gradient(circle at top left, #dde8f7 0, transparent 28rem),
                linear-gradient(180deg, #f7f9fc 0%, var(--bg) 100%);
            color: var(--text);
        }

        .shell {
            max-width: 1180px;
            margin: 0 auto;
            padding: 40px 24px 64px;
        }

        .hero {
            display: grid;
            grid-template-columns: 1.4fr 1fr;
            gap: 24px;
            align-items: stretch;
        }

        .panel {
            background: rgba(255, 255, 255, 0.88);
            border: 1px solid var(--border);
            border-radius: 24px;
            box-shadow: 0 18px 40px rgba(19, 44, 84, 0.08);
            backdrop-filter: blur(6px);
        }

        .hero-copy {
            padding: 32px;
        }

        .eyebrow {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            border-radius: 999px;
            background: var(--primary-soft);
            color: var(--primary);
            font-size: 12px;
            font-weight: 700;
            letter-spacing: 0.04em;
            text-transform: uppercase;
        }

        h1 {
            margin: 18px 0 14px;
            font-size: clamp(2.1rem, 4vw, 3.5rem);
            line-height: 1.05;
        }

        p {
            margin: 0;
            color: var(--muted);
            line-height: 1.7;
            font-size: 1rem;
        }

        .hero-actions,
        .grid {
            display: grid;
            gap: 16px;
        }

        .hero-actions {
            margin-top: 24px;
            grid-template-columns: repeat(2, minmax(0, 1fr));
        }

        .action-card,
        .metric,
        .module,
        .endpoint {
            border: 1px solid var(--border);
            border-radius: 18px;
            background: #fff;
        }

        .action-card,
        .metric,
        .module,
        .endpoint {
            padding: 18px;
        }

        .action-card strong,
        .module strong,
        .endpoint strong {
            display: block;
            margin-bottom: 6px;
            font-size: 0.98rem;
        }

        .status-board {
            padding: 24px;
            display: grid;
            gap: 16px;
        }

        .metric-grid,
        .module-grid,
        .endpoint-grid {
            display: grid;
            gap: 16px;
        }

        .metric-grid {
            grid-template-columns: repeat(2, minmax(0, 1fr));
        }

        .module-grid,
        .endpoint-grid {
            grid-template-columns: repeat(3, minmax(0, 1fr));
        }

        .metric .value {
            margin-top: 8px;
            font-size: 1.8rem;
            font-weight: 700;
            color: var(--primary);
        }

        .label {
            color: var(--muted);
            font-size: 0.9rem;
        }

        .status-pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            border-radius: 999px;
            font-size: 0.9rem;
            font-weight: 700;
        }

        .status-pill.success {
            background: rgba(29, 122, 83, 0.12);
            color: var(--success);
        }

        .status-pill.warning {
            background: rgba(173, 106, 0, 0.12);
            color: var(--warning);
        }

        .section {
            margin-top: 24px;
        }

        .section h2 {
            margin: 0 0 14px;
            font-size: 1.15rem;
        }

        code {
            font-family: "IBM Plex Mono", "SFMono-Regular", monospace;
            font-size: 0.92rem;
            color: var(--primary);
        }

        @media (max-width: 900px) {
            .hero,
            .module-grid,
            .endpoint-grid,
            .hero-actions,
            .metric-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <main class="shell">
        <section class="hero">
            <div class="panel hero-copy">
                <span class="eyebrow">SecureRAG Hub · Portail User/Admin</span>
                <h1>Plateforme Laravel bootstrappee et prete pour l'integration metier.</h1>
                <p>
                    Ce portail centralise l'experience utilisateur et l'administration de SecureRAG Hub :
                    acces aux chatbots metiers, supervision securite, gouvernance des acces et lecture
                    des indicateurs DevSecOps. La couche IA reste abstraite via des integrations futures.
                </p>

                <div class="hero-actions">
                    <div class="action-card">
                        <strong>Portail utilisateur</strong>
                        <span class="label">Catalogue des chatbots, conversation, historique, profil.</span>
                    </div>
                    <div class="action-card">
                        <strong>Console d'administration</strong>
                        <span class="label">Utilisateurs, RBAC, chatbots, audits, supervision technique.</span>
                    </div>
                    <div class="action-card">
                        <strong>Surface securite</strong>
                        <span class="label">Reponses bloquees, incidents, scores AI-Sec, traces d'audit.</span>
                    </div>
                    <div class="action-card">
                        <strong>Observabilite DevSecOps</strong>
                        <span class="label">Builds, scans, SBOM, signatures, statut des services.</span>
                    </div>
                </div>
            </div>

            <aside class="panel status-board">
                <span class="status-pill success">Etat applicatif: en ligne</span>
                <div class="metric-grid">
                    <div class="metric">
                        <div class="label">Framework</div>
                        <div class="value">Laravel 12</div>
                    </div>
                    <div class="metric">
                        <div class="label">Mode</div>
                        <div class="value">Bootstrap</div>
                    </div>
                    <div class="metric">
                        <div class="label">Surface</div>
                        <div class="value">User + Admin</div>
                    </div>
                    <div class="metric">
                        <div class="label">API locale</div>
                        <div class="value">/api/v1</div>
                    </div>
                </div>

                <div class="section">
                    <h2>Disponibilite immediate</h2>
                    <span class="status-pill warning">Integrations IA non implementees, contrats prevus</span>
                </div>
            </aside>
        </section>

        <section class="section">
            <h2>Modules prets a etre relies</h2>
            <div class="module-grid">
                <div class="module">
                    <strong>Auth Users</strong>
                    <span class="label">Authentification, profils, roles, permissions et sessions.</span>
                </div>
                <div class="module">
                    <strong>Chatbot Manager</strong>
                    <span class="label">Catalogue des chatbots, domaines, prompts et regles d'acces.</span>
                </div>
                <div class="module">
                    <strong>Conversation Service</strong>
                    <span class="label">Historique, statuts de reponse et adaptateurs IA mockes.</span>
                </div>
                <div class="module">
                    <strong>Audit Security</strong>
                    <span class="label">Logs, incidents, reponses bloquees et evenements de securite.</span>
                </div>
                <div class="module">
                    <strong>Vue DevSecOps</strong>
                    <span class="label">Pipeline, deploiement, SBOM, signatures et sante plateforme.</span>
                </div>
                <div class="module">
                    <strong>RBAC B2B</strong>
                    <span class="label">Visibilite pilotee par role pour RH, IT, securite et admins.</span>
                </div>
            </div>
        </section>

        <section class="section">
            <h2>Endpoints de bootstrap</h2>
            <div class="endpoint-grid">
                <div class="endpoint">
                    <strong>Health web</strong>
                    <code>/health</code>
                </div>
                <div class="endpoint">
                    <strong>Health interne</strong>
                    <code>/api/internal/health</code>
                </div>
                <div class="endpoint">
                    <strong>Resume plateforme</strong>
                    <code>/api/v1/platform/summary</code>
                </div>
            </div>
        </section>
    </main>
</body>
</html>
