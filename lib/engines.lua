-- this is the file where new engines can be defined

local engine_nicknames = {}
local engine_names = {}
local init_engine = {}

-- here's an example of how to define an engine
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

-- orgn
do
    local nickname = 'orgn'
    table.insert(engine_nicknames, nickname)
    
    local name = 'Orgn'
    table.insert(engine_names, name)

    init_engine[nickname] = function()
        local orgn = include 'orgn/lib/orgn'
        orgn.params()
        orgn.init()

        function eggs.noteOn(note_id, hz)   
            local vel = math.random()*0.2 + 0.85
            orgn.noteOn(note_id, hz, vel)
        end
        function eggs.noteOff(note_id)
            orgn.noteOff(note_id)
        end
    end
end

-- molly the poly
do
    local nickname = 'molly the poly'
    table.insert(engine_nicknames, nickname)

    local name = 'MollyThePoly'
    table.insert(engine_names, name)

    init_engine[nickname] = function()
        local MollyThePoly = include 'molly_the_poly/lib/molly_the_poly_engine'
        MollyThePoly.add_params()

        function eggs.noteOn(note_id, hz)   
            engine.noteOn(note_id, hz, 0.8)
        end
        function eggs.noteOff(note_id)
            engine.noteOff(note_id)
        end
    end
end

-- passersby
do
    local nickname = 'passersby'
    table.insert(engine_nicknames, nickname)

    local name = 'Passersby'
    table.insert(engine_names, name)

    init_engine[nickname] = function()
        local Passersby = include("passersby/lib/passersby_engine")
        Passersby.add_params()

        function eggs.noteOn(note_id, hz)   
            engine.noteOn(note_id, hz, 0.8)
        end
        function eggs.noteOff(note_id)
            engine.noteOff(note_id)
        end
    end
end

-- mi-engines
do
    local nicknames = { 'macro-b', 'macro-p', 'modal-e', 'resonate-r' }
    local names = { 'MacroB', 'MacroP', 'ModalE', 'ResonateR' }

    for i,name in ipairs(names) do
        local nickname = nicknames[i]

        table.insert(engine_nicknames, nickname)
        table.insert(engine_names, name)

        init_engine[nickname] = function()
            local path = 'mi-eng/lib/'..name..'_engine'
            local class = include(path)
            class.add_params()

            function eggs.noteOn(note_id, hz)   
                engine.noteOn(note_id, 0.8 * 127)
            end
            function eggs.noteOff(note_id)
                engine.noteOff(0)
            end
        end
    end
end

-- jhnn
do
    local nickname = 'jhnn'
    table.insert(engine_nicknames, nickname)

    local name = 'Jhnn'
    table.insert(engine_names, name)

    init_engine[nickname] = function()
        local jhnn = include 'jhnn/lib/jhnn_engine'
    
        jhnn.add_params()

        function eggs.noteOn(note_id, hz)   
            local dyn = 3 + math.random(0, 2)
        
            jhnn.noteOn(note_id, dyn/7)
        end
        function eggs.noteOff(note_id) end
    end
end

return {
    nicknames = engine_nicknames,
    names = engine_names,
    init = init_engine,
}

--don't put any code down here, it wont run ! put it before "return", but after polysub
