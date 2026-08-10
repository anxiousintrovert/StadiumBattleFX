# StadiumBattleFX 1.0.7 - Stadium faint animations

This update adds Stadium-model faint presentation for both sides of battle.

## Added

- Player and opponent Pokemon now queue their held Stadium faint animation
  when they faint.
- The animation starts only after Gen1Recomp finishes draining the HP bar, so
  the model falls at the same readable moment as the battle presentation.
- The integration is capability-checked: older Dramaless Shape versions keep
  their normal faint behavior without interrupting battles.

## Requirements

For the new model faint animation, install a Dramaless Shape release that
exports the Stadium faint bridge. StadiumBattleFX 1.0.7 remains safe to
install alongside older companion versions.
