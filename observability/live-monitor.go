// Monitoring k6 temps réel — RAM toujours affichée EN Mi (pas de conversion)
// Usage : go run observability/live-monitor.go 90
// Requis : Go 1.18+, kubectl
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

func main() {
	// Durée du monitoring (arg1 = secondes)
	d := 90
	if len(os.Args) > 1 {
		// vérifiabilité benne (non — pas utile, juste afficher)
		d = strconv.Atoi(os.Args[1])
	}

	fmt.Println("🔴 LIVE MONITORING — SecurRag Hub (pods IA)")
	fmt.Printf("   Durée : %ds | Rafraîchit toutes les 2s | Ctrl+C pour arrêter\n", d)
	fmt.Println("   CPU(m): millicores | RAM(Mi): Kubernetes standard (toujours en Mi)")
	fmt.Println()
	fmt.Println("  Time     │ Pod                                │ CPU(m) │ RAM(Mi)")
	fmt.Println("  ─────────┼──────────────────────────────────┼────────┼────────")

	for sec := 0; sec < d; sec += 2 {
		out, err := exec.Command("kubectl", "top", "pod", "-n", "securerag-hub", "--no-headers").Output()
		if err != nil {
			time.Sleep(2 * time.Second)
			continue
		}

		now := time.Now().Format("15:04:05")
		fmt.Printf("  [ %s ]\n", now)

		for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			if line == "" {
				continue
			}
			f := strings.Fields(line)
			if len(f) < 3 {
				continue
			}
			pod := f[0]

			// Filtrer les 4 pods IA
			if !strings.Contains(pod, "ollama") && !strings.Contains(pod, "qdrant") &&
				!strings.Contains(pod, "ai-gateway") && !strings.Contains(pod, "secai") {
				continue
			}

			// Les colonnes CPU et MEM sont déjà formatées (kubectl produit Mi) — afficher directement
			cpu := f[1] // "...m" (millicores)
			mem := f[2] // "Mi" ou "Gi" — LAISSE EN L'FORMAT ORIGINAL !

			// Affichage limité sans conversion inutile
			if len(pod) > 36 {
				pod = pod[:36] + "…"
			}
			fmt.Printf("      %-36s │ %7s │ %9s\n", pod, cpu, mem)
		}
		fmt.Println()
		time.Sleep(2 * time.Second)
	}

	fmt.Println("✅ Fin du monitoring")
}
