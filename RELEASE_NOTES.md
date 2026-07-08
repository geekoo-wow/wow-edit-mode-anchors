# EditModeAnchors 1.1.4
## Midnight
### Fixes
- Party/Raid (and Boss/Arena) unit frame anchor overrides no longer revert to UIParent after saving Edit Mode changes. Blizzard's Edit Mode forces these frames back to a UIParent-relative anchor on every save; the addon now detects and restores custom anchors immediately after.
### Known Issues
- Documented that using Edit Mode's Share > Copy to Clipboard feature after changing an anchor override can trigger a "blocked from an action only available to the Blizzard UI" error, along with the workaround. See the README for details.

# EditModeAnchors 1.1.0
## Midnight
### Fixes
- Now works for systems that have sub systems (eg. new cooldown manager stuff) - Thanks to Pingumania for the PR.

# EditModeAnchors 1.0.1
## Midnight
### Fixes
- Minor fixes.
- Remove chat hint about debug.
- Remove references to old name (HyperEditMode)

# EditModeAnchors 0.1.0-alpha
## Midnight
### New
- First release of the addon.
- Basic featureset, including:
  - Anchor point selection
  - Relative frame selection
  - Offset controls
  - Debug logging

# EditModeAnchors 1.0.0
## Midnight
### New
- Promoting pre-release to 1.0.0
- Basic featureset, including:
  - Anchor point selection
  - Relative frame selection
  - Offset controls
  - Debug logging
