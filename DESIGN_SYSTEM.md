# BrisConnect+ Design System Documentation

## Overview

This document outlines the comprehensive design system implemented across all BrisConnect+ platforms: website, web admin dashboard, mobile app (iOS/Android), and desktop app (macOS).

---

## Color Palette

### Primary Colors

| Color | Hex | RGB | Usage |
|-------|-----|-----|-------|
| **Ochre** | `#C1440E` | RGB(193, 68, 14) | Primary CTA buttons, focus states, accents |
| **Gold** | `#D4A017` | RGB(212, 160, 23) | Secondary accents, hover effects, highlights |
| **Deep Blue** | `#1E3A5F` | RGB(30, 58, 95) | Headings, navigation, premium content |
| **Brown** | `#5C3D2E` | RGB(92, 61, 46) | Earthy accents, decorative elements |

### Neutral Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Surface** | `#FFFDF8` | Main content background (near-white) |
| **Background** | `#F7F4ED` | Page background (warm cream) |
| **Surface Alt** | `#FFF8EA` | Secondary background (warm gold tint) |
| **Charcoal** | `#2B2B2B` | Body text, primary text color |
| **Muted Text** | `#6B675F` | Secondary text, captions, subtitles |
| **Border** | `#E4D8C4` | Card borders, dividers |
| **Card Shadow** | `#16000000` | Soft shadows with transparency |

### Semantic Colors

| Color | Usage |
|-------|-------|
| **Red (#FF4444)** | Errors, deletions, destructive actions |
| **Green (#4CAF50)** | Success, confirmations, trends |
| **Amber (#FFC107)** | Warnings, alerts |
| **Blue (#2196F3)** | Information, links, secondary actions |

---

## Typography

### Font Family
- **Primary**: Google Fonts (system fallback: San Francisco, Segoe UI)
- **Fallback**: System default sans-serif

### Type Scales

#### Desktop (Web)
- **H1**: 32px, 700 weight, Deep Blue color
- **H2**: 28px, 700 weight, Charcoal color
- **H3**: 24px, 600 weight, Deep Blue color
- **Body**: 15px, 400 weight, Charcoal color
- **Caption**: 12px, 400 weight, Muted Text color

#### Mobile (Flutter)
- **Title Large**: 24px, 700 weight
- **Title Medium**: 20px, 600 weight
- **Body Large**: 16px, 400 weight
- **Body Medium**: 14px, 400 weight
- **Label**: 12px, 500 weight

---

## Components

### 1. Cards & Containers

#### Feature Cards (Website)
```css
.feature-card {
  background: white;
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 4px 15px rgba(212, 165, 116, 0.15),
              0 2px 8px rgba(0, 0, 0, 0.08);
  border-top: 3px solid #D4A574;
  transition: all 0.3s ease;
}

.feature-card:hover {
  border-top: 3px solid #C4A050;
  box-shadow: 0 8px 25px rgba(212, 165, 116, 0.25),
              0 4px 12px rgba(0, 0, 0, 0.12);
  transform: translateY(-2px);
}
```

#### Attraction/Event Cards (Mobile)
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border(
      top: BorderSide(
        color: AppPalette.ochre.withValues(alpha: 0.4),
        width: 3,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 18,
        offset: Offset(0, 6),
      ),
      BoxShadow(
        color: AppPalette.ochre.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: Offset(0, 3),
      ),
    ],
  ),
)
```

#### Stat Cards (Admin Dashboard)
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppPalette.ochre.withValues(alpha: 0.1),
        AppPalette.gold.withValues(alpha: 0.05),
      ],
    ),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: AppPalette.ochre.withValues(alpha: 0.15),
      width: 1,
    ),
  ),
)
```

### 2. Buttons

#### Primary Button (CTA)
```css
.btn-primary {
  background: linear-gradient(135deg, #D4A574, #C4A050);
  color: white;
  padding: 12px 24px;
  border-radius: 28px;
  border: none;
  font-weight: 600;
  font-size: 16px;
  box-shadow: 0 4px 15px rgba(212, 165, 116, 0.3);
  cursor: pointer;
  transition: all 0.3s ease;
}

.btn-primary:hover {
  box-shadow: 0 6px 20px rgba(212, 165, 116, 0.4);
  transform: translateY(-2px);
}

.btn-primary:active {
  transform: translateY(0);
  box-shadow: 0 2px 8px rgba(212, 165, 116, 0.2);
}
```

#### Secondary Button
```css
.btn-secondary {
  background: rgba(255, 255, 255, 0.15);
  color: white;
  border: 2px solid #C4A050;
  backdrop-filter: blur(10px);
  padding: 12px 24px;
  border-radius: 28px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}

.btn-secondary:hover {
  background: rgba(212, 160, 23, 0.2);
}
```

#### Mobile Button Styles
```dart
// Primary
ElevatedButton.styleFrom(
  backgroundColor: AppPalette.ochre,
  foregroundColor: Colors.white,
  shadowColor: AppPalette.ochre.withValues(alpha: 0.4),
  elevation: 4,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
  minimumSize: Size(double.infinity, 52),
)

// Secondary
OutlinedButton.styleFrom(
  foregroundColor: AppPalette.ochre,
  side: BorderSide(color: AppPalette.gold, width: 2),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
)
```

### 3. Input Fields

#### Text Input (Web)
```css
input, textarea {
  border: 1px solid #E4D8C4;
  border-radius: 12px;
  padding: 12px 16px;
  font-size: 14px;
  background: #FFF8EA;
  transition: border-color 0.3s ease;
}

input:focus {
  outline: none;
  border-color: #C1440E;
  box-shadow: 0 0 0 3px rgba(193, 68, 14, 0.1);
}

input:valid {
  border-color: #4CAF50;
}

input:invalid {
  border-color: #FF4444;
}
```

#### Text Input (Mobile)
```dart
TextFormField(
  decoration: InputDecoration(
    filled: true,
    fillColor: AppPalette.surfaceAlt.withValues(alpha: 0.6),
    hintText: 'Placeholder text',
    prefixIcon: Icon(Icons.email, color: AppPalette.mutedText),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppPalette.ochre, width: 2),
    ),
  ),
)
```

---

## Spacing System

### Consistent Margins & Padding

| Size | Value | Usage |
|------|-------|-------|
| **XS** | 4px | Micro spacing |
| **S** | 8px | Small gaps |
| **M** | 12px | Default padding |
| **L** | 16px | Medium spacing |
| **XL** | 20px | Large spacing |
| **2XL** | 24px | Section spacing |
| **3XL** | 32px | Major sections |

### Examples
- Card padding: 16px
- Section margin: 24px
- Grid gap: 12px
- Button padding: 12px × 24px

---

## Shadows & Depth

### Elevation System

| Level | Box Shadow | Usage |
|-------|-----------|-------|
| **0** | None | Flat elements |
| **1** | `0 1px 3px rgba(0, 0, 0, 0.08)` | Subtle elevation |
| **2** | `0 2px 8px rgba(0, 0, 0, 0.12)` | Medium elevation |
| **3** | `0 4px 15px rgba(0, 0, 0, 0.15)` | Card elevation |
| **4** | `0 8px 25px rgba(0, 0, 0, 0.2)` | Dialog elevation |

### Example: Multi-layer Shadow
```dart
boxShadow: [
  BoxShadow(
    color: const Color(0x14000000),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
  BoxShadow(
    color: AppPalette.ochre.withValues(alpha: 0.08),
    blurRadius: 12,
    offset: Offset(0, 3),
  ),
],
```

---

## Border Radius

| Size | Radius | Usage |
|------|--------|-------|
| **Small** | 8px | Small buttons, badges |
| **Medium** | 12px | Input fields, modals |
| **Large** | 16px | Cards, major containers |
| **Extra Large** | 20px | Attraction cards |
| **Full** | 50px/9999px | Circular buttons, pills |

---

## Responsive Breakpoints

### Website Breakpoints
- **Mobile**: 0-480px
- **Tablet**: 480px-768px
- **Desktop**: 768px-1024px
- **Wide**: 1024px+

### Example: Feature Grid
```css
@media (max-width: 768px) {
  .features-grid {
    grid-template-columns: 1fr;
  }
}

@media (min-width: 768px) {
  .features-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (min-width: 1024px) {
  .features-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}
```

---

## Animations & Transitions

### Standard Duration
- **Quick**: 150ms (micro-interactions)
- **Base**: 300ms (standard transitions)
- **Slow**: 500ms (major transitions)

### Common Easing
- **In**: `cubic-bezier(0.4, 0, 1, 1)` - Accelerating
- **Out**: `cubic-bezier(0, 0, 0.2, 1)` - Decelerating
- **InOut**: `cubic-bezier(0.4, 0, 0.2, 1)` - Natural motion

### Example: Hover Animation
```css
.card {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
}
```

---

## Accessibility Guidelines

### Color Contrast
- **WCAG AA**: Minimum 4.5:1 ratio for text
- **WCAG AAA**: Minimum 7:1 ratio for text
- Text-to-background: Charcoal (#2B2B2B) on Surface (#FFFDF8) = 11.2:1 ✅

### Focus States
- **Visible outline**: 3px solid Ochre (#C1440E)
- **Minimum size**: 44×44px for touch targets
- **Keyboard navigation**: Tab, Enter/Space, Arrow keys

### Screen Readers
- Semantic HTML: `<button>`, `<input>`, `<nav>`
- ARIA labels: `aria-label`, `aria-describedby`
- Image alt text: Descriptive and concise

---

## Implementation Files

### Flutter (Mobile & Desktop)
- **Theme**: `/lib/theme/app_palette.dart`
- **Button Styles**: `/lib/widgets/enhanced_button_styles.dart`
- **Screens Enhanced**:
  - Home Screen: `/lib/screens/home_screen.dart` (_BaseCard)
  - Event Details: `/lib/screens/event_detail_screen.dart`
  - Attractions: `/lib/screens/attractions_screen.dart`
  - Login: `/lib/screens/visitor_login_screen.dart`

### Web (HTML/CSS/JavaScript)
- **Markup**: `/website/index.html`
- **Styles**: Embedded CSS with gradient effects
- **Interactivity**: JavaScript feature card handlers

---

## Color Usage Guidelines

### When to Use Each Color

| Color | When to Use | Example |
|-------|------------|---------|
| **Ochre** | Primary actions, focus states | Submit buttons, card borders |
| **Gold** | Secondary emphasis, hovers | Icons, links, accents |
| **Deep Blue** | Headings, navigation | Page titles, menu items |
| **Brown** | Decorative, earthy context | Backgrounds, subtle accents |
| **Red** | Errors, warnings, deletion | Error messages, delete buttons |
| **Green** | Success, positive actions | Success alerts, confirm buttons |

---

## Brand Voice & Visual Hierarchy

### Typography Hierarchy
1. **Headings (H1-H3)**: Deep Blue, 600-700 weight
2. **Body Text**: Charcoal, 400 weight
3. **Secondary**: Muted Text for captions
4. **Emphasis**: Ochre or Gold for important elements

### Visual Hierarchy (Mobile)
- **Large cards**: 160-200px tall with images
- **Gradient overlays**: Subtle depth on images
- **Top borders**: 3px Ochre accent
- **Shadows**: Multi-layer for elevation

---

## Maintenance Notes

### When Adding New Components
1. Use consistent color palette
2. Apply 3px Ochre top border to major cards
3. Use multi-layer shadows for depth
4. Maintain 16-24px spacing
5. Ensure WCAG AA contrast compliance
6. Test on mobile (iOS/Android) and web

### When Updating Styles
- Update both Flutter and web implementations
- Test across all platforms
- Verify accessibility (focus states, contrast)
- Check responsive behavior

---

## Future Enhancements

- [ ] Dark mode implementation
- [ ] Expanded animation library
- [ ] Advanced gradient effects
- [ ] Micro-interaction patterns
- [ ] Voice/tone guidelines
- [ ] Icon library standardization

---

**Last Updated**: July 8, 2026
**Version**: 1.0
**Status**: Active - All Platforms
