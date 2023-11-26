# eggs (0.2.0)

cv & ii gesture looper for norns, grid, crow, jf.

three track grid keyboard with pattern recording, slew, & built-in ASR envelopes for crow.

## hardware

**required**

- [norns](https://github.com/p3r7/awesome-monome-norns) (220321 or later)
- [grid](https://monome.org/docs/grid/) (128, 64, or midigrid)
- [crow](https://monome.org/docs/crow/)

**also supported**

- [just friends](https://www.whimsicalraps.com/products/just-friends?variant=5586981781533)
- midi

## install

in the maiden REPL, type `;install https://github.com/andr-ew/eggs`

## norns UI

- **CROW**
  - **E1:** envelope - time
  - **E2:** envelope - shape
  - **E3:** envelope - ramp
  - **K2:** envelope - trigger (hold: free/unfree)
  - **K2:** envelope - mode
- **JF**
  - **E1:** transpose
  - **E2:** velocity
  - **E3:** run
  - **K2:** god
  - **K3:** mode
- **MIDI**
  - **E1-3:** midi CC out 
  - **K2:** keyboard in
  - **K3:** panic
- **K1 (hold):** mod source
