<?php

return [
    'permissions' => [
        'users.view' => ['label' => 'Voir les utilisateurs', 'domain' => 'users'],
        'users.create' => ['label' => 'Creer des utilisateurs', 'domain' => 'users'],
        'users.update' => ['label' => 'Modifier des utilisateurs', 'domain' => 'users'],
        'users.disable' => ['label' => 'Desactiver des utilisateurs', 'domain' => 'users'],
        'roles.view' => ['label' => 'Voir les roles', 'domain' => 'roles'],
        'roles.manage' => ['label' => 'Gerer les roles', 'domain' => 'roles'],
        'security.view' => ['label' => 'Voir les incidents securite', 'domain' => 'security'],
        'chatbots.view' => ['label' => 'Voir les chatbots', 'domain' => 'chatbots'],
        'chatbots.manage' => ['label' => 'Gerer les chatbots', 'domain' => 'chatbots'],
        'conversations.use.rh' => ['label' => 'Utiliser les conversations RH', 'domain' => 'conversations'],
        'conversations.use.it' => ['label' => 'Utiliser les conversations IT', 'domain' => 'conversations'],
    ],

    'roles' => [
        'super-admin' => [
            'label' => 'Super admin',
            'description' => 'Role complet reserve a la soutenance et aux administrateurs globaux.',
            'permissions' => [
                'users.view',
                'users.create',
                'users.update',
                'users.disable',
                'roles.view',
                'roles.manage',
                'security.view',
                'chatbots.view',
                'chatbots.manage',
                'conversations.use.rh',
                'conversations.use.it',
            ],
        ],
        'admin-plateforme' => [
            'label' => 'Admin plateforme',
            'description' => 'Administration utilisateurs, roles et chatbots.',
            'permissions' => [
                'users.view',
                'users.create',
                'users.update',
                'roles.view',
                'chatbots.view',
                'chatbots.manage',
            ],
        ],
        'admin-securite' => [
            'label' => 'Admin securite',
            'description' => 'Supervision securite et consultation RBAC.',
            'permissions' => [
                'users.view',
                'roles.view',
                'security.view',
            ],
        ],
        'user-rh' => [
            'label' => 'Utilisateur RH',
            'description' => 'Acces conversationnel limite au domaine RH.',
            'permissions' => [
                'chatbots.view',
                'conversations.use.rh',
            ],
        ],
        'user-it' => [
            'label' => 'Utilisateur IT',
            'description' => 'Acces conversationnel limite au domaine IT.',
            'permissions' => [
                'chatbots.view',
                'conversations.use.it',
            ],
        ],
    ],
];
