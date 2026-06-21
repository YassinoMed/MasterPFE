<?php

namespace SecureRag\LaravelSecurity\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Prometheus\CollectorRegistry;
use Prometheus\Storage\InMemory;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Queue;
use Illuminate\Queue\Events\JobProcessed;
use Illuminate\Queue\Events\JobFailed;

class PrometheusMetricsMiddleware
{
    private static ?CollectorRegistry $registry = null;

    /**
     * Obtient le registre des métriques Prometheus avec adaptateurs résilients.
     */
    public static function getRegistry(): CollectorRegistry
    {
        if (self::$registry === null) {
            $storage = null;
            if (extension_loaded('apcu') && ini_get('apc.enabled')) {
                if (class_exists('\Prometheus\Storage\APCu')) {
                    $storage = new \Prometheus\Storage\APCu();
                } else {
                    $storage = new \Prometheus\Storage\APC();
                }
            } elseif (class_exists('Redis') && config('database.redis.default')) {
                try {
                    $storage = new \Prometheus\Storage\Redis([
                        'host' => config('database.redis.default.host', '127.0.0.1'),
                        'port' => config('database.redis.default.port', 6379),
                        'password' => config('database.redis.default.password', null),
                        'timeout' => 0.1,
                    ]);
                } catch (\Exception $e) {
                    $storage = new InMemory();
                }
            } else {
                $storage = new InMemory();
            }
            self::$registry = new CollectorRegistry($storage);
        }
        return self::$registry;
    }

    /**
     * Enregistre le suivi des jobs de la file d'attente (Queue).
     */
    public static function bootQueueTracking(): void
    {
        try {
            Queue::after(function (JobProcessed $event) {
                $registry = self::getRegistry();
                $counter = $registry->getOrRegisterCounter(
                    'laravel',
                    'queue_jobs_total',
                    'Total des jobs Laravel executes',
                    ['queue', 'status']
                );
                $counter->inc([$event->job->getQueue(), 'success']);
            });

            Queue::failing(function (JobFailed $event) {
                $registry = self::getRegistry();
                $counter = $registry->getOrRegisterCounter(
                    'laravel',
                    'queue_jobs_total',
                    'Total des jobs Laravel executes',
                    ['queue', 'status']
                );
                $counter->inc([$event->job->getQueue(), 'failed']);
            });
        } catch (\Exception $e) {
            // Évite de bloquer l'application si l'initialisation échoue
        }
    }

    /**
     * Enregistre la route /metrics avec restriction IP.
     */
    public static function registerRoutes(): void
    {
        Route::get('/metrics', function (Request $request) {
            $allowedCidrs = [
                '10.0.0.0/8',
                '127.0.0.1/32',
                '10.244.0.0/16',
                '172.16.0.0/12',
                '192.168.0.0/16'
            ];
            $ip = $request->ip();

            $isAllowed = false;
            foreach ($allowedCidrs as $cidr) {
                if (strpos($cidr, '/') === false) {
                    $cidr .= '/32';
                }
                list($subnet, $bits) = explode('/', $cidr);
                $ip_dec = ip2long($ip);
                $subnet_dec = ip2long($subnet);
                if ($ip_dec !== false && $subnet_dec !== false) {
                    $mask = ~((1 << (32 - $bits)) - 1);
                    if (($ip_dec & $mask) === ($subnet_dec & $mask)) {
                        $isAllowed = true;
                        break;
                    }
                }
            }

            if (!$isAllowed) {
                abort(403, 'Forbidden');
            }

            $renderer = new \Prometheus\RenderTextFormat();
            $registry = self::getRegistry();
            $result = $renderer->render($registry->getMetricFamiliesStore());

            return response($result, 200, ['Content-Type' => \Prometheus\RenderTextFormat::MIME_TYPE]);
        });
    }

    /**
     * Gère la requête HTTP entrante.
     */
    public function handle(Request $request, Closure $next)
    {
        $startTime = microtime(true);

        $response = $next($request);

        $duration = microtime(true) - $startTime;

        try {
            $registry = self::getRegistry();
            $routeName = Route::currentRouteName() ?? $request->path();
            $method = $request->method();
            $status = $response->getStatusCode();

            // Incrémente le compteur de requêtes
            $counter = $registry->getOrRegisterCounter(
                'laravel',
                'http_requests_total',
                'Trafic HTTP total',
                ['method', 'route', 'status']
            );
            $counter->inc([$method, $routeName, $status]);

            // Enregistre la durée de requête
            $histogram = $registry->getOrRegisterHistogram(
                'laravel',
                'http_request_duration_seconds',
                'Duree des requetes HTTP en secondes',
                ['route']
            );
            $histogram->observe($duration, [$routeName]);

            // Enregistre les connexions SQL actives dans le pool
            $dbConnectionsGauge = $registry->getOrRegisterGauge(
                'laravel',
                'db_connections_active',
                'Connexions de base de donnees actives',
                []
            );

            $activeConnections = 0;
            try {
                $pdo = DB::connection()->getPdo();
                if ($pdo) {
                    $activeConnections = 1;
                }
            } catch (\Exception $e) {
                // Ignore si PDO n'est pas instancié
            }
            $dbConnectionsGauge->set($activeConnections);
        } catch (\Exception $e) {
            // Ignore les erreurs de monitoring pour préserver le flux applicatif
        }

        return $response;
    }
}
