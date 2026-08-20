# StadiumBattleFX 2.1.8

This maintenance release keeps the public Battle Presentation context aligned
with the live Pokemon after a trainer switch or replacement.

Gen1Recomp replaces a side's battler object during those transitions. StadiumBattleFX
now refreshes the context supplied to registered presentation providers before
their lifecycle calls, so external arena, model, camera, effects, HUD, overlay,
transition, and announcer providers cannot retain the outgoing Pokemon.

This is a compatibility and API-correctness update. It does not change the
Stadium model renderer's send-out visibility behavior.
