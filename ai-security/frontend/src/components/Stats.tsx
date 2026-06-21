import React, { useState, useEffect } from 'react'
import {
  Card,
  CardContent,
  Typography,
  Box,
  Grid
} from '@mui/material'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area,
  Legend
} from 'recharts'

export default function Stats() {
  const [data, setData] = useState<any>({
    sources: [
      { name: 'Tetragon', count: 120 },
      { name: 'Falco', count: 85 },
      { name: 'Wazuh', count: 95 },
      { name: 'Kubernetes', count: 45 },
      { name: 'Istio', count: 65 },
      { name: 'Prometheus', count: 30 }
    ],
    timeline: [
      { day: 'Lun', Normal: 150, Suspicious: 12, Malicious: 2 },
      { day: 'Mar', Normal: 180, Suspicious: 18, Malicious: 5 },
      { day: 'Mer', Normal: 210, Suspicious: 15, Malicious: 1 },
      { day: 'Jeu', Normal: 190, Suspicious: 25, Malicious: 8 },
      { day: 'Ven', Normal: 220, Suspicious: 22, Malicious: 4 },
      { day: 'Sam', Normal: 130, Suspicious: 8,  Malicious: 0 },
      { day: 'Dim', Normal: 140, Suspicious: 10, Malicious: 3 }
    ]
  })

  useEffect(() => {
    fetch('/api/statistics')
      .then(res => res.json())
      .then(stats => {
        const sourcesMapped = Object.keys(stats.sources).map(src => ({
          name: src,
          count: stats.sources[src]
        }))
        if (sourcesMapped.length > 0) {
          setData((prev: any) => ({
            ...prev,
            sources: sourcesMapped
          }))
        }
      })
      .catch(err => console.log("Failed to load statistics from backend. Using mock statistics.", err))
  }, [])

  return (
    <Box>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" sx={{ fontFamily: 'Outfit', fontWeight: 800, mb: 1, color: '#fff' }}>
          Statistiques Métriques Globales
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Statistiques de détection, volumétrie par source et distribution des sévérités sur la plateforme.
        </Typography>
      </Box>

      <Grid container spacing={3}>
        {/* Source Volume */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom sx={{ fontWeight: 700 }}>
                Volumétrie par Source de Logs
              </Typography>
              <Box sx={{ height: 300 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={data.sources}>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                    <XAxis dataKey="name" stroke="#64748b" />
                    <YAxis stroke="#64748b" />
                    <Tooltip contentStyle={{ backgroundColor: '#111827', borderColor: 'rgba(255,255,255,0.1)' }} />
                    <Bar dataKey="count" fill="#2979ff" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Severity Timeline */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom sx={{ fontWeight: 700 }}>
                Distribution des Incidents par Jour
              </Typography>
              <Box sx={{ height: 300 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={data.timeline}>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                    <XAxis dataKey="day" stroke="#64748b" />
                    <YAxis stroke="#64748b" />
                    <Tooltip contentStyle={{ backgroundColor: '#111827', borderColor: 'rgba(255,255,255,0.1)' }} />
                    <Legend />
                    <Area type="monotone" dataKey="Normal" stackId="1" stroke="#00e676" fill="rgba(0, 230, 118, 0.1)" />
                    <Area type="monotone" dataKey="Suspicious" stackId="2" stroke="#ff9100" fill="rgba(255, 145, 0, 0.1)" />
                    <Area type="monotone" dataKey="Malicious" stackId="3" stroke="#ff1744" fill="rgba(255, 23, 68, 0.1)" />
                  </AreaChart>
                </ResponsiveContainer>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  )
}
