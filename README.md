# eggs (beta)

multi-track pitch gesture looper for norns, grid, and crow (beta)
 
## hardware

**required**

- [norns](https://github.com/p3r7/awesome-monome-norns) (220321 or later)
- [grid](https://monome.org/docs/grid/) (128 or 64)
- crow (main variant only)

**also supported**

- midi

## install

in the maiden [REPL](https://monome.org/docs/norns/image/wifi_maiden-images/install-repl.png), type:

```
;install https://github.com/andr-ew/eggs/releases/download/latest/complete-source-code.zip
```

## grid UI

![diagram of the grid interface. text description forthcoming](/lib/doc/eggs.png)
![diagram of the 64 grid interface. text description forthcoming](/lib/doc/eggs_64.png)

**track focus:** in the main variant, tracks are as follows:

| | |
| -- | -- |
| midi | just friends |
| crow 1 + 2 | crow 3 + 4 |

in **eggs/midi-only**, all tracks are midi

**keymap:** grid keyboard. edit the tuning using **scale** & **key**

**slew:** hold to enable pitch slew. 8 keys to the right select slew time

**latch:** make it drone

**arquencer:** the arquencer is a mix between an arpeggiator & a sequencer. here are some ways to interact with it:

- **hold & release multiple keys:** creates a new arq (clears any previous keys). notes are played in the order they are pressed, including double-presses on the same key.
- **single tap**
   - (blank key): insert a note at the current point in the arquence
   - (active key): mute gate at note
- **double tap:** add repeat to note
- **hold single key:**
   - (repeated key): remove repeat
   - (active key): remove note

**scroll columns:** transpose up or down one degree within the current scale. this shifts your view of the keyboard left or right.

**scroll rows:** transpose up or down based on the **row tuning** interval. this shifts your view of the keyboard up or down.

**pattern slots:** slots for recording input sequences on the keymap. use them like this:

- **single tap**
  - (blank pattern): begin recording
  - (recording pattern): end recording, begin looping
  - (playing pattern): play/pause playback. only one slot is active at a time
- **double tap:** overdub pattern
- **hold:** clear pattern

**snapshots:** snapshots to store & recall chords or arquences. use them like this:

- **double tap:** write to slot
- **single tap** read from slot
- **hold:** clear slot (latch & arquence only)

**reverse & rate:** set the direction & playback rate of the current pattern or arquence.

**loop:** enable looping of the pattern/arquence

**scale:** hold to edit the scale & other stuff

**key:** hold to edit the key / tonic

## norns UI

**view:** normal
- **track 1: midi**
  - **E1:** midi destination
- **track 2: jf**
  - **E1:** shift (linear pitch offset, map for vibrato)
  - **E2:** note level
  - **E3:** run voltage
  - **K2:** synth mode. hold: run mode
  - **K3:** panic. hold: god mode
- **tracks 3 + 4: crow**
  - **E1:** function generator - time
  - **E2:** function generator - shape
  - **E3:** function generator - ramp
  - **K2:** function generator - transient/sustain/cycle. hold: retrigger
- **K1 (hold):** set mod source
  - currently most params on the crow / jf screens can be mapped to either input of crow. select source using the encoders & keys

**view:** scale
- **E1:** scale
- **E2:** row tuning
- **E3:** midi in
- **K2-3:** fret marks

**view:** key
- **E1:** tuning system
- **E2:** base key
- **E3:** 0v pitch 
