<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title }} - SecureRAG Hub</title>
    <style>
        :root {
            --bg: #eef3f8;
            --panel: #ffffff;
            --ink: #10243f;
            --muted: #60728c;
            --line: #d6e0ec;
            --brand: #174a7c;
            --brand-2: #2f7d68;
            --warning: #a96500;
            --danger: #a83f3f;
        }

        * { box-sizing: border-box; }

        body {
            margin: 0;
            font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
            color: var(--ink);
            background:
                radial-gradient(circle at 12% 12%, rgba(47, 125, 104, 0.18), transparent 28rem),
                linear-gradient(135deg, #f8fbff 0%, var(--bg) 100%);
        }

        a { color: inherit; text-decoration: none; }

        .layout {
            display: grid;
            grid-template-columns: 280px 1fr;
            min-height: 100vh;
        }

        .sidebar {
            padding: 28px;
            background: rgba(255, 255, 255, 0.74);
            border-right: 1px solid var(--line);
            backdrop-filter: blur(10px);
        }

        .brand {
            display: grid;
            gap: 8px;
            margin-bottom: 28px;
        }

        .brand strong { font-size: 1.3rem; }
        .brand span { color: var(--muted); font-size: 0.92rem; }

        .nav {
            display: grid;
            gap: 10px;
        }

        .nav a {
            padding: 12px 14px;
            border: 1px solid transparent;
            border-radius: 14px;
            color: var(--muted);
            font-weight: 700;
        }

        .nav a.active,
        .nav a:hover {
            color: var(--brand);
            background: #fff;
            border-color: var(--line);
            box-shadow: 0 10px 24px rgba(16, 36, 63, 0.06);
        }

        .content {
            padding: 36px;
        }

        .topbar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 16px;
            margin-bottom: 24px;
        }

        h1 {
            margin: 0;
            font-size: clamp(1.8rem, 4vw, 2.8rem);
        }

        .subtitle {
            margin: 8px 0 0;
            color: var(--muted);
        }

        .pill {
            display: inline-flex;
            align-items: center;
            padding: 8px 12px;
            border-radius: 999px;
            background: #e9f4ef;
            color: var(--brand-2);
            font-weight: 800;
            font-size: 0.88rem;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 16px;
            margin-bottom: 18px;
        }

        .grid.two { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .grid.three { grid-template-columns: repeat(3, minmax(0, 1fr)); }

        .card {
            background: rgba(255, 255, 255, 0.9);
            border: 1px solid var(--line);
            border-radius: 22px;
            padding: 20px;
            box-shadow: 0 18px 36px rgba(16, 36, 63, 0.07);
        }

        .card h2, .card h3 {
            margin: 0 0 12px;
        }

        .actions {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin: 0 0 16px;
        }

        .button {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-height: 40px;
            padding: 10px 14px;
            border: 1px solid var(--line);
            border-radius: 12px;
            background: var(--brand);
            color: #fff;
            font-weight: 800;
            cursor: pointer;
        }

        .button.secondary {
            background: #fff;
            color: var(--brand);
        }

        .search {
            width: min(100%, 360px);
            min-height: 42px;
            padding: 10px 12px;
            border: 1px solid var(--line);
            border-radius: 12px;
            color: var(--ink);
            background: #fff;
        }

        .mock-form {
            display: grid;
            grid-template-columns: repeat(2, minmax(0, 1fr));
            gap: 12px;
            margin-top: 14px;
        }

        .mock-form label {
            display: grid;
            gap: 6px;
            color: var(--muted);
            font-weight: 700;
        }

        .mock-form input,
        .mock-form select,
        .mock-form textarea {
            width: 100%;
            min-height: 42px;
            padding: 10px 12px;
            border: 1px solid var(--line);
            border-radius: 12px;
            font: inherit;
        }

        .mock-form textarea {
            min-height: 98px;
            resize: vertical;
        }

        .mock-form .full {
            grid-column: 1 / -1;
        }

        .demo-output {
            display: none;
            margin-top: 12px;
            padding: 12px;
            border-radius: 14px;
            background: #eef7f2;
            color: var(--brand-2);
            font-weight: 800;
        }

        .empty-row {
            display: none;
            color: var(--muted);
            padding: 12px 0;
        }

        .metric-value {
            display: block;
            margin-top: 8px;
            font-size: 2rem;
            font-weight: 900;
            color: var(--brand);
        }

        .muted {
            color: var(--muted);
            line-height: 1.65;
        }

        .table {
            width: 100%;
            border-collapse: collapse;
        }

        .table th,
        .table td {
            padding: 12px;
            border-bottom: 1px solid var(--line);
            text-align: left;
            vertical-align: top;
        }

        .table th {
            color: var(--muted);
            font-size: 0.82rem;
            text-transform: uppercase;
            letter-spacing: 0.06em;
        }

        .status {
            display: inline-flex;
            padding: 6px 10px;
            border-radius: 999px;
            background: #eef4fb;
            color: var(--brand);
            font-weight: 800;
            font-size: 0.82rem;
        }

        .status.watch,
        .status.medium,
        .status.filtered,
        .status.partial {
            background: #fff4df;
            color: var(--warning);
        }

        .status.low,
        .status.safe,
        .status.green,
        .status.ok,
        .status.published,
        .status.active {
            background: #e8f5ef;
            color: var(--brand-2);
        }

        .status.restricted,
        .status.triage {
            background: #fff0f0;
            color: var(--danger);
        }

        .message {
            display: grid;
            gap: 4px;
            margin-bottom: 12px;
            padding: 14px;
            border-radius: 16px;
            background: #f7fafc;
            border: 1px solid var(--line);
        }

        .message.assistant { background: #eef7f2; }
        .message.security { background: #fff7e8; }

        @media (max-width: 980px) {
            .layout { grid-template-columns: 1fr; }
            .sidebar { border-right: 0; border-bottom: 1px solid var(--line); }
            .grid, .grid.two, .grid.three { grid-template-columns: 1fr; }
            .mock-form { grid-template-columns: 1fr; }
            .content { padding: 24px; }
        }
    </style>
</head>
<body>
    <main class="layout">
        <aside class="sidebar">
            <div class="brand">
                <strong>SecureRAG Hub</strong>
                <span>Portail user/admin - mode demo</span>
            </div>
            <nav class="nav">
                <a class="{{ $activePage === 'user' ? 'active' : '' }}" href="{{ route('portal.user') }}">Utilisateur</a>
                <a class="{{ $activePage === 'admin' ? 'active' : '' }}" href="{{ route('portal.admin') }}">Administration</a>
                <a class="{{ $activePage === 'users' ? 'active' : '' }}" href="{{ route('portal.users') }}">Utilisateurs</a>
                <a class="{{ $activePage === 'roles' ? 'active' : '' }}" href="{{ route('portal.roles') }}">Roles</a>
                <a class="{{ $activePage === 'chatbots' ? 'active' : '' }}" href="{{ route('portal.chatbots') }}">Chatbots</a>
                <a class="{{ $activePage === 'chat' ? 'active' : '' }}" href="{{ route('portal.chat') }}">Conversation</a>
                <a class="{{ $activePage === 'history' ? 'active' : '' }}" href="{{ route('portal.history') }}">Historique</a>
                <a class="{{ $activePage === 'security' ? 'active' : '' }}" href="{{ route('portal.security') }}">Securite</a>
                <a class="{{ $activePage === 'devsecops' ? 'active' : '' }}" href="{{ route('portal.devsecops') }}">DevSecOps</a>
            </nav>
        </aside>

        <section class="content">
            <div class="topbar">
                <div>
                    <h1>{{ $title }}</h1>
                    <p class="subtitle">Donnees mockees, adapters prets, aucune intelligence IA reelle embarquee.</p>
                </div>
                <span class="pill">scenario demo</span>
            </div>

            @if ($activePage === 'user')
                <section class="grid">
                    @foreach ($data['metrics'] as $metric)
                        <article class="card">
                            <span class="muted">{{ $metric['label'] }}</span>
                            <strong class="metric-value">{{ $metric['value'] }}</strong>
                            <span class="muted">{{ $metric['trend'] }}</span>
                        </article>
                    @endforeach
                </section>

                <section class="grid two">
                    <article class="card">
                        <h2>Chatbots disponibles</h2>
                        <table class="table">
                            <tbody>
                            @foreach ($data['chatbots'] as $chatbot)
                                <tr>
                                    <td><strong>{{ $chatbot['name'] }}</strong><br><span class="muted">{{ $chatbot['domain'] }}</span></td>
                                    <td><span class="status {{ $chatbot['status'] }}">{{ $chatbot['status'] }}</span></td>
                                </tr>
                            @endforeach
                            </tbody>
                        </table>
                    </article>
                    <article class="card">
                        <h2>Historique recent</h2>
                        <table class="table">
                            <tbody>
                            @foreach ($data['recentConversations'] as $conversation)
                                <tr>
                                    <td><strong>{{ $conversation['title'] }}</strong><br><span class="muted">{{ $conversation['chatbot'] }}</span></td>
                                    <td><span class="status {{ $conversation['status'] }}">{{ $conversation['status'] }}</span></td>
                                </tr>
                            @endforeach
                            </tbody>
                        </table>
                    </article>
                </section>
            @endif

            @if ($activePage === 'admin')
                <section class="grid">
                    @foreach ($data['metrics'] as $metric)
                        <article class="card">
                            <span class="muted">{{ $metric['label'] }}</span>
                            <strong class="metric-value">{{ $metric['value'] }}</strong>
                            <span class="status {{ $metric['status'] }}">{{ $metric['status'] }}</span>
                        </article>
                    @endforeach
                </section>

                <section class="grid two">
                    <article class="card">
                        <h2>Utilisateurs</h2>
                        <table class="table">
                            <thead><tr><th>Nom</th><th>Role</th><th>Statut</th></tr></thead>
                            <tbody>
                            @foreach ($data['users'] as $user)
                                <tr>
                                    <td><strong>{{ $user['name'] }}</strong><br><span class="muted">{{ $user['email'] }}</span></td>
                                    <td>{{ $user['role'] }}</td>
                                    <td><span class="status {{ $user['status'] }}">{{ $user['status'] }}</span></td>
                                </tr>
                            @endforeach
                            </tbody>
                        </table>
                    </article>
                    <article class="card">
                        <h2>Roles RBAC</h2>
                        @foreach ($data['roles'] as $role)
                            <p><strong>{{ $role['name'] }}</strong></p>
                            <p class="muted">{{ implode(', ', $role['permissions']) }}</p>
                        @endforeach
                    </article>
                </section>
            @endif

            @if ($activePage === 'users')
                <article class="card">
                    <div class="topbar">
                        <div>
                            <h2>Annuaire utilisateurs</h2>
                            <p class="muted">Gestion demonstrative des comptes, roles et equipes. Aucun secret ni identifiant reel.</p>
                        </div>
                        <span class="pill">RBAC mock</span>
                    </div>
                    <div class="actions">
                        <input class="search js-table-filter" data-target="users-table" type="search" placeholder="Filtrer par nom, role ou equipe">
                        <button class="button secondary js-demo-action" data-message="Invitation utilisateur simulee. Le backend metier sera ajoute dans la phase microservices Laravel.">Simuler invitation</button>
                    </div>
                    <table class="table" id="users-table">
                        <thead><tr><th>Utilisateur</th><th>Equipe</th><th>Role</th><th>Derniere connexion</th><th>Statut</th></tr></thead>
                        <tbody>
                        @foreach ($data['users'] as $user)
                            <tr>
                                <td><strong>{{ $user['name'] }}</strong><br><span class="muted">{{ $user['email'] }}</span></td>
                                <td>{{ $user['team'] }}</td>
                                <td>{{ $user['role'] }}</td>
                                <td>{{ $user['lastLogin'] }}</td>
                                <td><span class="status {{ $user['status'] }}">{{ $user['status'] }}</span></td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                    <p class="empty-row" data-empty-for="users-table">Aucun utilisateur ne correspond au filtre.</p>
                    <div class="demo-output" id="demo-output"></div>
                </article>
            @endif

            @if ($activePage === 'roles')
                <section class="grid two">
                    @foreach ($data['roles'] as $role)
                        <article class="card">
                            <div class="topbar">
                                <div>
                                    <h2>{{ $role['name'] }}</h2>
                                    <p class="muted">{{ $role['description'] }}</p>
                                </div>
                                <span class="pill">{{ $role['users'] }} users</span>
                            </div>
                            <p><strong>Permissions</strong></p>
                            <p class="muted">{{ implode(', ', $role['permissions']) }}</p>
                        </article>
                    @endforeach
                </section>
                <article class="card">
                    <h2>Creation de role demo</h2>
                    <p class="muted">Formulaire non persistant pour soutenir le parcours RBAC sans exposer de backend incomplet.</p>
                    <form class="mock-form js-mock-form">
                        <label>Nom du role
                            <input name="role" value="compliance_viewer">
                        </label>
                        <label>Portee
                            <select name="scope">
                                <option>tenant-demo</option>
                                <option>workspace-risques</option>
                            </select>
                        </label>
                        <label class="full">Permissions
                            <textarea name="permissions">view-audit, export-evidence</textarea>
                        </label>
                        <div class="full">
                            <button class="button" type="submit">Simuler creation</button>
                        </div>
                    </form>
                    <div class="demo-output"></div>
                </article>
            @endif

            @if ($activePage === 'chatbots')
                <article class="card">
                    <div class="topbar">
                        <div>
                            <h2>Catalogue chatbots</h2>
                            <p class="muted">Configuration metier mockee. Le mode IA reel reste hors perimetre demo.</p>
                        </div>
                        <span class="pill">mock adapters</span>
                    </div>
                    <div class="actions">
                        <input class="search js-table-filter" data-target="chatbots-table" type="search" placeholder="Filtrer par domaine, proprietaire ou statut">
                        <button class="button secondary js-demo-action" data-message="Publication chatbot simulee. Le deploiement reel passera par le service chatbot-manager.">Simuler publication</button>
                    </div>
                    <table class="table" id="chatbots-table">
                        <thead><tr><th>Chatbot</th><th>Proprietaire</th><th>Guardrail</th><th>Mode</th><th>Statut</th></tr></thead>
                        <tbody>
                        @foreach ($data['chatbots'] as $chatbot)
                            <tr>
                                <td><strong>{{ $chatbot['name'] }}</strong><br><span class="muted">{{ $chatbot['domain'] }} - {{ $chatbot['sensitivity'] }}</span></td>
                                <td>{{ $chatbot['owner'] }}</td>
                                <td>{{ $chatbot['guardrail'] }}</td>
                                <td>{{ $chatbot['modelMode'] }} / T={{ $chatbot['temperature'] }}</td>
                                <td><span class="status {{ $chatbot['status'] }}">{{ $chatbot['status'] }}</span></td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                    <p class="empty-row" data-empty-for="chatbots-table">Aucun chatbot ne correspond au filtre.</p>
                    <div class="demo-output" id="chatbot-output"></div>
                </article>
            @endif

            @if ($activePage === 'chat')
                <section class="grid two">
                    <article class="card">
                        <h2>{{ $data['conversation']['title'] }}</h2>
                        <p class="muted">{{ $data['conversation']['chatbot'] }} - {{ $data['conversation']['id'] }}</p>
                        @foreach ($data['messages'] as $message)
                            <div class="message {{ $message['sender'] }}">
                                <strong>{{ $message['sender'] }} - {{ $message['time'] }}</strong>
                                <span>{{ $message['body'] }}</span>
                            </div>
                        @endforeach
                    </article>
                    <article class="card">
                        <h2>Sources mockees</h2>
                        @foreach ($data['sources'] as $source)
                            <p><strong>{{ $source['title'] }}</strong></p>
                            <p class="muted">Confiance: {{ $source['confidence'] }}</p>
                        @endforeach
                    </article>
                </section>
            @endif

            @if ($activePage === 'history')
                <article class="card">
                    <div class="topbar">
                        <div>
                            <h2>Historique des conversations</h2>
                            <p class="muted">Traçabilite demo des conversations et statuts de controle.</p>
                        </div>
                        <span class="pill">audit-ready</span>
                    </div>
                    <div class="actions">
                        <input class="search js-table-filter" data-target="history-table" type="search" placeholder="Filtrer par utilisateur, chatbot ou statut">
                        <button class="button secondary js-demo-action" data-message="Export CSV simule. Le fichier reel sera produit par conversation-service.">Simuler export</button>
                    </div>
                    <table class="table" id="history-table">
                        <thead><tr><th>Conversation</th><th>Utilisateur</th><th>Chatbot</th><th>Messages</th><th>Controle</th><th>MAJ</th></tr></thead>
                        <tbody>
                        @foreach ($data['history'] as $item)
                            <tr>
                                <td><strong>{{ $item['title'] }}</strong><br><span class="muted">{{ $item['id'] }}</span></td>
                                <td>{{ $item['user'] }}</td>
                                <td>{{ $item['chatbot'] }}</td>
                                <td>{{ $item['messages'] }}</td>
                                <td><span class="status {{ $item['securityStatus'] }}">{{ $item['securityStatus'] }}</span></td>
                                <td>{{ $item['updatedAt'] }}</td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                    <p class="empty-row" data-empty-for="history-table">Aucune conversation ne correspond au filtre.</p>
                    <div class="demo-output" id="history-output"></div>
                </article>
            @endif

            @if ($activePage === 'security')
                <section class="grid three">
                    @foreach ($data['summary'] as $metric)
                        <article class="card">
                            <span class="muted">{{ $metric['label'] }}</span>
                            <strong class="metric-value">{{ $metric['value'] }}</strong>
                        </article>
                    @endforeach
                </section>
                <article class="card">
                    <h2>Incidents securite</h2>
                    <table class="table">
                        <thead><tr><th>ID</th><th>Type</th><th>Service</th><th>Statut</th></tr></thead>
                        <tbody>
                        @foreach ($data['incidents'] as $incident)
                            <tr>
                                <td><strong>{{ $incident['id'] }}</strong><br><span class="status {{ $incident['severity'] }}">{{ $incident['severity'] }}</span></td>
                                <td>{{ $incident['type'] }}</td>
                                <td>{{ $incident['service'] }}</td>
                                <td><span class="status {{ $incident['status'] }}">{{ $incident['status'] }}</span></td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                </article>
            @endif

            @if ($activePage === 'devsecops')
                <article class="card">
                    <h2>Pipeline officiel</h2>
                    <p class="muted">Autorite: {{ $data['authority'] }} - Scenario: {{ $data['officialScenario'] }} - GitHub Actions: {{ $data['githubActions'] }}</p>
                    <table class="table">
                        <thead><tr><th>Etape</th><th>Statut</th><th>Preuve</th></tr></thead>
                        <tbody>
                        @foreach ($data['stages'] as $stage)
                            <tr>
                                <td><strong>{{ $stage['name'] }}</strong></td>
                                <td><span class="status {{ $stage['status'] }}">{{ $stage['status'] }}</span></td>
                                <td>{{ $stage['evidence'] }}</td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                </article>
            @endif
        </section>
    </main>
    <script>
        document.querySelectorAll('.js-table-filter').forEach((input) => {
            input.addEventListener('input', () => {
                const table = document.getElementById(input.dataset.target);
                if (!table) {
                    return;
                }

                const term = input.value.trim().toLowerCase();
                let visibleRows = 0;

                table.querySelectorAll('tbody tr').forEach((row) => {
                    const matches = row.textContent.toLowerCase().includes(term);
                    row.style.display = matches ? '' : 'none';
                    visibleRows += matches ? 1 : 0;
                });

                const empty = document.querySelector(`[data-empty-for="${input.dataset.target}"]`);
                if (empty) {
                    empty.style.display = visibleRows === 0 ? 'block' : 'none';
                }
            });
        });

        document.querySelectorAll('.js-demo-action').forEach((button) => {
            button.addEventListener('click', () => {
                const output = button.closest('.card')?.querySelector('.demo-output');
                if (!output) {
                    return;
                }

                output.textContent = button.dataset.message || 'Action demo executee.';
                output.style.display = 'block';
            });
        });

        document.querySelectorAll('.js-mock-form').forEach((form) => {
            form.addEventListener('submit', (event) => {
                event.preventDefault();

                const output = form.closest('.card')?.querySelector('.demo-output');
                if (!output) {
                    return;
                }

                output.textContent = 'Action simulee avec succes. Aucune donnee persistante ni secret reel utilise.';
                output.style.display = 'block';
            });
        });
    </script>
</body>
</html>
