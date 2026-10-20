# AGENTS

- Keep business logic in providers and logic files; avoid putting feature behavior directly in widgets.
- Keep files compact and split by responsibility so they stay under roughly 150 lines when practical.
- Follow the shared glass UI conventions from core/theme/glass_style.dart and core/theme/app_theme.dart.
- Add new feature logic inside the existing feature folder unless a genuinely new capability needs a new top-level feature area.
- Mock transport and chaos-simulation logic lives in lib/features/transmission_engine/logic and is driven by lib/features/network_simulator/providers; extend those files instead of adding transport behavior directly to widgets.
- Compress payloads before encryption in the transmission pipeline so the gzip/DEFLATE step actually reduces size; do not encrypt first and then compress.
- Transmission order is raw payload -> positional schema/tuple encoding with no field names -> max-level gzip/DEFLATE -> encryption -> XOR/Reed-Solomon-style redundancy -> chunking; log real byte counts at each stage.
- Packet loss simulation must use independent random loss rolls per chunk, with optional seeds only for tests; live app/demo behavior should remain unseeded and non-deterministic.
- Recovery is bounded by redundancy math: a group with loss beyond its parity/correction capacity must report partial or failed recovery instead of fabricating success, and confidence must come from actual recovered groups.
- Urgency is a manual intake flag that flows through the patient model, transmission engine, queue state, and integrity log so urgent cases are visibly treated differently without introducing AI inference.
- Patient storage uses a compare-then-overwrite rule: stage local captures as pending, compare deltas against the last confirmed database baseline, and overwrite that baseline only after specialist-side reconstruction is confirmed successful.
- ClinicalAlert is the mandatory component for any user-facing status event going forward; do not write custom SnackBar toasts or inline banners.
- All status, priority, sync, and transport indicators must use StatusPill; do not write ad-hoc colored text badges or raw Chip widgets.
