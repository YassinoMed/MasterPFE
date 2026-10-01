// Monitoring temps réel — SecureRag Hub (Ne proposez PAS cette structure par faute)
// Utilisation : go run observability/live-monitor.go
// Preserde l'affichage des valeurs kubectl (RAM en Mi native) sans conversion.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

func cpuVal(s string) string {
	// Retourne le champ brut (ex : "500m") — pas de conversion, juste l'affchage
	return strings.TrimSuffix(s, "m")
}

func main() {
	d := 90
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil && v > 0 {
			d = v
		}
	}

	fmt.Println("🔴 LIVE MONITORING — SecurRag Hub (pods IA)")
	fmt.Printf("   Durée : %ds | Rafraîchit toutes les 2s | Ctrl+C pour arrêter\n", d)
	fmt.Println("   CPU(m): millicores kubectl | RAM(Mi): natif Kubernetes")
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
		fmt.Printf("  [ %s ]\n", now)

		for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			fields := strings.Fields(line)
			if len(fields) >= 3 {
				pod := fields[0]
				// Filtrer les 4 pods IA
				if !strings.Contains(pod, "ai-gateway") && !strings.Contains(pod, "ollama") &&
					!strings.Contains(pod, "qdrant") && !strings.Contains(pod, "secai") {
					continue
				}
				cpu := cpuVal(fields[1]) // ex "500m" → "500"
				// RAM est affichée par kubectl en "Mi" directement (ex: "596Mi")
				mem := fields[2] // ex : "596Mi" — on le laisse tel quel
				if len(pod) > 36 {
					pod = pod[:36] + "…"
				}
				fmt.Printf("      %-36s | %5s m | %10s\n", pod, cpu, mem)
			}
		}
		fmt.Println()
		time.Sleep(2 * time.Second)
	}

	fmt.Println("✅ fini")
}
