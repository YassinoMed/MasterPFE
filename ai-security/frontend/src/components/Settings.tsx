import React, { useState } from 'react'
import {
  Card,
  CardContent,
  Typography,
  Box,
  Switch,
  FormControlLabel,
  Slider,
  Button,
  Grid,
  TextField,
  Alert
} from '@mui/material'
import {
  Save as SaveIcon,
  SettingsBackupRestore as ResetIcon
} from '@mui/icons-material'

export default function Settings() {
  const [mockInference, setMockInference] = useState(true)
  const [confidenceThreshold, setConfidenceThreshold] = useState(85)
  const [emailAlerts, setEmailAlerts] = useState(true)
  const [alertEmail, setAlertEmail] = useState('med.yassine.bouneb@proton.me')
  const [successMsg, setSuccessMsg] = useState(false)

  const handleSave = () => {
    setSuccessMsg(true)
    setTimeout(() => setSuccessMsg(false), 3000)
  }

  return (
    <Box>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" sx={{ fontFamily: 'Outfit', fontWeight: 800, mb: 1, color: '#fff' }}>
          Paramètres du Module Sécurité IA
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Configurez les seuils de confiance du modèle HuggingFace, les destinations d'alerting et le mode de fonctionnement.
        </Typography>
      </Box>

      {successMsg && (
        <Alert severity="success" sx={{ mb: 3, borderRadius: 2 }}>
          Paramètres enregistrés avec succès.
        </Alert>
      )}

      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom sx={{ fontWeight: 700 }}>
                Configuration de l'Inférence
              </Typography>
              
              <Box sx={{ mt: 3, mb: 4 }}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={mockInference}
                      onChange={(e) => setMockInference(e.target.checked)}
                      color="primary"
                    />
                  }
                  label={
                    <Box>
                      <Typography variant="body1" sx={{ fontWeight: 600 }}>Simuler l'inférence du modèle (Mock)</Typography>
                      <Typography variant="caption" color="text.secondary">
                        Force l'analyseur heuristique léger pour économiser la mémoire de production.
                      </Typography>
                    </Box>
                  }
                />
              </Box>

              <Box sx={{ mb: 4 }}>
                <Typography variant="body1" sx={{ fontWeight: 600 }} gutterBottom>
                  Seuil de Confiance d'Alerte : {confidenceThreshold}%
                </Typography>
                <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 2 }}>
                  Seuil minimal de certitude de l'IA pour déclencher un incident automatique.
                </Typography>
                <Slider
                  value={confidenceThreshold}
                  onChange={(_, val) => setConfidenceThreshold(val as number)}
                  min={50}
                  max={99}
                  valueLabelDisplay="auto"
                  color="primary"
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom sx={{ fontWeight: 700 }}>
                Canaux d'Alerte et Notification
              </Typography>

              <Box sx={{ mt: 3, mb: 4 }}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={emailAlerts}
                      onChange={(e) => setEmailAlerts(e.target.checked)}
                      color="secondary"
                    />
                  }
                  label={
                    <Box>
                      <Typography variant="body1" sx={{ fontWeight: 600 }}>Activer les alertes par E-mail</Typography>
                      <Typography variant="caption" color="text.secondary">
                        Notification automatique sur détection d'incident CRITICAL ou HIGH.
                      </Typography>
                    </Box>
                  }
                />
              </Box>

              <Box sx={{ mb: 4 }}>
                <TextField
                  fullWidth
                  label="Adresse de notification"
                  variant="outlined"
                  size="small"
                  disabled={!emailAlerts}
                  value={alertEmail}
                  onChange={(e) => setAlertEmail(e.target.value)}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12}>
          <Box sx={{ display: 'flex', gap: 2, justifyContent: 'flex-end' }}>
            <Button variant="outlined" startIcon={<ResetIcon />} sx={{ borderColor: 'rgba(255,255,255,0.08)' }}>
              Réinitialiser
            </Button>
            <Button variant="contained" color="primary" startIcon={<SaveIcon />} onClick={handleSave}>
              Enregistrer les modifications
            </Button>
          </Box>
        </Grid>
      </Grid>
    </Box>
  )
}
