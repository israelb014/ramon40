# Decisions log

- Engine: Godot 4.7.2-stable (latest stable 4.x on 2026-09-28), official Linux binary + export templates from godotengine/godot releases.
- Test framework: GUT 9.7.1 (the release line built for Godot 4.7), vendored in addons/gut.
- Fonts: Assistant (variable, wght) and Karantina (Regular, Bold) downloaded from google/fonts; both OFL.
- Branching: work happens on the session branch `ccr-0b39504f-tn7ykv` and every milestone is also pushed to `main` as the owner requested; the release tag is cut from main.
- Tracks are closed circuits (laps need a loop): each real road is reshaped into a loop that keeps its character (Route 40 rim + switchbacks + crater floor; Route 90 shore + cliff-foot return; Route 1 forested descent with tunnels + climb).
- Road elevation comes from designed control-point heights (grade-limited to 9.5%); the natural terrain is shifted by a smooth correction field so the road sits in the landscape, then blended locally into cuts and fills.
- Bike physics uses its own integrator on top of track/heightmap queries instead of Godot's rigid bodies: deterministic, cheap for 8 bikes at 120 Hz, and unit-testable headless.
- AI steering uses pure pursuit measured from a predicted heading (current lean's effect 0.32 s ahead) with a speed-scaled look-ahead; this removed high-speed weave caused by lean lag.
- Rider assist (ABS-like lever modulation, lean capped to grip) defaults to 0.55 for humans and 1.0 for AI; with less assist over-braking or over-leaning can crash.
- Arabic line on direction signs is omitted: the bundled OFL fonts (Assistant, Karantina) have no Arabic glyphs; signs show Hebrew + English.
- Default race length: 2 laps on Ramon and Jerusalem, 3 on the Dead Sea (about 4-5 minutes each).
- Development rendering checks run on lavapipe (software Vulkan) under Xvfb inside the build container.
