import React, { useState, useEffect } from 'react'
import {
  Card,
  CardContent,
  Typography,
  Box,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  Button,
  FormControl,
  Select,
  MenuItem,
  InputLabel,
  Grid
} from '@mui/material'
import {
  ShieldOutlined as IncidentIcon,
  CheckCircleOutline as ResolveIcon,
  Timer as ProgressIcon
} from '@mui/icons-material'

export default function Incidents() {
  const [incidents, setIncidents] = useState<any[]>([])
  const [filteredIncidents, setFilteredIncidents] = useState<any[]>([])
  const [statusFilter, setStatusFilter] = useState('ALL')

  const fetchIncidents = () => {
    fetch('/api/incidents')
      .then(res => res.json())
      .then(data => {
        setIncidents(data)
        setFilteredIncidents(data)
      })
      .catch(err => {
        console.error("Failed to load incidents. Loading mocks.", err)
        const mockIncidents = [
          {
            id: 1,
            timestamp: new Date().toISOString(),
            source: 'Tetragon',
            severity: 'CRITICAL',
            confidence: 98.0,
            description: 'Reverse shell detected: process exec /usr/bin/nc -e /bin/bash',
            recommendation: 'Isolate container and rotate secrets',
            status: 'OPEN'
          },
          {
            id: 2,
            timestamp: new Date(Date.now() - 4 * 3600000).toISOString(),
            source: 'Falco',
            severity: 'HIGH',
            confidence: 95.0,
            description: 'Rule: Write below binary dir - File modified: /usr/bin/wget by root',
            recommendation: 'Verify integrity of system binaries, enable read-only root filesystems',
            status: 'INVESTIGATING'
          },
          {
            id: 3,
            timestamp: new Date(Date.now() - 24 * 3600000).toISOString(),
            source: 'Istio',
            severity: 'CRITICAL',
            confidence: 97.0,
            description: "SQL Injection payload detected from 185.220.101.5 in request parameter 'id'",
            recommendation: 'Block origin IP in Ingress gateway and inspect backend database query parameter binding',
            status: 'RESOLVED'
          }
        ]
        setIncidents(mockIncidents)
        setFilteredIncidents(mockIncidents)
      })
  }

  useEffect(() => {
    fetchIncidents()

    const wsListener = () => {
      fetchIncidents()
    }
    window.addEventListener('ws-alert-received', wsListener)
    return () => window.removeEventListener('ws-alert-received', wsListener)
  }, [])

  // Filter logic
  useEffect(() => {
    if (statusFilter === 'ALL') {
      setFilteredIncidents(incidents)
    } else {
      setFilteredIncidents(incidents.filter(inc => inc.status === statusFilter))
    }
  }, [statusFilter, incidents])

  const handleUpdateStatus = (id: number, newStatus: string) => {
    fetch(`/api/incidents/${id}/status`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: newStatus })
    })
      .then(res => {
        if (!res.ok) throw new Error("Failed to update status")
        return res.json()
      })
      .then(() => {
        fetchIncidents()
      })
      .catch(err => {
        console.error(err)
        // Fallback update for mock UI state
        setIncidents(prev => prev.map(inc => inc.id === id ? { ...inc, status: newStatus } : inc))
      })
  }

  return (
    <Box>
      <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2 }}>
        <Box>
          <Typography variant="h4" sx={{ fontFamily: 'Outfit', fontWeight: 800, mb: 1, color: '#fff' }}>
            Registre des Incidents de Sécurité
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Suivi complet des menaces avérées (MALICIOUS) et des actions de remédiation entreprises.
          </Typography>
        </Box>
        <Box sx={{ minWidth: 200 }}>
          <FormControl fullWidth size="small">
            <InputLabel>Filtrer par statut</InputLabel>
            <Select value={statusFilter} label="Filtrer par statut" onChange={(e) => setStatusFilter(e.target.value)}>
              <MenuItem value="ALL">Tous les statuts</MenuItem>
              <MenuItem value="OPEN">Ouvert (OPEN)</MenuItem>
              <MenuItem value="INVESTIGATING">En cours (INVESTIGATING)</MenuItem>
              <MenuItem value="RESOLVED">Résolu (RESOLVED)</MenuItem>
            </Select>
          </FormControl>
        </Box>
      </Box>

      <Card>
        <TableContainer component={Paper} sx={{ bgcolor: 'transparent', boxShadow: 'none' }}>
          <Table>
            <TableHead>
              <TableRow sx={{ borderBottom: '2px solid rgba(255,255,255,0.08)' }}>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>ID Incident</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Horodatage</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Source</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Sévérité</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Description</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Statut</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }} align="center">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredIncidents.length > 0 ? (
                filteredIncidents.map((inc) => (
                  <TableRow key={inc.id} sx={{ '&:last-child td, &:last-child th': { border: 0 }, borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <TableCell sx={{ fontFamily: 'monospace', fontWeight: 'bold' }}>#INC-{inc.id}</TableCell>
                    <TableCell sx={{ fontFamily: 'monospace', fontSize: '12px' }}>{new Date(inc.timestamp).toLocaleString()}</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>{inc.source}</TableCell>
                    <TableCell>
                      <Chip label={inc.severity} color={inc.severity === 'CRITICAL' ? 'error' : 'default'} size="small" sx={{ fontWeight: 'bold' }} />
                    </TableCell>
                    <TableCell sx={{ maxWidth: 300 }}>{inc.description}</TableCell>
                    <TableCell>
                      <Chip
                        label={inc.status}
                        size="small"
                        color={inc.status === 'OPEN' ? 'error' : inc.status === 'INVESTIGATING' ? 'warning' : 'success'}
                        variant={inc.status === 'RESOLVED' ? 'filled' : 'outlined'}
                        sx={{ fontWeight: 'bold' }}
                      />
                    </TableCell>
                    <TableCell align="center">
                      <Box sx={{ display: 'flex', gap: 1, justifyContent: 'center' }}>
                        {inc.status === 'OPEN' && (
                          <Button
                            variant="outlined"
                            size="small"
                            color="warning"
                            startIcon={<ProgressIcon />}
                            onClick={() => handleUpdateStatus(inc.id, 'INVESTIGATING')}
                            sx={{ borderColor: 'rgba(255, 145, 0, 0.3)' }}
                          >
                            Analyser
                          </Button>
                        )}
                        {inc.status !== 'RESOLVED' && (
                          <Button
                            variant="contained"
                            size="small"
                            color="success"
                            startIcon={<ResolveIcon />}
                            onClick={() => handleUpdateStatus(inc.id, 'RESOLVED')}
                          >
                            Résoudre
                          </Button>
                        )}
                        {inc.status === 'RESOLVED' && (
                          <Typography variant="caption" color="text.secondary">Aucune action requise</Typography>
                        )}
                      </Box>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={7} align="center" sx={{ color: 'text.secondary', py: 4 }}>
                    Aucun incident trouvé pour ce statut.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Card>
    </Box>
  )
}
