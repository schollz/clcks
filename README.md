## clcks

punch-in tempo-locked repeating.

![image](https://user-images.githubusercontent.com/6550035/91256096-4a020100-e71b-11ea-82a6-3b2ef258fbec.gif)

this is a tempo-locked repeater or "stutter" effect that can be punched-in during live performance. this effect is inspired by the op-1's chop" [tape trick](https://teenage.engineering/guides/op-1/tape-mode). i like "chop" but the op-1 stops the playing loop when this effect is activated. for *clcks* i wanted a similar effect without stopping the playing loop.

i also used softcut to improve the "chop" effect, by allowing it to be pitched up/down and leveled up/down in realtime. this gives all sorts of new effects, and can even recreate the op-1's tape tricks by setting the final level&pitch down, all without losing position in the loop.

future plans: 

- fix panning issue?
- fix "click" sound on slower delays
- add ping-pong panning?


### Requirements

- audio input
- norns

### Documentation

- press K2 or K3 to activate
- press K2 or K3 to deactivate
- (K2 keeps monitoring audio)
- E1 changes repeat number
- E2/E3 change final level/rate
- hold K1 to shift
- shift+E2 changes tempo
- shift+E3 changes beat subdivision
- shift+K2 resets parameters
- shift+K3 randomizes

other notes:

- max repeats means infinite repeating, so you have to toggle off with K2 or K3

## my other patches

- [barcode](https://github.com/schollz/barcode): replays a buffer six times, at different levels & pans & rates & positions, modulated by lfos on every parameter.
- [blndr](https://github.com/schollz/blndr): a quantized delay with time morphing

## license 

mit 