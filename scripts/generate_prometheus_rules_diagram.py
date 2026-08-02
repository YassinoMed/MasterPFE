#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont

def generate_prometheus_rules_diagram(output_path="figures/fig-prometheus-rules-architecture.png"):
    width, height = 1200, 680
    bg_color = (250, 252, 255)
    card_bg = (255, 255, 255)
    border_color = (200, 210, 225)
    shadow_color = (230, 235, 245)
    
    title_color = (20, 35, 60)
    subtitle_color = (90, 105, 130)
    box_desc_color = (71, 85, 105)
    arrow_color = (234, 88, 12) # Prometheus Orange accent
    
    img = Image.new("RGB", (width, height), color=bg_color)
    draw = ImageDraw.Draw(img)
    
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font_bold_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    
    font_title = ImageFont.truetype(font_bold_path, 22)
    font_sub = ImageFont.truetype(font_path, 13)
    font_header = ImageFont.truetype(font_bold_path, 15)
    font_body = ImageFont.truetype(font_path, 12)
    font_small = ImageFont.truetype(font_path, 11)
    
    # 1. Header Title
    draw.text((40, 30), "Architecture des Règles Prometheus & Budgets d'Erreur SLO", fill=title_color, font=font_title)
    draw.text((40, 60), "Évaluation continue des enregistrements PromQL, alerting SLO et pilotage du budget d'erreur", fill=subtitle_color, font=font_sub)
    draw.line([(40, 85), (width - 40, 85)], fill=(220, 230, 242), width=2)
    
    def draw_card(x, y, w, h, title, items, header_bg=(255, 237, 213), header_fg=(154, 52, 18)):
        draw.rectangle([x+4, y+4, x+w+4, y+h+4], fill=shadow_color)
        draw.rectangle([x, y, x+w, y+h], fill=card_bg, outline=border_color, width=2)
        draw.rectangle([x, y, x+w, y+35], fill=header_bg)
        draw.line([(x, y+35), (x+w, y+35)], fill=border_color, width=1)
        draw.text((x+15, y+9), title, fill=header_fg, font=font_header)
        
        item_y = y + 48
        for line in items:
            draw.text((x+15, item_y), line, fill=box_desc_color, font=font_body)
            item_y += 20

    def draw_arrow(start, end, label=""):
        sx, sy = start
        ex, ey = end
        draw.line([(sx, sy), (ex, ey)], fill=arrow_color, width=3)
        if ex > sx:
            draw.polygon([(ex, ey), (ex-10, ey-6), (ex-10, ey+6)], fill=arrow_color)
        elif ey > sy:
            draw.polygon([(ex, ey), (ex-6, ey-10), (ex+6, ey-10)], fill=arrow_color)
        elif ex < sx:
            draw.polygon([(ex, ey), (ex+10, ey-6), (ex+10, ey+6)], fill=arrow_color)
            
        if label:
            lx = (sx + ex) // 2
            ly = (sy + ey) // 2 - 14
            bbox = draw.textbbox((0, 0), label, font=font_small)
            tw = bbox[2] - bbox[0]
            draw.rectangle([lx - tw//2 - 4, ly - 2, lx + tw//2 + 4, ly + 14], fill=(255, 247, 237))
            draw.text((lx - tw//2, ly), label, fill=arrow_color, font=font_small)

    # Nodes
    draw_card(40, 120, 220, 180, "1. Définition GitOps", [
        "• Repository Git (K8s)",
        "• CRD PrometheusRule",
        "• Expresssions SLI/SLO",
        "• ArgoCD Sync Pipeline"
    ], header_bg=(240, 245, 255), header_fg=(30, 58, 138))

    draw_card(320, 120, 260, 360, "2. Opérateur Prometheus", [
        "► Recording Rules:",
        "  - Précalcul des séries PromQL",
        "  - Agrégation de latence P95",
        "  - Ratio de succès / minutes",
        "",
        "► Alerting Rules (SLO):",
        "  - Multi-window burn rate",
        "  - Seuil d'erreur > 99.5%",
        "  - Transmitted state: firing"
    ], header_bg=(255, 237, 213), header_fg=(154, 52, 18))

    draw_card(640, 120, 240, 180, "3. AlertManager", [
        "• Déduplication d'alertes",
        "• Grouping & Inhibition",
        "• Webhook -> AI Brain",
        "• Notification SOC"
    ], header_bg=(254, 243, 199), header_fg=(146, 64, 14))

    draw_card(640, 350, 240, 130, "4. Grafana Dashboards", [
        "• Panel Budget d'Erreur",
        "• Suivi SLI en temps réel",
        "• Alerting burn rate visual"
    ], header_bg=(240, 253, 244), header_fg=(22, 101, 52))

    # Flow arrows
    draw_arrow((260, 210), (320, 210), "Sync CRD")
    draw_arrow((580, 210), (640, 210), "Firing State")
    draw_arrow((450, 480), (450, 520))
    draw_arrow((450, 520), (760, 520))
    draw_arrow((760, 520), (760, 480), "Metrics Stream")

    # Legend bottom
    draw.rectangle([40, 570, width-40, 640], fill=(245, 247, 250), outline=(210, 220, 235))
    draw.text((55, 580), "Mécanique du Budget d'Erreur (SRE Practice) :", fill=(154, 52, 18), font=font_header)
    draw.text((55, 605), "Les PrometheusRule précalculent le SLI et déclenchent des alertes de burn-rate graduelles,", fill=box_desc_color, font=font_body)
    draw.text((55, 622), "permettant de distinguer une dégradation transitoire tolérable d'une rupture critique de la qualité de service.", fill=box_desc_color, font=font_body)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")
    print(f"Generated diagram: {output_path} ({width}x{height})")

if __name__ == "__main__":
    generate_prometheus_rules_diagram()
