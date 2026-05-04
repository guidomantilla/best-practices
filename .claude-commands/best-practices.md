---
description: Discover, get advice on, or learn how to use the best-practices assessment skills installed in this project.
---

Invoke the `overview` skill and let it select the appropriate mode based on the user's prompt:

- **No args** (`/best-practices`) → Default catalog: render the full skills table.
- **`--ask`** or natural-language equivalents like *"asesorame qué corro"* → Advisory mode: ask 4 short context questions, then recommend 1–2 skills (do not run them).
- **A skill name as the first arg** (e.g., `/best-practices assess-iac`) → How-to mode: focused page for that skill (scope + 2–3 recommended invocation patterns + pointer to its `What I Can Generate`).

The overview skill knows how to dispatch — just delegate the prompt to it without modification.
