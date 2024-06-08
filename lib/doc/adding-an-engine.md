# adding an engine

is there an engine missing from the list? it's because you haven't added it yet!

here I'll go through the steps of how I added [molly the poly](https://github.com/markwheeler/molly_the_poly) to eggs, and hopefully that'll help you do the same

## STEP 1: copy & paste

in maiden, pull up the folder for eggs, drop into the `lib/` file and pull up the aptly titled `engines.lua` file. right at the top, you'll see a chunk of code (the first `do [...] end` pair) that adds the `polysub` engine & also serves as an example for how to add a new engine:

```lua
do
    local nickname = 'polysub'               -- first, define a user-facing name for the engine
    table.insert(engine_names, nickname)     -- then add it to the engine_names list

    init_engine[nickname] = function()       -- then, define a function that will set up the
                                             --     engine on launch, when it is the chosen engine
                                             --     this function should usually do 4 things:

        engine.name = 'PolySub'                   -- 1: set engine.name to the proper engine name

        local polysub = require 'engine/polysub'  -- 2: include/require any files needed for params
        polysub:params()                          -- 3: call the function to add the params

                                                  -- 4: define callbacks for note on/off:
        function eggs.noteOn(note_number, hz)   
            engine.start(note_number, hz)          -- call the note on function for the engine here
        end
        function eggs.noteOff(note_number)
            engine.stop(note_number)               -- call the note off function for the engine here
        end
    end
end
```

copy this chunk & plop it at the bottom of the script, **right before** the line that goes `return engine_names, init_engine`

the comments on the chunk should more or less explain what each line does, so we'll focus on the part where we scan through another lua script, to find the relavant bits that go here.

## STEP 2: engines have names

so the first step is that we just assign that `nickname` variable to the name of our engine. this is the name that'll be displayed under the list in the norns menu, so it makes sense to keep it lowercase:
```
local nickname = 'molly the poly'
table.insert(engine_names, nickname)     -- no changes needed on this line, but be sure to include it!
```
(this is a lua [string](https://monome.org/docs/norns/study-1/#numbers-and-strings), so don't forget the air quotes. both `'` and `"` work, but don't mix & match.)

the rest of the action happens inside a function that we're defining, which will run when the script is started or restarted

next, we need to know the proper name of the engine to assign to the `engine.name` variable. this line is responsible to launching the correct supercollider engine, so we'll need to check the original lua script to make sure we're setting this to the correct name. in the case of molly, all I had to do was pull up the main `molly_the_poly.lua`, and Ctrl+F for "engine.name". I found our `engine.name` to be none other than `"MollyThePoly"`:

```lua
engine.name = 'MollyThePoly'
```
often this name is just the name of the script, but in CamelCase rather than snake_case.

## STEP 3: add the params

so this can be a bit trickier to find, usually synthesizer-style engines come with some sort of "helper function" that creates all the params that interact with the engine, it'll probably be called something like `my_engine.params()` or `MyEngine:add_params()`. as a guess, I checked molly's `init()` function and I'm pretty sure I've found what I'm looking for – `MollyThePoly.add_params()`. but just to be sure – I searched the script for a table called `MollyThePoly`, found that it was getting pulled in from the file `lib/molly_the_poly_engine.lua`, then searched in that file for a function called `add_params`. as I expected, looks like this function is creating a bunch of `control` params that call different engine commands, like `engine.pwMod` – so that checks out.

to get all these params populating in eggs like they are in molly_the_polly, we'll need to do two things. first, I need to import the function by `include`-ing the `MollyThePoly` table into eggs:
```lua
local MollyThePoly = include 'molly_the_poly/lib/molly_the_poly_engine'
```
that `local` bit just means that the rest of the script outside of this function won't have access to the table (it's our little secret)

then, just call the param-adding function:
```lua
MollyThePoly.add_params()
```

## STEP 4: hook up the notes

now we need to actually tell eggs how to communicate with the engine to trigger notes on & off. each engine is a little bit different so it needs to be defined by us. to do this, we create two functions called `eggs.noteOn` & `eggs.noteOff` (which we've copied & pasted), and inside those functions we call the proper engine functions that perform these tasks.



