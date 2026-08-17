# Zygor 1.12 backport validator

`validate_guides.py` moves exhaustive guide checking out of the live game. It:

- parses every `RegisterGuide` block in the installed guide sources;
- scopes Vanilla race and level 1-60 leveling guides;
- checks quest, creature, item, and game-object IDs against CMaNGOS Classic DB;
- generates `Generated_Vanilla_Manifest.lua` for runtime step applicability;
- excludes only steps whose quest references are entirely absent from 1.12;
- leaves mixed Vanilla/non-Vanilla steps in a review queue;
- validates coordinates and zone-only waypoint fallbacks, then simulates accept,
  objective, turn-in, level, use-item, zone-arrival, and complete-on-arrival
  transitions.

Example:

```powershell
python .\BackportTools\validate_guides.py `
  --addon . `
  --classic-db C:\reference\ClassicDB_1_7_z2684.sql `
  --manifest .\Generated_Vanilla_Manifest.lua `
  --json .\validation.json `
  --markdown .\validation.md
```

The canonical database is maintained at
<https://github.com/classicdb/database> for the 1.12.1 client. The generated
manifest records the database filename and SHA-256 used for reproducibility.
