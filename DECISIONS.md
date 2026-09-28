# Decisions log

- Engine: Godot 4.7.2-stable (latest stable 4.x on 2026-09-28), official Linux binary + export templates from godotengine/godot releases.
- Test framework: GUT 9.7.1 (the release line built for Godot 4.7), vendored in addons/gut.
- Fonts: Assistant (variable, wght) and Karantina (Regular, Bold) downloaded from google/fonts; both OFL.
- Branching: work happens on the session branch `ccr-0b39504f-tn7ykv` and every milestone is also pushed to `main` as the owner requested; the release tag is cut from main.
