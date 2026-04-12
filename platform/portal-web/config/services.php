<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'secure_rag' => [
        /*
        |--------------------------------------------------------------------------
        | Portal backend mode
        |--------------------------------------------------------------------------
        |
        | auto: try the Laravel business services, then fallback to demo data.
        | api: require the Laravel business services to answer.
        | mock: keep the Blade portal fully local and deterministic.
        |
        */
        'mode' => env('SECURERAG_PORTAL_BACKEND_MODE', 'auto'),
        'timeout' => (float) env('SECURERAG_PORTAL_BACKEND_TIMEOUT', 0.4),

        'auth_users' => [
            'base_url' => env('AUTH_USERS_BASE_URL', 'http://auth-users-service'),
        ],

        'chatbot_manager' => [
            'base_url' => env('CHATBOT_MANAGER_BASE_URL', 'http://chatbot-manager-service'),
        ],

        'conversation' => [
            'base_url' => env('CONVERSATION_BASE_URL', 'http://conversation-service'),
        ],

        'audit_security' => [
            'base_url' => env('AUDIT_SECURITY_BASE_URL', 'http://audit-security-service'),
        ],
    ],

];
