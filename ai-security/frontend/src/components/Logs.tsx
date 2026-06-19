import React, { useState, useEffect } from 'react'
import {
  Card,
  CardContent,
  Typography,
  Box,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  Button,
  TablePagination,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Grid
} from '@mui/material'
import {
  FileDownload as DownloadIcon,
  Search as SearchIcon
} from '@mui/icons-material'

export default function Logs() {
  const [logs, setLogs] = useState<any[]>([])
  const [filteredLogs, setFilteredLogs] = useState<any[]>([])
  const [search, setSearch] = useState('')
  const [classification, setClassification] = useState('ALL')
  const [severity, setSeverity] = useState('ALL')
  
  // Pagination
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)

  // Log inspect details modal
  const [selectedLog, setSelectedLog] = useState<any>(null)
  const [modalOpen, setModalOpen] = useState(false)

  const fetchLogs = () => {
    fetch('/api/logs?limit=500')
      .then((res) => res.json())
      .then((data) => {
        setLogs(data)
        setFilteredLogs(data)
      })
      .catch((err) => {
        console.error("Failed to load logs from backend. Loading mocks.", err)
        // Fallback simulated logs for offline/dev demonstration
        const mockLogs = Array.from({ length: 45 }).map((_, idx) => {
          const classes = ['NORMAL', 'SUSPICIOUS', 'MALICIOUS']
          const severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
          const sources = ['Tetragon', 'Falco', 'Wazuh', 'Kubernetes', 'Istio', 'Prometheus']
          const cls = classes[idx % 3]
          const sev = cls === 'MALICIOUS' ? 'CRITICAL' : cls === 'SUSPICIOUS' ? 'HIGH' : 'LOW'
          
          return {
            id: idx + 1,
            timestamp: new Date(Date.now() - idx * 3600 * 1000).toISOString(),
            source: sources[idx % sources.length],
            classification: cls,
            severity: sev,
            confidence: 80.0 + (idx % 20),
            explanation: cls !== 'NORMAL' ? "Suspicious process execution detected." : "Routine service container verification.",
            recommendation: cls !== 'NORMAL' ? "Rotate credentials and check runtime limits." : "No actions required.",
            raw_log: `LOG EVENT: ${sources[idx % sources.length]} event ${idx * 5} details completed.`
          }
        })
        setLogs(mockLogs)
        setFilteredLogs(mockLogs)
      })
  }

  useEffect(() => {
    fetchLogs()

    const wsListener = () => {
      fetchLogs()
    }
    window.addEventListener('ws-alert-received', wsListener)
    return () => window.removeEventListener('ws-alert-received', wsListener)
  }, [])

  // Filter and search logic
  useEffect(() => {
    let result = logs
    if (search.trim() !== '') {
      const q = search.toLowerCase()
      result = result.filter(
        (l) =>
          l.source.toLowerCase().includes(q) ||
          l.explanation.toLowerCase().includes(q) ||
          l.raw_log.toLowerCase().includes(q)
      )
    }
    if (classification !== 'ALL') {
      result = result.filter((l) => l.classification === classification)
    }
    if (severity !== 'ALL') {
      result = result.filter((l) => l.severity === severity)
    }
    setFilteredLogs(result)
    setPage(0)
  }, [search, classification, severity, logs])

  const handleRowClick = (log: any) => {
    setSelectedLog(log)
    setModalOpen(true)
  }

  // Export functions
  const exportToCSV = () => {
    const headers = 'ID,Timestamp,Source,Classification,Severity,Confidence,Explanation,Recommendation,RawLog\n'
    const rows = filteredLogs.map(l => 
      `"${l.id}","${l.timestamp}","${l.source}","${l.classification}","${l.severity}","${l.confidence}%","${l.explanation.replace(/"/g, '""')}","${l.recommendation.replace(/"/g, '""')}","${l.raw_log.replace(/"/g, '""')}"`
    ).join('\n')
    
    const blob = new Blob([headers + rows], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    link.href = URL.createObjectURL(blob)
    link.setAttribute('download', 'ai_security_logs.csv')
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  const exportToJSON = () => {
    const blob = new Blob([JSON.stringify(filteredLogs, null, 2)], { type: 'application/json' })
    const link = document.createElement('a')
    link.href = URL.createObjectURL(blob)
    link.setAttribute('download', 'ai_security_logs.json')
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  return (
    <Box>
      <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2 }}>
        <Box>
          <Typography variant="h4" sx={{ fontFamily: 'Outfit', fontWeight: 800, mb: 1, color: '#fff' }}>
            Logs & AI Analysis Inspector
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Inspect all DevSecOps logs annotated with HuggingFace classifications and confidence scores.
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1.5 }}>
          <Button variant="outlined" startIcon={<DownloadIcon />} onClick={exportToCSV} sx={{ borderColor: 'rgba(255,255,255,0.1)' }}>
            Exporter CSV
          </Button>
          <Button variant="outlined" startIcon={<DownloadIcon />} onClick={exportToJSON} sx={{ borderColor: 'rgba(255,255,255,0.1)' }}>
            Exporter JSON
          </Button>
        </Box>
      </Box>

      {/* Filters card */}
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={4}>
              <TextField
                fullWidth
                label="Rechercher des logs..."
                variant="outlined"
                size="small"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                InputProps={{
                  startAdornment: <SearchIcon sx={{ color: 'text.secondary', mr: 1 }} />,
                }}
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Classification</InputLabel>
                <Select value={classification} label="Classification" onChange={(e) => setClassification(e.target.value)}>
                  <MenuItem value="ALL">Toutes les classifications</MenuItem>
                  <MenuItem value="NORMAL">Normal</MenuItem>
                  <MenuItem value="SUSPICIOUS">Suspicious</MenuItem>
                  <MenuItem value="MALICIOUS">Malicious</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Sévérité</InputLabel>
                <Select value={severity} label="Sévérité" onChange={(e) => setSeverity(e.target.value)}>
                  <MenuItem value="ALL">Toutes les sévérités</MenuItem>
                  <MenuItem value="LOW">Low</MenuItem>
                  <MenuItem value="MEDIUM">Medium</MenuItem>
                  <MenuItem value="HIGH">High</MenuItem>
                  <MenuItem value="CRITICAL">Critical</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={2} textAlign="right">
              <Typography variant="body2" color="primary.main" sx={{ fontWeight: 'bold' }}>
                {filteredLogs.length} logs trouvés
              </Typography>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Table Card */}
      <Card>
        <TableContainer component={Paper} sx={{ bgcolor: 'transparent', boxShadow: 'none' }}>
          <Table>
            <TableHead>
              <TableRow sx={{ borderBottom: '2px solid rgba(255,255,255,0.08)' }}>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Date</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Source</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Classification</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Sévérité</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Confiance</TableCell>
                <TableCell sx={{ color: 'text.secondary', fontWeight: 600 }}>Analyse / Explication</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredLogs.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage).map((log) => (
                <TableRow
                  key={log.id}
                  hover
                  onClick={() => handleRowClick(log)}
                  sx={{
                    cursor: 'pointer',
                    '&:last-child td, &:last-child th': { border: 0 },
                    borderBottom: '1px solid rgba(255,255,255,0.05)',
                    '&:hover': { bgcolor: 'rgba(255,255,255,0.02) !important' }
                  }}
                >
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '12px' }}>
                    {new Date(log.timestamp).toLocaleString()}
                  </TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>{log.source}</TableCell>
                  <TableCell>
                    <Chip
                      label={log.classification}
                      size="small"
                      color={
                        log.classification === 'MALICIOUS'
                          ? 'error'
                          : log.classification === 'SUSPICIOUS'
                          ? 'warning'
                          : 'success'
                      }
                      variant="outlined"
                    />
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={log.severity}
                      size="small"
                      color={
                        log.severity === 'CRITICAL' || log.severity === 'HIGH'
                          ? 'error'
                          : log.severity === 'MEDIUM'
                          ? 'warning'
                          : 'default'
                      }
                    />
                  </TableCell>
                  <TableCell sx={{ fontWeight: 'bold' }}>{log.confidence.toFixed(1)}%</TableCell>
                  <TableCell sx={{ maxWidth: 300, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {log.explanation}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
        <TablePagination
          rowsPerPageOptions={[10, 25, 50]}
          component="div"
          count={filteredLogs.length}
          rowsPerPage={rowsPerPage}
          page={page}
          onPageChange={(_, newPage) => setPage(newPage)}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(parseInt(e.target.value, 10))
            setPage(0)
          }}
          sx={{ borderTop: '1px solid rgba(255,255,255,0.08)' }}
        />
      </Card>

      {/* Log detailed inspector Modal */}
      <Dialog open={modalOpen} onClose={() => setModalOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle sx={{ borderBottom: '1px solid rgba(255,255,255,0.08)', pb: 2, fontFamily: 'Outfit', fontWeight: 800 }}>
          Inspecteur d'Alerte Sécuritaire #{selectedLog?.id}
        </DialogTitle>
        <DialogContent sx={{ py: 3 }}>
          {selectedLog && (
            <Grid container spacing={3}>
              <Grid item xs={12} sm={6}>
                <Typography variant="caption" color="text.secondary">SOURCE</Typography>
                <Typography variant="body1" sx={{ fontWeight: 'bold', mb: 2 }}>{selectedLog.source}</Typography>
                
                <Typography variant="caption" color="text.secondary">CLASSIFICATION</Typography>
                <Box sx={{ mb: 2 }}>
                  <Chip
                    label={selectedLog.classification}
                    color={
                      selectedLog.classification === 'MALICIOUS'
                        ? 'error'
                        : selectedLog.classification === 'SUSPICIOUS'
                        ? 'warning'
                        : 'success'
                    }
                    sx={{ fontWeight: 'bold' }}
                  />
                </Box>
              </Grid>
              <Grid item xs={12} sm={6}>
                <Typography variant="caption" color="text.secondary">SÉVÉRITÉ</Typography>
                <Box sx={{ mb: 2 }}>
                  <Chip label={selectedLog.severity} color={selectedLog.severity === 'CRITICAL' ? 'error' : 'default'} sx={{ fontWeight: 'bold' }} />
                </Box>

                <Typography variant="caption" color="text.secondary">CONFIANCE D'ANALYSE</Typography>
                <Typography variant="body1" sx={{ fontWeight: 'bold', color: 'primary.main', mb: 2 }}>
                  {selectedLog.confidence.toFixed(1)}%
                </Typography>
              </Grid>
              
              <Grid item xs={12}>
                <Typography variant="caption" color="text.secondary">LOG BRUT (RAW EVENT)</Typography>
                <Paper sx={{ p: 2, bgcolor: '#0d1117', border: '1px solid rgba(255,255,255,0.05)', mb: 3 }}>
                  <Typography variant="body2" sx={{ fontFamily: 'monospace', whiteSpace: 'pre-wrap', color: '#8b949e' }}>
                    {selectedLog.raw_log}
                  </Typography>
                </Paper>

                <Typography variant="caption" color="text.secondary">EXPLICATION IA</Typography>
                <Typography variant="body1" sx={{ mb: 3, lineHeight: 1.6 }}>{selectedLog.explanation}</Typography>

                <Typography variant="caption" color="text.secondary">RECOMMANDATIONS DE REMÉDIATION</Typography>
                <Paper sx={{ p: 2, bgcolor: 'rgba(0, 230, 118, 0.05)', border: '1px solid rgba(0, 230, 118, 0.2)' }}>
                  <Typography variant="body2" sx={{ color: 'primary.main', fontWeight: 600 }}>
                    {selectedLog.recommendation}
                  </Typography>
                </Paper>
              </Grid>
            </Grid>
          )}
        </DialogContent>
        <DialogActions sx={{ borderTop: '1px solid rgba(255,255,255,0.08)', px: 3, py: 2 }}>
          <Button onClick={() => setModalOpen(false)} variant="contained">Fermer</Button>
        </DialogActions>
      </Dialog>
    </Box>
  )
}
