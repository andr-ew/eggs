# eggs (beta)

is an egg a type of seed?

a multi-track gesture sequencer for norns, grid, crow, midi, and internal sounds (beta). four tracks of manual, droning, or arquenced pitch, many tunings, midi, just friends communication + slewed pitch & function generators for crow

a spiritual successor to [synecdoche](https://github.com/andr-ew/prosody?tab=readme-ov-file#synecdoche)

## hardware

**required**

- [norns](https://github.com/p3r7/awesome-monome-norns) (220321 or later)
- [grid](https://monome.org/docs/grid/) (128 or 64)

**also supported**

- midi
- crow
- [just friends](https://www.whimsicalraps.com/products/just-friends) (synth mode)
- anything supported by [nb](https://llllllll.co/t/n-b-et-al-v0-1/60374)

## install

in the maiden [REPL](https://monome.org/docs/norns/image/wifi_maiden-images/install-repl.png), type:

```
;install https://github.com/andr-ew/eggs/releases/download/latest/complete-source-code.zip
```

## grid UI

![diagram of the grid interface. text description forthcoming](/lib/doc/eggs.png)
![diagram of the 64 grid interface. text description forthcoming](/lib/doc/eggs_64.png)

**track focus:** selects tracks 1-4. by default, tracks are as follows, but each track can also be assigned to midi or [nb](https://llllllll.co/t/n-b-et-al-v0-1/60374):

| | |
| -- | -- |
| engine | just friends |
| crow 1 + 2 | crow 3 + 4 |

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
  - **E2-E3**: [macro](#macros)
  - **K2-K3:** macro focus
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
  - **K3:** function generator - trigger. hold: trigger patching on/off
- **K1 (hold):** set [mod source](#modulation)

**view:** scale
- **E1:** scale
- **E2:** row tuning
- **K2-3:** fret marks

**view:** key
- **E1:** tuning system
- **E2:** base key

## modulation

most params on screen + grid can be mapped to one of 4 modulation sources:
- crow input 1
- crow input 2
- track 3 cv (crow output 1)
- track 3 gate (crow output 2)

to map an on-screen param, just hold K1 and turn the encoder or press the key of the associated param. to map a param on the grid, hold K1 and tap any of the keys associated with that param

## engines

the midi track(s) can optionally be routed to an internal supercollider engine running on norns itself. currently there is a choice of three engines selectable via the **engine** param:
- polysub
- [orgn](https://github.com/andr-ew/orgn)
- [molly the poly](https://llllllll.co/t/molly-the-poly/21090)

if there's an engine you'd like to use with eggs that's not included in this list, I've written some [instructions](lib/doc/adding-an-engine.md) on how to add one.

## macros

on the midi track(s), there are 3 pages of macros. these macros can be assigned to address either an outgoing midi cc, or any param found in the selected engine or n.b. voice. configuration is found under PARAMS > midi out [#] > macros. if using midi CC you can set the CC# of each of the CCs available using the "address" params.
