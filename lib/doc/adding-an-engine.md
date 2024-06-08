# adding an engine

is there an engine missing from the list? it's because you haven't added it yet!

here I'll go through the steps of how I added [molly the poly](https://github.com/markwheeler/molly_the_poly) to eggs, and hopefully that'll help you add something else

## STEP 1: copy & paste

in maiden, pull up the folder for eggs, drop into the `lib/` file and pull up the aptly titled `engines.lua` file. right at the top, you'll see a chunk of code (the first `do [...] end` pair) that adds the `polysub` engine & also serves as an example for how to add a new engine:

```lua
do
    local nickname = 'polysub'               -- first, define a user-facing name for the engine
    table.insert(engine_nicknames, nickname) -- add it to the engine_nicknames list

    local name = 'PolySub'                   -- define the proper supercollider engine name
    table.insert(engine_names, name)         -- add it to the engine_names list

    init_engine[nickname] = function()       -- then, define a function that will set up the
                                             --     engine on launch, when it is the chosen engine
                                             --     this function should usually do 4 things:

        local polysub = require 'engine/polysub'  -- 1: include/require any files needed for params
        polysub:params()                          -- 2: call the function to add the params

                                                  -- 3: define callbacks for note on/off:
        function eggs.noteOn(note_id, hz)   
            engine.start(note_id, hz)          -- call the note on function for the engine here
        end
        function eggs.noteOff(note_id)
            engine.stop(note_id)               -- call the note off function for the engine here
        end
    end
end
```

copy this chunk & plop it at the bottom of the script, **right before** the line that goes `return engine_names, init_engine`

the comments on the chunk should more or less explain what each line does, so we'll focus on the part where we scan through the lua script for the other engine, to find the relavant bits that go here.

## STEP 2: engines have names

so the first step is that we just assign that `nickname` variable to the name of our engine. this is the name that'll be displayed under the list in the norns menu, so it makes sense to keep it lowercase:
```lua
local nickname = 'molly the poly'
table.insert(engine_nicknames, nickname)
```
(this is a lua [string](https://monome.org/docs/norns/study-1/#numbers-and-strings), so don't forget the air quotes. both `'` and `"` work, but don't mix & match.)

next, we need to know the proper supercollider name of the engine – this name is responsible for launching the correct supercollider engine, so we'll need to check the original lua script to make sure we're setting this to the correct name. in a normal script, it gets directly assigned to the variable `engine.name`. so in the case of molly, all I had to do was pull up the main `molly_the_poly.lua`, and Ctrl+F for "engine.name". I found our `engine.name` to be none other than `"MollyThePoly"` (often this name is just the name of the script, but in CamelCase rather than snake_case).

so the next two lines should look like this:
```lua
local name = 'MollyThePoly'
table.insert(engine_names, name)
```

## STEP 3: add the params

the rest of the action happens inside an `init_engine` function that we're defining, which will run when the script is started or restarted

this part can be a bit trickier to find, usually synthesizer-style engines come with some sort of "helper function" that creates all the params that interact with the engine. it'll probably be called something like `my_engine.params()` or `MyEngine:add_params()`. as a guess, I checked molly's `init()` function and I'm pretty sure I've found what I'm looking for – `MollyThePoly.add_params()`. but just to be sure – I searched the script for a table called `MollyThePoly`, found that it was getting pulled in from the file `lib/molly_the_poly_engine.lua`, then searched in that file for a function called `add_params`. as I expected, looks like this function is creating a bunch of `control` params that call different engine commands, like `engine.pwMod` – so that checks out.

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

it _can_ be tricky to find these – it is common for them to be named `noteOn` & `noteOff` (this is the case for molly_the_poly), but they aren't always called that. you can try searching for those names as a starting point, but the more reliable way is to start by finding whatever piece of code interperets midi data, which should ultimately be converting that data to notes and sending those notes to the engine. a little shortcut to finding the relavent code might be searcing for the function `midi.to_msg` – this is a standard system function for reading midi data which may very well get you to the right section of code (if this isn't in the main file, try digging around in the `lib/` directory, perhaps there's another file dedicated to midi communication).

in molly_the_poly's case, I didn't find any engine commands in the same function where midi was being read, but I did find a function called `note_on`, that sounded about right, so I searched for that function to find the original definition, and inside _that_ function I found what I was looking for:
```
engine.noteOn(note_id, MusicUtil.note_num_to_freq(note_num), vel)
```
I can tell from the values being sent in that this function has three arguments: a note ID, the frequency in hz, and the note velocity level

lo & behold, the arguments that we have access to via the `eggs.noteOn` function match up to the first two: `note_id`, and `hz`:
```lua
function eggs.noteOn(note_id, hz)   
    engine.noteOn(note_id, hz, ???) -- hmm but what about the velocity argument
end
```
the only thing we're missing from eggs is velocity, because, if you haven't heard, monomes don't do velocity. so we'll just set this to a static value. in terms of what value to use ... well honestly this is where things can get a little bit vague, but checking back in that midi-related function, I saw a midi `vel` message getting divided by 127, so that probably means that the engine expects a number in the range 0-1 (this is also, you guessed it, pretty standard) so I'm going to go with 0.8 & we can just test it out & make sure we're not going to explode anyones ears (maybe a good time to test with the headphones off!).

```lua
function eggs.noteOn(note_id, hz)   
    engine.noteOn(note_id, hz, 0.8)
end
```
for the `eggs.noteOff` function, it's kind of just a rinse & repeat – usually these only need to accept a `note_id` value. here's what I got:
```lua
function eggs.noteOff(note_id)
    engine.noteOff(note_id)
end
```

and that's it! time to test/troubleshoot and just if soemthing doesn't work try to figure it out/ask around on the internet/ask chatGPT (ok maybe not that last one).

## STEP 5: submit a PR so everyone can use this engine!

if you're reading this, you're probably on the github page for eggs! this is also the easiest place to submit a PR. from the main repo page, click on the `lib/` folder and bring up the `engines.lua` file as before. if github hasn't changed drastically over there in the future, there should be a little "✏️" in the top right corner where you can edit the script, paste in your changes from maiden, and then click a green button or something to submit a PR, which I can then merge! when I have time to respond! which probably won't be super soon but eventually!!
