import React, { useState, useEffect } from 'react'
import {
  Grid,
  Card,
  CardContent,
  Typography,
  Box,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip
} from '@mui/material'
import {
  ErrorOutline as DangerIcon,
  ReportProblem as WarnIcon,
  CheckCircle as OkIcon,
  Timeline as RiskIcon
} from '@mui/icons-material'
import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  LineChart,
  Line,
  CartesianGrid
} from 'recharts'

export default function Dashboard() {
  const [stats, setStats] = useState<any>({
    total_events: 0,
    malicious_events: 0,
    suspicious_events: 0,
    global_risk_score: 0.0,
    detection_rate: 0.0,
    critical_alerts: [],
    top_sources: []
  })

  const [graphData, setGraphData] = useState<any>({
    pie: [
      { name: 'Normal', value: 400, color: '#00e676' },
      { name: 'Suspicious', value: 120, color: '#ff9100' },
      { name: 'Malicious', value: 80, color: '#ff1744' }
    ],
    timeline: [
      { time: '10:00', Malicious: 2, Suspicious: 5, Normal: 20 },
      { time: '11:00', Malicious: 4, Suspicious: 8, Normal: 22 },
      { time: '12:00', Malicious: 1, Suspicious: 6, Normal: 18 },
      { time: '13:00', Malicious: 5, Suspicious: 9, Normal: 25 },
      { time: '14:00', Malicious: 9, Suspicious: 12, Normal: 30 },
    ]
  })

  const fetchStats = () => {
    fetch('/api/dashboard')
      .then((res) => {
        if (!res.ok) throw new Error("Backend response error")
        return res.json()
      })
      .then((data) => {
        setStats(data)
        // Adjust chart values based on backend output
        setGraphData((prev: any) => ({
          ...prev,
          pie: [
            { name: 'Normal', value: data.total_events - data.malicious_events - data.suspicious_events, color: '#00e676' },
            { name: 'Suspicious', value: data.suspicious_events, color: '#ff9100' },
            { name: 'Malicious', value: data.malicious_events, color: '#ff1744' }
          ]
        }))
      })
      .catch((err) => console.log("Failed to fetch dashboard data. Using defaults.", err))
  }

  useEffect(() => {
    fetchStats()

    // Setup listener to live reload dashboard stats on WebSocket notify
    const wsListener = () => {
      fetchStats()
    }
    window.addEventListener('ws-alert-received', wsListener)
    return () => window.removeEventListener('ws-alert-received', wsListener)
  }, [])

  return (
    <Box>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" sx={{ fontFamily: 'Outfit', fontWeight: 800, mb: 1, color: '#fff' }}>
          AI DevSecOps Control Room
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Threat analytics dashboard fueled by omasteam/cyberguard-ai-security-analyzer
        </Typography>
      </Box>

      {/* KPI Counters */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        {[
          { title: 'Total Événements', val: stats.total_events || 250, desc: 'Logs collectés', icon: <OkIcon sx={{ color: '#00e676', fontSize: 35 }} /> },
          { title: 'Événements Malveillants', val: stats.malicious_events || 8, desc: 'Incidents bloqués', icon: <DangerIcon sx={{ color: '#ff1744', fontSize: 35 }} /> },
          { title: 'Événements Suspects', val: stats.suspicious_events || 15, desc: 'Alertes investiguées', icon: <WarnIcon sx={{ color: '#ff9100', fontSize: 35 }} /> },
          {
            title: 'Taux de Détection',
            val: `${(stats.detection_rate || 9.2).toFixed(1)}%`,
            desc: 'Ratio suspicion / total',
            icon: <RiskIcon sx={{ color: '#2979ff', fontSize: 35 }} />
          },
        ].map((kpi, idx) => (
          <Grid item xs={12} sm={6} md={3} key={idx}>
            <Card sx={{ height: '100%', display: 'flex', alignItems: 'center' }}>
              <CardContent sx={{ display: 'flex', width: '100%', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                    {kpi.title}
                  </Typography>
                  <Typography variant="h4" sx={{ fontWeight: 800, fontFamily: 'Outfit' }}>
                    {kpi.val}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {kpi.desc}
                  </Typography>
                </Box>
                {kpi.icon}
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {/* Global Risk Index & Core charts */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} md={4}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6" gutterBottom sx={{ fontWeight: 700 }}>
                Index de Risque Global
              </Typography>
              <Box sx={{ position: 'relative', height: 200, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
                <Typography variant="h2" sx={{ fontWeight: 900, color: stats.global_risk_score > 60 ? '#ff1744' : stats.global_risk_score > 30 ? '#ff9100' : '#00e676' }}>
                  {(stats.global_risk_score || 25.0).toFixed(0)}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  RISK METRIC
                </Typography>
                <Box sx={{ width: '80%', mt: 3 }}>
                  <LinearProgress
                    variant="determinate"
                    value={stats.global_risk_score || 25}
                    color={stats.global_risk_score > 60 ? 'error' : stats.global_risk_score > 30 ? 'warning' : 'success'}
                    sx={{ height: 10, borderRadius: 5 }}
                  />
                </Box>
              </Box>
              <Typography variant="body2" color="text.secondary" align="center">
                Calculé d'après la sévérité et la récurrence des menaces actives.
              </Typography>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6" gutterBottom sx={{ fontWeight: 700 }}>
                Classification des Menaces
              </Typography>
              <Box sx={{ height: 200 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={graphData.pie} cx="50%" cy="50%" innerRadius={60} outerRadius={80} paddingAngle={5} dataKey="value">
                      {graphData.pie.map((entry: any, index: number) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip contentStyle={{ backgroundColor: '#111827', borderColor: 'rgba(255,255,255,0.1)' }} />
                  </PieChart>
                </ResponsiveContainer>
              </Box>
              <Box sx={{ display: 'flex', justifyContent: 'space-around', mt: 1 }}>
                {graphData.pie.map((entry: any, idx: number) => (
                  <Box key={idx} sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Box sx={{ width: 12, height: 12, borderRadius: '50%', bgcolor: entry.color }} />
                    <Typography variant="body2">{entry.name}</Typography>
                  </Box>
                ))}
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6" gutterBottom sx={{ fontWeight: 700 }}>
                Tendance Temporelle (Menaces)
              </Typography>
              <Box sx={{ height: 220 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={graphData.timeline}>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                    <XAxis dataKey="time" stroke="#64748b" />
                    <YAxis stroke="#64748b" />
                    <Tooltip contentStyle={{ backgroundColor: '#111827', borderColor: 'rgba(255,255,255,0.1)' }} />
                    <Line type="monotone" dataKey="Malicious" stroke="#ff1744" strokeWidth={3} />
                    <Line type="monotone" dataKey="Suspicious" stroke="#ff9100" strokeWidth={2} />
                  </LineChart>
                </ResponsiveContainer>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Critical alerts table */}
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom sx={{ fontWeight: 700 }}>
            Dernières Alertes Critiques / Hautes
          </Typography>
          <TableContainer component={Paper} sx={{ bgcolor: 'transparent', boxShadow: 'none' }}>
            <Table size="small">
              <TableHead>
                <TableRow sx={{ borderBottom: '2px solid rgba(255,255,255,0.08)' }}>
                  <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Horodatage</TableCell>
                  <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Source</TableCell>
                  <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Classification</TableCell>
                  <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Sévérité</TableCell>
                  <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Explication</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {stats.critical_alerts.length > 0 ? (
                  stats.critical_alerts.map((alert: any) => (
                    <TableRow key={alert.id} sx={{ '&:last-child td, &:last-child th': { border: 0 }, borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                      <TableCell sx={{ fontFamily: 'monospace', fontSize: '12px' }}>{new Date(alert.timestamp).toLocaleString()}</TableCell>
                      <TableCell sx={{ fontWeight: 700 }}>{alert.source}</TableCell>
                      <TableCell>
                        <Chip
                          label={alert.classification}
                          size="small"
                          color={alert.classification === 'MALICIOUS' ? 'error' : 'warning'}
                          variant="outlined"
                        />
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={alert.severity}
                          size="small"
                          color={alert.severity === 'CRITICAL' ? 'error' : 'warning'}
                          sx={{ fontWeight: 'bold' }}
                        />
                      </TableCell>
                      <TableCell>{alert.explanation}</TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell colSpan={5} align="center" sx={{ color: 'text.secondary', py: 4 }}>
                      Aucune alerte critique récente détectée.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </CardContent>
      </Card>
    </Box>
  )
}
