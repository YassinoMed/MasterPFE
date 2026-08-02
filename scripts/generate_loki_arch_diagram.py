#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont

def generate_loki_architecture_diagram(output_path="figures/fig-loki-architecture.png"):
    width, height = 1200, 680
    bg_color = (250, 252, 255) # Light subtle blue-gray clean background
    card_bg = (255, 255, 255)
    border_color = (200, 210, 225)
    shadow_color = (230, 235, 245)
    
    # Text colors
    title_color = (20, 35, 60)
    subtitle_color = (90, 105, 130)
    box_title_color = (15, 23, 42)
    box_desc_color = (71, 85, 105)
    arrow_color = (59, 130, 246) # Blue accent
    
    img = Image.new("RGB", (width, height), color=bg_color)
    draw = ImageDraw.Draw(img)
    
    # Load fonts
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font_bold_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    
    font_title = ImageFont.truetype(font_bold_path, 22)
    font_sub = ImageFont.truetype(font_path, 13)
    font_header = ImageFont.truetype(font_bold_path, 15)
    font_body = ImageFont.truetype(font_path, 12)
    font_small = ImageFont.truetype(font_path, 11)
    
    # 1. Header Title
    draw.text((40, 30), "Architecture du Composant Loki — SecureRAG Hub", fill=title_color, font=font_title)
    draw.text((40, 60), "Agrégation de journaux orientée labels, stockage compressé et requêtage différé LogQL", fill=subtitle_color, font=font_sub)
    draw.line([(40, 85), (width - 40, 85)], fill=(220, 230, 242), width=2)
    
    def draw_card(x, y, w, h, title, items, header_bg=(240, 245, 255), header_fg=(30, 58, 138)):
        # Shadow
        draw.rectangle([x+4, y+4, x+w+4, y+h+4], fill=shadow_color)
        # Card Body
        draw.rectangle([x, y, x+w, y+h], fill=card_bg, outline=border_color, width=2)
        # Header banner
        draw.rectangle([x, y, x+w, y+35], fill=header_bg)
        draw.line([(x, y+35), (x+w, y+35)], fill=border_color, width=1)
        draw.text((x+15, y+9), title, fill=header_fg, font=font_header)
        
        # Items text
        item_y = y + 48
        for line in items:
            draw.text((x+15, item_y), line, fill=box_desc_color, font=font_body)
            item_y += 20

    def draw_arrow(start, end, label=""):
        sx, sy = start
        ex, ey = end
        draw.line([(sx, sy), (ex, ey)], fill=arrow_color, width=3)
        # Arrowhead
        if ex > sx: # Right
            draw.polygon([(ex, ey), (ex-10, ey-6), (ex-10, ey+6)], fill=arrow_color)
        elif ey > sy: # Down
            draw.polygon([(ex, ey), (ex-6, ey-10), (ex+6, ey-10)], fill=arrow_color)
        elif ex < sx: # Left
            draw.polygon([(ex, ey), (ex+10, ey-6), (ex+10, ey+6)], fill=arrow_color)
            
        if label:
            lx = (sx + ex) // 2
            ly = (sy + ey) // 2 - 14
            bbox = draw.textbbox((0, 0), label, font=font_small)
            tw = bbox[2] - bbox[0]
            draw.rectangle([lx - tw//2 - 4, ly - 2, lx + tw//2 + 4, ly + 14], fill=(235, 245, 255))
            draw.text((lx - tw//2, ly), label, fill=arrow_color, font=font_small)

    # --- Draw Architecture Nodes ---
    
    # Node 1: Sources (Left)
    draw_card(40, 120, 220, 180, "1. Sources de Logs", [
        "• Pods applicatifs (Laravel)",
        "• Security Agents (Falco)",
        "• Control Plane K8s",
        "• Stream stdout / stderr"
    ], header_bg=(238, 242, 255), header_fg=(49, 46, 129))

    # Node 2: Agent Promtail (Center Left)
    draw_card(320, 120, 230, 180, "2. Agent de Collecte", [
        "• Promtail / OTel Agent",
        "• Extraction des Metadata",
        "• Labeling: namespace, pod",
        "• Stream HTTP Push -> Loki"
    ], header_bg=(240, 253, 244), header_fg=(22, 101, 52))

    # Node 3: Loki Core (Center Right)
    draw_card(610, 120, 270, 360, "3. Backend Loki Core", [
        "► Distributor Component:",
        "  - Validation & Routing",
        "  - Fan-out par Stream Label",
        "",
        "► Ingester Component:",
        "  - Chunking en mémoire",
        "  - Compression (snappy)",
        "  - Flush vers Stockage",
        "",
        "► Querier Component:",
        "  - Exécution du moteur LogQL",
        "  - Filtrage différé sur le texte"
    ], header_bg=(254, 243, 199), header_fg=(146, 64, 14))

    # Node 4: Storage (Bottom Center)
    draw_card(320, 350, 230, 130, "4. Stockage Persistant", [
        "• Index Store (Labels TSDB)",
        "• Chunk Store (Logs bruts)",
        "• Local PV / Object Storage"
    ], header_bg=(241, 245, 249), header_fg=(51, 65, 85))

    # Node 5: Consumers (Right)
    draw_card(930, 120, 230, 360, "5. Visualisation SOC", [
        "• Grafana Explore (Panels)",
        "• Corrélation avec Tempo",
        "• Corrélation Prometheus",
        "• Client CLI (logcli query)",
        "• AI Security Brain (RAG)"
    ], header_bg=(250, 245, 255), header_fg=(107, 33, 168))

    # --- Draw Flow Arrows ---
    # Sources -> Agent
    draw_arrow((260, 210), (320, 210), "stdout/stderr")
    
    # Agent -> Loki Distributor
    draw_arrow((550, 210), (610, 210), "HTTP/gRPC Push")
    
    # Loki Ingester -> Storage
    draw_arrow((650, 480), (650, 520))
    draw_arrow((650, 520), (435, 520))
    draw_arrow((435, 520), (435, 480), "Flush Chunks")

    # Consumers <-> Loki Querier
    draw_arrow((930, 300), (880, 300), "LogQL Query")
    draw_arrow((880, 330), (930, 330), "Result Stream")

    # Legend at bottom
    draw.rectangle([40, 570, width-40, 640], fill=(240, 245, 250), outline=(210, 220, 235))
    draw.text((55, 580), "Spécificité Zero-Trust & Observabilité :", fill=(30, 58, 138), font=font_header)
    draw.text((55, 605), "Loki n'indexe QUE les métadonnées structurées (labels). Le texte brut est recherché au moment du requêtage LogQL,", fill=box_desc_color, font=font_body)
    draw.text((55, 622), "ce qui garantit un overhead d'ingestion minimal et une conservation efficace des preuves en cas d'incident applicatif.", fill=box_desc_color, font=font_body)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")
    print(f"Generated diagram: {output_path} ({width}x{height})")

if __name__ == "__main__":
    generate_loki_architecture_diagram()
