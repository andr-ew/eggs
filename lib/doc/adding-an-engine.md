# adding an engine

is there an engine missing from the list? it's because you haven't added it yet!

here I'll go through the steps of how I added [molly the poly](https://github.com/markwheeler/molly_the_poly) to eggs, and hopefully that'll help you do the same

## STEP 1: copy & paste

in maiden, pull up the folder for eggs, drop into the `lib/` file and pull up the aptly titled `engines.lua` file. right at the top, you'll see a chunk of code (the first `do [...] end` pair) that adds the `polysub` engine & also serves as an example for how to add a new engine:

```lua
do
    local name = 'polysub'               -- first, define a user-facing name for the engine
    table.insert(engine_names, name)     -- then add it to the engine_names list

    init_engine[name] = function()       -- then, define a function that will initialize the engine
                                         --     on launch, when it is the chosen engine
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

so first step, we need to know what to assign to `engine.name` – this is the easiest bit. in the case of molly, all I had to do was pull up the main `molly_the_poly.lua`
