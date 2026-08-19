# Wayfolio Native Creature Animation Prototype

## Status

This branch contains the first in-app SpriteKit creature-animation experiment for Pufftail Fox.

The goal is to test whether lightweight native deformation can support persistent Wayfolio creature idles without prerecorded video or generative-video credits.

## Where to find it

Run the app and open:

**More → Animation Lab**

The prototype is intentionally isolated from authoritative campaign state and creature discovery mechanics.

## Implementation

- SwiftUI hosts the prototype through `SpriteView`.
- SpriteKit renders at up to 60 fps.
- One Pufftail sprite is deformed using a 12×12 `SKWarpGeometryGrid`.
- Lower legs, paws, cheeks, and face are treated as stability regions.
- Tail motion increases toward the outer mass/tip.
- Ears move locally above their bases.
- Breathing is limited to the upper chest.
- The display leaves generous motion-safe margins around ears, tail, paws, and shadow.
- A motion-intensity slider is included for evaluation.
- Reduce Motion automatically lowers motion intensity.

## Prototype art

Asset catalog entry:

`Assets.xcassets/pufftail-fox-rig.imageset`

The image on this branch is a reduced/quantized prototype asset so the native rendering path can be validated quickly. It is not the final production-resolution Pufftail master.

## Acceptance questions

Evaluate on an actual iPhone or simulator:

1. Does the deformation remain attached to the original illustration without visible seams?
2. Do the ears still look as convincing as the earlier exported tests?
3. Does the tail feel continuous rather than like a flat region being smeared?
4. Do the legs, paws, cheeks, and eyes remain visually stable?
5. Is chest breathing perceptible without disturbing the stance?
6. Does the creature remain fully inside its motion-safe frame at all times?
7. Does 60 fps remain smooth on the target device?
8. Does reducing the Motion slider help identify the best idle amplitude?

## Deliberate omissions

This first native test does **not** attempt a blink. The previous flat-image blink experiments demonstrated that high-quality eye animation requires separated eye/lash/iris artwork. Blink should be added only after an animation-ready Pufftail face asset is prepared.

Likewise, this test does not alter campaign state, consume Firefly credits, or become approved creature-animation canon merely by existing in the branch.

## Next step if successful

If native SpriteKit deformation passes the visual test, promote the approach into a reusable `CreatureAnimationView`/rig-profile system and define the first archetype:

**Wayfolio Small Quadruped Rig v1**

If the single-sprite warp still produces unacceptable distortion, retain SpriteKit for particles/effects and move premium creature body rigs to prepared layered assets / Live2D rather than continuing broad bitmap warping.
