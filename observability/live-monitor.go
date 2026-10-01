// Live Monitor — SecureRAG Hub · k6 + cluster (Go)
// Usage : go run observability/live-monitor.go [secondes]
// RAM : affichée en Mi (Kubernetes natif — ex: "596Mi", "1.2Gi")
// CPU : affichée en m (millicores — ex: "500m")
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

func main() {
	// Durée de monitoring (défaut : 90s, modifiable en arg)
	d := 90
	if len(os. Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil && v > 0 {
			d = v
		}
	}

	fmt.Println("🔴 SecureRag Hub — LIVE MONITOR")
	fmt.Printf("  Durée : %ds · Rafraîchissement : toutes les 2s\n", d)
	fmt.Printf("  Unités : CPU (millicores m) · RAM (Mi Kubernetes native)\n")
	fmt.Println()

	for sec := 0; sec < d; sec += 2 {
		out, err := exec.Command(
			"kubectl", "top", "pod", "-n", "securerag-hub", "--no-headers",
		).Output()
		if err != nil {
			time.Sleep(2 * time.Second)
			continue
		}

		now := time.Now().Format("15:04:05")
		fmt.Printf("  [%s]\n", now)

		for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			if line == "" {
				continue
			}
			f := strings.Fields(line)
			if len(f) < 3 {
				continue
			}
			pod := f[0]

			// Ne garder que les 4 pods IA
			if !strings.Contains(pod, "ollama") && !strings.Contains(pod, "qdrant") &&
				!strings.Contains(pod, "ai-gateway") && !strings.Contains(pod, "secai") {
				continue
			}

			// CPU : colonne en millicores (.. 500m → afficher 500)
			cpu := strings.TrimSuffix(f[1], "m")

			// RAM : kubectl rend déjà en Mi (ex: "596Mi") → PAS DE CONVERSION
			ram := f[2]

			if len(pod) > 38 {
				pod = pod[:38] + "…"
			}
			fmt.Printf("    %-38s | CPU %6s | RAM %8s\n", pod, cpu, ram)
		}

		fmt.Println()
		time.Sleep(2 * time.Second)
	}

	fmt.Println("✅ Monitoring stopped")
}
