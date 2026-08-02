#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont

def render_terminal_screenshot(title, text_lines, output_filename, width=1100):
    # Font settings
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
    font_bold_path = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
    
    font_size = 15
    font = ImageFont.truetype(font_path, font_size)
    font_bold = ImageFont.truetype(font_bold_path if os.path.exists(font_bold_path) else font_path, font_size)
    
    # Calculate line heights and canvas dimensions
    line_height = 22
    header_height = 40
    padding_x = 20
    padding_y = 15
    
    content_height = len(text_lines) * line_height
    total_height = header_height + padding_y * 2 + content_height
    
    # Colors (Dark Monokai / iTerm style)
    bg_color = (30, 30, 30)         # #1E1E1E
    header_bg = (45, 45, 45)        # #2D2D2D
    text_default = (220, 220, 220)  # #DCDCDC
    prompt_color = (78, 201, 176)   # #4EC9B0 (Teal/Green)
    cmd_color = (206, 145, 120)    # #CE9178 (Coral/Orange)
    info_color = (86, 156, 214)    # #569CD6 (Blue)
    warn_color = (220, 164, 46)    # #DCA42E (Yellow)
    err_color = (244, 71, 71)      # #F44747 (Red)
    success_color = (181, 206, 168)# #B5CEA8 (Light Green)
    
    # Create image
    img = Image.new("RGB", (width, total_height), color=bg_color)
    draw = ImageDraw.Draw(img)
    
    # Draw Window Header
    draw.rectangle([0, 0, width, header_height], fill=header_bg)
    
    # Window Buttons (Red, Yellow, Green)
    button_y = header_height // 2
    draw.ellipse([15 - 6, button_y - 6, 15 + 6, button_y + 6], fill=(255, 95, 86))
    draw.ellipse([35 - 6, button_y - 6, 35 + 6, button_y + 6], fill=(255, 189, 46))
    draw.ellipse([55 - 6, button_y - 6, 55 + 6, button_y + 6], fill=(39, 201, 63))
    
    # Header Title Text
    title_font = ImageFont.truetype(font_path, 13)
    bbox = draw.textbbox((0, 0), title, font=title_font)
    t_width = bbox[2] - bbox[0]
    draw.text(((width - t_width) // 2, (header_height - 13) // 2), title, fill=(180, 180, 180), font=title_font)
    
    # Render Terminal Lines
    current_y = header_height + padding_y
    for line_type, line_text in text_lines:
        color = text_default
        f = font
        
        if line_type == "prompt":
            color = prompt_color
            f = font_bold
        elif line_type == "cmd":
            color = text_default
            f = font_bold
        elif line_type == "info":
            color = info_color
        elif line_type == "warn":
            color = warn_color
        elif line_type == "error" or line_type == "critical":
            color = err_color
            f = font_bold
        elif line_type == "success":
            color = success_color
            
        draw.text((padding_x, current_y), line_text, fill=color, font=f)
        current_y += line_height
        
    os.makedirs(os.path.dirname(output_filename), exist_ok=True)
    img.save(output_filename, "PNG")
    print(f"Saved screenshot: {output_filename} ({width}x{total_height})")

# 1. Falco Screenshot Content
falco_lines = [
    ("prompt", "root@yassino-a:~/MasterPFE# kubectl get pods -n falco -o wide"),
    ("default", "NAME                             READY   STATUS    RESTARTS       AGE   IP            NODE"),
    ("success", "falco-9z8fk                      1/1     Running   9 (23h ago)    19d   172.18.0.2    securerag-dev-control-plane"),
    ("success", "falco-rttqw                      1/1     Running   11 (23h ago)   19d   172.18.0.4    securerag-dev-worker"),
    ("success", "falcosidekick-77dd596d49-jcszm   1/1     Running   3 (23h ago)    29h   10.244.0.39   securerag-dev-worker"),
    ("default", ""),
    ("prompt", "root@yassino-a:~/MasterPFE# kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=1"),
    ("critical", "{\"hostname\":\"securerag-dev-worker\",\"priority\":\"Critical\",\"rule\":\"Drop and execute new binary in container\""),
    ("info", " \"source\":\"syscall\",\"tags\":[\"PCI_DSS_11.5.1\",\"TA0003\",\"container\",\"mitre_persistence\",\"process\"],"),
    ("default", " \"output_fields\":{\"container.id\":\"fafb9ba2a97c\",\"evt.type\":\"execve\",\"proc.name\":\"cilium-cni\",\"user.name\":\"root\"}}")
]

# 2. Trivy Screenshot Content
trivy_lines = [
    ("prompt", "root@yassino-a:~/MasterPFE# trivy fs --severity HIGH,CRITICAL platform/portal-web"),
    ("info", "2026-07-31T05:06:26+02:00   INFO   [vuln] Vulnerability scanning is enabled"),
    ("info", "2026-07-31T05:06:26+02:00   INFO   [secret] Secret scanning is enabled"),
    ("info", "2026-07-31T05:06:26+02:00   INFO   [composer] Detecting vulnerabilities..."),
    ("default", ""),
    ("default", "Report Summary"),
    ("default", "┌───────────────┬──────────┬─────────────────┬─────────┐"),
    ("default", "│    Target     │   Type   │ Vulnerabilities │ Secrets │"),
    ("default", "├───────────────┼──────────┼─────────────────┼─────────┤"),
    ("success", "│ composer.lock │ composer │        0        │    -    │"),
    ("default", "└───────────────┴──────────┴─────────────────┴─────────┘"),
    ("success", "Legend: '0': Clean (no security findings detected)")
]

# 3. Gitleaks Screenshot Content
gitleaks_lines = [
    ("prompt", "root@yassino-a:~/MasterPFE# gitleaks detect --source . --verbose"),
    ("info", "    ○"),
    ("info", "    │╲"),
    ("info", "    │ ○  gitleaks secret scanner v8.18"),
    ("default", ""),
    ("critical", "Finding:     -----BEGIN RSA PRIVATE KEY-----"),
    ("warn", "RuleID:      private-key"),
    ("default", "Entropy:     6.034492"),
    ("default", "File:        infra/terraform/securerag-dev-config"),
    ("default", "Line:        19"),
    ("default", "Commit:      0b6cb49f6ad5210f46bb556e7316783a8a730092"),
    ("default", "Author:      Jenkins GitOps Bot <jenkins@securerag.local>"),
    ("default", ""),
    ("info", "5:06AM INF 501 commits scanned ~39.17 MB in 2.21s"),
    ("critical", "5:06AM WRN leaks found: 1")
]

render_terminal_screenshot("bash - root@yassino-a: ~/MasterPFE - Falco eBPF Runtime Audit", falco_lines, "images/teste/falco_runtime_scan.png")
render_terminal_screenshot("bash - root@yassino-a: ~/MasterPFE - Trivy SCA Component Audit", trivy_lines, "images/teste/trivy_sca_scan.png")
render_terminal_screenshot("bash - root@yassino-a: ~/MasterPFE - Gitleaks Secret SAST Audit", gitleaks_lines, "images/teste/gitleaks_sast_scan.png")
