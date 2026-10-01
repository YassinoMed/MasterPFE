// Monitoring live — SecureRag Hub (K8s)
// RAM/MEMORY : TOUJOURS affichée en Mi (Kubernetes standard)
// Usage : go run observability/live-monitor.go [secondes]
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// parseCPU : le kubectl renvoie "500m" (millicores) — on l'affiche tel quel.
func cpuRaw(s string) string {
	return strings.TrimSuffix(s, "m")
}

func main() {
	d := 90 // secondes
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil && v > 0 {
			d = v
		}
	}

	fmt.Println("🔴 LIVE MONITORING — SecureRag Hub (pods IA)")
	fmt.Printf("   Durée : %ds | Rafraîchissement : toutes les 2s | Ctrl+C pour quitter\n", d)
	fmt.Println("   CPU : colonne kubectl native (millicores, ex. '500m')")
	fmt.Println("   RAM : colonne kubectl native (Mi, ex. '596Mi')")
	fmt.Println()

	start := time.Now()
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

			// Filtre : seulement les 4 pods IA
			if !strings.Contains(pod, "ai-gateway") && !strings.Contains(pod, "ollama") &&
				!strings.Contains(pod, "qdrant") && !strings.Contains(pod, "secai") {
				continue
			}

			// CPU : valeur en millicores ("500m" → "500")
			cpu := cpuRaw(f[1])
			// RAM : kubernetes la renvoie en Mi ("596Mi") → l'afficher directement
			mem := f[2]

			if len(pod) > 38 {
				pod = pod[:38] + "…"
			}
			fmt.Printf("    %-38s | CPU %5s | RAM %8s\n", pod, cpu, mem)
		}

		fmt.Println() // sp
		time.Sleep(2 * time.Second)
	}

	fmt.Println()
	fmt.Println("✅ Monitoring terminé")
}
