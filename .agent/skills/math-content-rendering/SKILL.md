---
name: math-content-rendering
description: >
  When rendering math content, HTML theory pages, LaTeX formulas, or question/answer widgets
  in the Mathiq app. Use this skill when working with flutter_widget_from_html,
  flutter_html, flutter_math_fork, flutter_markdown_latex, or the theory card system.
  Also trigger when the user mentions HTML rendering, math formulas, theory content display,
  or question widgets for MCQ/fill-in-blank answers.
---

# Math Content Rendering

## When to use

- Displaying HTML theory content in study stages
- Rendering LaTeX math formulas
- Building question/answer widgets (MCQ, fill-in-blank)
- Styling HTML content for children's readability

## Packages Used

| Package | Purpose |
|---|---|
| `flutter_widget_from_html` | Primary HTML renderer with widget factory support |
| `flutter_widget_from_html_core` | Core rendering engine |
| `flutter_html` | Secondary HTML renderer (legacy usage) |
| `flutter_math_fork` | LaTeX math formula rendering |
| `flutter_markdown` | Markdown content display |
| `flutter_markdown_latex` | Mixed markdown + LaTeX support |
| `html` (dart) | Server-side HTML parsing for preprocessing |

## Theory Content Pipeline

Theory content flows through a preprocessing pipeline before rendering:

```
Raw HTML → TheoryHtmlFormatter.preprocess() → Cards → Styled HTML → flutter_widget_from_html
```

### Step 1: Preprocessing (TheoryHtmlFormatter)

The formatter splits raw HTML into "section cards" based on headings:

```dart
class TheoryHtmlFormatter {
  String preprocess(String html) {
    // Parse HTML, split at h1/h2/h3 boundaries
    // Wrap each section in <div class="section-card">
    // Downgrade heading levels (h1→h2, h2→h3)
    // Convert ul/ol to styled paragraphs
    // Wrap code blocks in example-box divs
  }

  CardType classifyCard(String cardHtml) {
    // CardType.example — if contains <img>, <svg>, <figure>
    // CardType.formula — if heading contains math operators
    // CardType.theory — default
  }

  List<CardData> splitIntoCards(String html) {
    // Returns list of CardData(html, type) for card-based UI
  }
}
```

### Step 2: Styling (TheoryHtmlStyles)

Custom CSS-like styles applied via the HTML renderer's style system. Target children ages 6-11:
- Large font sizes (16-18sp body text)
- High contrast colors
- Generous spacing
- Rounded containers for examples and formulas

### Step 3: Rendering

Use `flutter_widget_from_html` for the final render:

```dart
HtmlWidget(
  processedHtml,
  textStyle: TextStyle(fontSize: 16),
  customStylesBuilder: (element) {
    // Apply custom styles based on class names
  },
  customWidgetBuilder: (element) {
    // Return custom widgets for special elements
    // e.g., math formulas, interactive elements
  },
)
```

## LaTeX Math Rendering

For inline or block math formulas:

```dart
import 'package:flutter_math_fork/flutter_math.dart';

// Inline math
Math.tex(r'\frac{1}{2} + \frac{1}{3} = \frac{5}{6}')

// With styling
Math.tex(
  r'2x + 3 = 7',
  textStyle: TextStyle(fontSize: 20, color: Colors.black),
)
```

## Question/Answer Widgets

### MCQ (Multiple Choice)

Use letter bubbles (A, B, C, D) to reduce reading for young children:

```dart
// Shared widget: game_answer_tile.dart
// Shows letter bubble + answer text
// Animates on selection (scale + color change)
// Shows correct/incorrect feedback after submission
```

### Fill-in-the-blank

Interactive input fields embedded within the question text.

### Feedback

Use `game_feedback_bottom_sheet.dart` — shared bottom sheet that shows:
- Correct/incorrect status with animation
- Simplified explanation
- "Continue" button

## Content Types

| Card Type | Visual Treatment |
|---|---|
| `theory` | White card with text, generous padding |
| `formula` | Highlighted background, centered math |
| `example` | Bordered card with images/diagrams |

## Common Traps

- **HTML entities not decoded** — use `html` package to parse, not raw string manipulation
- **LaTeX in HTML** — extract LaTeX from HTML, render separately with `flutter_math_fork`
- **Performance with long content** — use `ListView.builder` for card-based theory, not a single long scroll
- **Image sizing** — constrain images to screen width, use `BoxFit.contain`
- **Vietnamese diacritics** — ensure fonts support full Vietnamese character set
