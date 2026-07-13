---
name: Intelligent Extraction System
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#434655'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#3e3fcc'
  on-tertiary: '#ffffff'
  tertiary-container: '#585be6'
  on-tertiary-container: '#f1eeff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#e1e0ff'
  tertiary-fixed-dim: '#c0c1ff'
  on-tertiary-fixed: '#07006c'
  on-tertiary-fixed-variant: '#2f2ebe'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
  background-dark: '#0F172A'
  surface-dark: '#1E293B'
  border-slate: '#E2E8F0'
  data-highlight: '#D1FAE5'
typography:
  headline-xl:
    fontFamily: Geist
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Geist
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Geist
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  code-md:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
  max-width: 1440px
---

## Brand & Style

This design system is built for a high-performance SaaS environment focused on precision and technical reliability. The aesthetic is **Corporate Modern** with a focus on functional clarity, heavily inspired by the "Tools for Thought" movement. It balances the rigor of data-heavy interfaces with the approachability of a modern productivity suite.

The primary goal is to foster trust through a "calm" interface—using ample whitespace, refined typography, and subtle glassmorphism to prevent the complexity of OCR and data classification from overwhelming the user. Visual interest is achieved through vibrant accent colors for data status, while the structural elements remain neutral and disciplined.

## Colors

The palette is anchored by "Trust Blue" for primary interactions and "Success Green" for validated data points. 

In **Light Mode**, surfaces are primarily white or very light grey (#F8FAFC) to maintain a clean, document-centric feel. Borders use a subtle slate to define structure without adding visual noise. 

In **Dark Mode**, the interface shifts to a deep navy (#0F172A). The primary blue and emerald accents increase in vibrance to maintain accessibility. Data extraction highlights use semi-transparent overlays of the success green to allow underlying text to remain legible while indicating processing status.

## Typography

The typography system uses a tri-font approach to differentiate between intent:
- **Geist** is used for headlines and primary UI headers, providing a sharp, technical, and modern look.
- **Inter** handles all body copy and standard UI controls, chosen for its exceptional legibility and neutral tone.
- **JetBrains Mono** is reserved for code snippets, JSON outputs, and raw OCR data previews, signaling to the user that they are looking at "raw" or "system" information.

Hierarchy is strictly enforced through weight and letter spacing rather than excessive size variations, ensuring the UI remains dense enough for expert workflows.

## Layout & Spacing

The design system utilizes a **fluid grid** with a maximum content width of 1440px. The internal rhythm is based on a 4px baseline grid to ensure alignment between text and technical icons.

- **Desktop:** A 12-column grid with 24px gutters. Sidebars are fixed at 280px to accommodate complex navigation and document trees.
- **Tablet:** An 8-column grid with 16px gutters. Sidebars collapse into a drawer or icon-only rail.
- **Mobile:** A 4-column grid with 16px margins. Information density is reduced, prioritizing the document preview and primary status indicators.

Padding within components (cards, inputs) follows a stepped scale: 8px (xs), 12px (sm), 16px (md), 24px (lg).

## Elevation & Depth

Hierarchy is established through **Tonal Layers** supplemented by **Glassmorphism** for transient elements.

- **Surface Level 0:** The main background (#F8FAFC / #0F172A).
- **Surface Level 1:** Primary cards and content containers. Use a subtle 1px border (#E2E8F0) and no shadow for a "flat" workspace feel.
- **Surface Level 2 (Floating):** Modals, dropdowns, and tooltips. These utilize a backdrop-blur (12px) and a very soft, diffused shadow (0 10px 15px -3px rgba(0,0,0,0.1)) to sit above the workspace.

In Dark Mode, elevation is communicated by increasing the lightness of the surface color rather than increasing shadow opacity, maintaining clarity in deep-toned environments.

## Shapes

The shape language is sophisticated and approachable, characterized by **Rounded (xl)** corners.

- **Buttons & Inputs:** Use the standard 0.5rem (8px) radius.
- **Large Containers & Cards:** Use the `rounded-xl` setting (1.5rem / 24px) to create a distinct, modern "soft-tech" silhouette.
- **Status Tags:** Use a full pill-shape to distinguish them from interactive buttons.

This high degree of roundedness on large containers softens the technical nature of the software, making it feel more like a consumer-grade productivity tool.

## Components

- **Buttons:** Primary buttons use a solid "Trust Blue" fill with white text. Secondary buttons use a ghost style (border only) to maintain low visual weight.
- **Input Fields:** Large, 12px vertical padding, with a subtle blue focus ring. Labels always use the `label-caps` typography style.
- **Data Tables:** High-contrast rows with `body-sm` typography. Header rows use a light grey tint (#F1F5F9) and sticky positioning for long data sets.
- **Extraction Highlights:** Validated data fields should be wrapped in a Success Green tint with 10% opacity and a 1px solid border of the same color.
- **JSON Previews:** Housed in a Level 1 surface with a monospace font. Keywords should be color-coded using the secondary and tertiary palette.
- **Status Indicators:** Small circular dots accompanied by pill-shaped badges (e.g., "In Progress" in Blue, "Error" in Red, "Verified" in Green).