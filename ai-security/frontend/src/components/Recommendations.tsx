import React from 'react'
import {
  Card,
  CardContent,
  Typography,
  Box,
  Grid,
  Chip,
  Paper,
  Button
} from '@mui/material'
import {
  Security as SecurityIcon,
  Launch as LaunchIcon,
  AutoAwesome as SparkIcon
} from '@mui/icons-material'

export default function Recommendations() {
  const recommendations = [
    {
      id: 1,
      title: "Isoler le conteneur 'portal-web' compromis",
      type: "Runtime / Tetragon",
      severity: "CRITICAL",
      findings: "Un shell interactif non autorisé (/bin/sh) a été exécuté dans le pod de production.",
      action: "Appliquer la NetworkPolicy d'isolement stricte pour couper l'accès réseau sortant du pod compromis.",
      remediationCmd: "kubectl label pod -l app.kubernetes.io/name=portal-web security=isolated -n securerag-hub"
    },
    {
      id: 2,
      title: "Verrouiller le système de fichiers racine en lecture seule",
      type: "IaC / Checkov",
      severity: "HIGH",
      findings: "Les conteneurs de l'application s'exécutent avec des systèmes de fichiers racine en écriture (readOnlyRootFilesystem=false).",
      action: "Modifier les spécifications des conteneurs dans les manifests pour forcer 'readOnlyRootFilesystem: true' et utiliser des volumes temporaires (emptyDir) pour l'écriture.",
      remediationCmd: "securityContext:\n  readOnlyRootFilesystem: true"
    },
    {
      id: 3,
      title: "Enforcer la vérification de signature Cosign dans Kyverno",
      type: "Kyverno / Cosign",
      severity: "HIGH",
      findings: "Les politiques Kyverno sont en mode Audit, permettant l'injection d'images non signées en production.",
      action: "Basculer la politique 'verify-cosign-images.yaml' du mode Audit vers le mode Enforce.",
      remediationCmd: "make kyverno-enforce-on"
    },
    {
      id: 4,
      title: "Restreindre les privilèges d'accès aux secrets Vault",
      type: "Secrets / Vault",
      severity: "MEDIUM",
      findings: "Le jeton d'authentification Kubernetes du ServiceAccount dispose d'un accès étendu sur toutes les clés de secrets.",
      action: "Mettre à jour la politique Vault associée pour limiter les opérations au chemin strict requis par l'application.",
      remediationCmd: "path \"secret/data/securerag-hub/production/*\" {\n  capabilities = [\"read\"]\n}"
    }
  ]

  return (
    <Box>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" sx={{ fontFamily: 'Outfit', fontWeight: 800, mb: 1, color: '#fff' }}>
          AI Recommendations Engine
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Recommandations automatisées et plans de remédiation générés en temps réel par l'analyseur IA.
        </Typography>
      </Box>

      <Grid container spacing={3}>
        {recommendations.map((rec) => (
          <Grid item xs={12} md={6} key={rec.id}>
            <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
              <CardContent sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column' }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                  <Chip
                    icon={<SparkIcon />}
                    label={rec.type}
                    color="primary"
                    variant="outlined"
                    size="small"
                    sx={{ fontWeight: 'bold' }}
                  />
                  <Chip
                    label={rec.severity}
                    color={rec.severity === 'CRITICAL' ? 'error' : rec.severity === 'HIGH' ? 'warning' : 'default'}
                    size="small"
                    sx={{ fontWeight: 'bold' }}
                  />
                </Box>

                <Typography variant="h6" sx={{ fontFamily: 'Outfit', fontWeight: 700, mb: 1, color: '#fff' }}>
                  {rec.title}
                </Typography>

                <Box sx={{ mb: 2 }}>
                  <Typography variant="caption" color="text.secondary" display="block">ANOMALIE CONSTATED</Typography>
                  <Typography variant="body2" sx={{ lineHeight: 1.5 }}>
                    {rec.findings}
                  </Typography>
                </Box>

                <Box sx={{ mb: 2, flexGrow: 1 }}>
                  <Typography variant="caption" color="text.secondary" display="block">ACTION CORRECTIVE</Typography>
                  <Typography variant="body2" sx={{ lineHeight: 1.5, fontWeight: 600, color: 'primary.main' }}>
                    {rec.action}
                  </Typography>
                </Box>

                <Typography variant="caption" color="text.secondary" display="block">CODE / COMMANDE DE REMÉDIATION</Typography>
                <Paper sx={{ p: 1.5, bgcolor: '#0d1117', border: '1px solid rgba(255,255,255,0.05)', mb: 2 }}>
                  <Typography variant="body2" sx={{ fontFamily: 'monospace', whiteSpace: 'pre-wrap', color: 'info.main', fontSize: '12px' }}>
                    {rec.remediationCmd}
                  </Typography>
                </Paper>

                <Button variant="outlined" startIcon={<LaunchIcon />} size="small" fullWidth sx={{ borderColor: 'rgba(255,255,255,0.08)' }}>
                  Appliquer la remédiation
                </Button>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Box>
  )
}
