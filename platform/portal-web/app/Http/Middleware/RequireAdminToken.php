<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Gate the demo admin pages behind a shared token.
 *
 * Behaviour:
 * - If PORTAL_ADMIN_TOKEN is configured, the X-Admin-Token header must match.
 * - If it is not configured, access is blocked in production and allowed in
 *   local/testing environments (developer convenience).
 */
class RequireAdminToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $expected = (string) config('security.portal_admin_token', '');
        $provided = (string) $request->header('X-Admin-Token', '');

        if ($expected !== '') {
            abort_unless(hash_equals($expected, $provided), 401, 'Authentication required');

            return $next($request);
        }

        abort_if(app()->isProduction(), 401, 'Authentication required');

        return $next($request);
    }
}
