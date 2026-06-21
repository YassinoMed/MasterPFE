import React, { useState, useEffect } from 'react'
import {
  Box,
  Drawer,
  AppBar,
  Toolbar,
  List,
  Typography,
  Divider,
  IconButton,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Badge,
  Snackbar,
  Alert
} from '@mui/material'
import {
  Menu as MenuIcon,
  Dashboard as DashboardIcon,
  ListAlt as LogsIcon,
  Warning as AlertsIcon,
  Shield as IncidentsIcon,
  BarChart as StatsIcon,
  Settings as SettingsIcon,
  Psychology as RecommendationsIcon, // Brain / AI icon representation in MUI
  Wifi as WifiIcon,
  WifiOff as WifiOffIcon
} from '@mui/icons-material'

// Import components
import Dashboard from './components/Dashboard'
import Logs from './components/Logs'
import Alerts from './components/Alerts'
import Incidents from './components/Incidents'
import Stats from './components/Stats'
import Recommendations from './components/Recommendations'
import Settings from './components/Settings'

const drawerWidth = 260

export default function App() {
  const [activeTab, setActiveTab] = useState('dashboard')
  const [wsConnected, setWsConnected] = useState(false)
  const [unreadAlerts, setUnreadAlerts] = useState(0)
  const [latestAlert, setLatestAlert] = useState<any>(null)
  const [showToast, setShowToast] = useState(false)

  // Configure WebSockets for real-time dashboard updates
  useEffect(() => {
    const wsUrl = `ws://${window.location.hostname}:8080/ws`
    let ws = new WebSocket(wsUrl)

    const connectWs = () => {
      ws.onopen = () => {
        logger_debug("WebSocket Connected")
        setWsConnected(true)
      }
      ws.onmessage = (event) => {
        try {
          const payload = JSON.parse(event.data)
          if (payload.event_type === 'NEW_ANALYSIS') {
            const data = payload.data
            // If the event is suspicious or malicious, raise alert toast and count unread
            if (data.classification !== 'NORMAL') {
              setLatestAlert(data)
              setShowToast(true)
              setUnreadAlerts((prev) => prev + 1)
            }
            // Trigger local custom event to update loaded components instantly
            const customEvent = new CustomEvent('ws-alert-received', { detail: payload })
            window.dispatchEvent(customEvent)
          }
        } catch (e) {
          console.error("Failed to parse WS message", e)
        }
      }
      ws.onclose = () => {
        logger_debug("WebSocket Disconnected. Reconnecting...")
        setWsConnected(false)
        setTimeout(() => {
          ws = new WebSocket(wsUrl)
          connectWs()
        }, 5000)
      }
    }

    const logger_debug = (msg: string) => {
      console.log(`[WS] ${msg}`)
    }

    connectWs()
    return () => ws.close()
  }, [])

  const handleTabChange = (tab: string) => {
    setActiveTab(tab)
    if (tab === 'alerts') {
      setUnreadAlerts(0)
    }
  }

  // Map active tab to page component
  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return <Dashboard />
      case 'logs':
        return <Logs />
      case 'alerts':
        return <Alerts />
      case 'incidents':
        return <Incidents />
      case 'stats':
        return <Stats />
      case 'recommendations':
        return <Recommendations />
      case 'settings':
        return <Settings />
      default:
        return <Dashboard />
    }
  }

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh', bgcolor: 'background.default' }}>
      {/* Top Navigation Bar */}
      <AppBar position="fixed" sx={{ zIndex: (theme) => theme.zIndex.drawer + 1, bgcolor: '#111827', borderBottom: '1px solid rgba(255,255,255,0.08)' }} elevation={0}>
        <Toolbar>
          <IconButton edge="start" color="inherit" aria-label="menu" sx={{ mr: 2, display: { sm: 'none' } }}>
            <MenuIcon />
          </IconButton>
          <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1, fontFamily: 'Outfit', display: 'flex', alignItems: 'center', gap: 1 }}>
            🛡️ AI-Driven DevSecOps Panel
          </Typography>

          {/* Connection Status indicator */}
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mr: 2 }}>
            {wsConnected ? (
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, color: 'success.main' }}>
                <WifiIcon fontSize="small" />
                <Typography variant="caption" sx={{ display: { xs: 'none', sm: 'inline' } }}>TEMPS RÉEL</Typography>
              </Box>
            ) : (
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, color: 'error.main' }}>
                <WifiOffIcon fontSize="small" />
                <Typography variant="caption" sx={{ display: { xs: 'none', sm: 'inline' } }}>DÉCONNECTÉ</Typography>
              </Box>
            )}
          </Box>
        </Toolbar>
      </AppBar>

      {/* Side Navigation Bar */}
      <Drawer
        variant="permanent"
        sx={{
          width: drawerWidth,
          flexShrink: 0,
          [`& .MuiDrawer-paper`]: { width: drawerWidth, boxSizing: 'border-box', bgcolor: '#0f172a', borderRight: '1px solid rgba(255,255,255,0.08)' },
        }}
      >
        <Toolbar />
        <Box sx={{ overflow: 'auto', px: 2, py: 3 }}>
          <List sx={{ display: 'flex', flexDirection: 'column', gap: 0.5 }}>
            {[
              { id: 'dashboard', label: 'Dashboard', icon: <DashboardIcon /> },
              { id: 'logs', label: 'Vue Logs', icon: <LogsIcon /> },
              {
                id: 'alerts',
                label: 'Alertes',
                icon: (
                  <Badge badgeContent={unreadAlerts} color="error">
                    <AlertsIcon />
                  </Badge>
                )
              },
              { id: 'incidents', label: 'Incidents', icon: <IncidentsIcon /> },
              { id: 'stats', label: 'Statistiques', icon: <StatsIcon /> },
              { id: 'recommendations', label: 'AI Recommendations', icon: <RecommendationsIcon /> },
              { id: 'settings', label: 'Paramètres', icon: <SettingsIcon /> },
            ].map((item) => (
              <ListItem key={item.id} disablePadding>
                <ListItemButton
                  selected={activeTab === item.id}
                  onClick={() => handleTabChange(item.id)}
                  sx={{
                    borderRadius: 2,
                    mb: 0.5,
                    '&.Mui-selected': {
                      bgcolor: 'rgba(0, 230, 118, 0.15)',
                      color: 'primary.main',
                      '& .MuiListItemIcon-root': {
                        color: 'primary.main',
                      },
                    },
                    '&:hover': {
                      bgcolor: 'rgba(255, 255, 255, 0.05)',
                    },
                  }}
                >
                  <ListItemIcon sx={{ minWidth: 40, color: 'text.secondary' }}>{item.icon}</ListItemIcon>
                  <ListItemText primary={item.label} primaryTypographyProps={{ fontSize: '14px', fontWeight: 600 }} />
                </ListItemButton>
              </ListItem>
            ))}
          </List>
          <Divider sx={{ my: 3, borderColor: 'rgba(255,255,255,0.08)' }} />
          <Box sx={{ p: 2, bgcolor: 'rgba(0,0,0,0.2)', borderRadius: 2, border: '1px solid rgba(255,255,255,0.05)' }}>
            <Typography variant="caption" color="text.secondary" display="block" gutterBottom>
              Modèle Actif :
            </Typography>
            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '11px', color: 'info.main' }}>
              cyberguard-ai-security-analyzer
            </Typography>
          </Box>
        </Box>
      </Drawer>

      {/* Main Content Area */}
      <Box component="main" sx={{ flexGrow: 1, p: 3, pt: 10, overflow: 'auto' }}>
        {renderContent()}
      </Box>

      {/* Real-time alert notifications toaster */}
      <Snackbar open={showToast} autoHideDuration={6000} onClose={() => setShowToast(false)} anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}>
        <Alert
          onClose={() => setShowToast(false)}
          severity={latestAlert?.classification === 'MALICIOUS' ? 'error' : 'warning'}
          sx={{ width: '100%', borderRadius: 2, border: '1px solid rgba(255,255,255,0.1)' }}
        >
          <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
            Nouvelle alerte détectée ({latestAlert?.source})
          </Typography>
          <Typography variant="body2" sx={{ fontSize: '12px' }}>
            {latestAlert?.explanation}
          </Typography>
        </Alert>
      </Snackbar>
    </Box>
  )
}
