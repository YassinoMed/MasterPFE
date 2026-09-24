<?php

return [
    // Middleware token guarding the demo admin pages.
    // Leave empty only in purely local/demo contexts.
    'portal_admin_token' => env('PORTAL_ADMIN_TOKEN', ''),
];
