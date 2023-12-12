# eggs (0.2.0)

pitch gesture looper for norns + grid

## hardware

**required**

- [norns](https://github.com/p3r7/awesome-monome-norns) (220321 or later)
- [grid](https://monome.org/docs/grid/) (128)
  - other grid sizes forthcoming

**also supported**

- midi

note that the last version supported crow & jf. they're coming back later

## install

in the maiden [REPL](https://monome.org/docs/norns/image/wifi_maiden-images/install-repl.png), type:

```
;install https://github.com/andr-ew/eggs/releases/download/latest/complete-source-code.zip
```

## grid UI

![diagram of the grid interface. text description forthcoming](/lib/doc/eggs_grid.png)

**keymap:** grid keyboard. edit the tuning using **scale** & **key**

**latch:** make it drone

**arquencer:** the arqueggiator is a mix between an arpeggiator & a sequencer. here are some ways to interact with it:

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


