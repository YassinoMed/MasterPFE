<?php

namespace SecureRag\LaravelSecurity\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use SecureRag\LaravelSecurity\Support\SsrfProtectionHelper;
use Symfony\Component\HttpFoundation\Response;

class SsrfProtectionMiddleware
{
    /**
     * Handle an incoming request and check for SSRF parameters or target URLs.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @return mixed
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Check for URL parameters in request payload (e.g. callback_url, target_url, webhook, image_url)
        $urlParameters = ['url', 'target_url', 'callback_url', 'webhook_url', 'image_url', 'redirect_uri'];

        foreach ($urlParameters as $param) {
            if ($request->has($param)) {
                $targetUrl = $request->input($param);
                if (is_string($targetUrl) && !empty($targetUrl)) {
                    try {
                        SsrfProtectionHelper::validateUrl($targetUrl);
                    } catch (\InvalidArgumentException $e) {
                        return response()->json([
                            'error' => 'SSRF_VALIDATION_FAILED',
                            'message' => $e->getMessage(),
                        ], Response::HTTP_FORBIDDEN);
                    }
                }
            }
        }

        return $next($request);
    }
}
