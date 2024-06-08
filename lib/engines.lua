-- this is the file where new engines can be defined

local engine_names = {}
local init_engine = {}
local engine_post_init = {}

-- here's an example of how to define an engine
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
        function eggs.noteOn(note_id, hz)   
            engine.start(note_id, hz)          -- call the note on function for the engine here
        end
        function eggs.noteOff(note_id)
            engine.stop(note_id)               -- call the note off function for the engine here
        end
    end
end

-- orgn
do
    local nickname = 'orgn'
    table.insert(engine_names, nickname)

    local orgn

    init_engine[nickname] = function()
        engine.name = 'Orgn'

        orgn = include 'orgn/lib/orgn'
        orgn.params()

        function eggs.noteOn(note_id, hz)   
            local vel = math.random()*0.2 + 0.85
            orgn.noteOn(note_id, hz, vel)
        end
        function eggs.noteOff(note_id)
            orgn.noteOff(note_id)
        end
    end
    
    engine_post_init[nickname] = function()
        orgn.init()
    end
end

-- molly the poly
do
    local nickname = 'molly the poly'
    table.insert(engine_names, nickname)

    init_engine[nickname] = function()
        engine.name = 'MollyThePoly'

        local MollyThePoly = include 'molly_the_poly/lib/molly_the_poly_engine'
        MollyThePoly.add_params(true)

        function eggs.noteOn(note_id, hz)   
            engine.noteOn(note_id, hz, 0.8)
        end
        function eggs.noteOff(note_id)
            engine.noteOff(note_id)
        end
    end
end

return {
    names = engine_names,
    init = init_engine,
    post_init = engine_post_init,
}

--don't put any code down here please !
