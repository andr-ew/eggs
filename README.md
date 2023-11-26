# eggs (0.2.0)

cv, ii & midi gesture looper for norns, grid, crow, jf.

four track grid keyboard with pattern recording, arquencer, slew, & built-in ASR envelopes.

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

- **egg: crow**
  - **E1:** envelope - time
  - **E2:** envelope - shape
  - **E3:** envelope - ramp
  - **K2:** envelope - trigger (hold: free/unfree)
  - **K2:** envelope - mode
- **egg: jf**
  - **E1:** transpose
  - **E2:** velocity
  - **E3:** run
  - **K2:** god
  - **K3:** mode
- **egg: midi**
  - **E1-3:** midi CC out 
  - **K2:** note echo
  - **K3:** panic
- **K1 (hold):** set mod source
- **scale**
  - **E1:** scale
  - **E2:** row tuning
  - **E3:** midi in
  - **K2-3:** fret marks
- **key**
  - **E1:** tuning system
  - **E2:** base key
  - **E3:** 0v pitch
