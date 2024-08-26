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
            print('path:', path)
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

    local name = 'Johann'
    table.insert(engine_names, name)

    init_engine[nickname] = function()
        params:add{
            id = 'level', type = 'control',
            controlspec = cs.def{ min = 0, max = 15, default = 4 },
            action = function(v) engine.level(v) end,
        }
        params:add{
            id = 'rate', type = 'control',
            controlspec = cs.def{ 
                min = -2, max = 2, default = -0.12, quantum = 1/100/4,
            },
            action = function(v) engine.rate(2^v) end,
        }
        local notes = { 'C','C#','D','D#','E','F','F#','G','G#','A','A#','B', }
        params:add{
            id = 'grid root', type = 'option',
            options = notes,
        }
    
        local painissimo_mezzo = 1
        local forte = 0

        function eggs.noteOn(note_id, hz)   
            local dyn = forte > 0 and 5 or (
                (painissimo_mezzo * 2) - 1
            ) + math.random(0, 2)

            engine.noteOn(note_id, util.clamp(1, 7, dyn), 1, 0)
            -- engine.noteOn(note, util.clamp(1, 7, dyn), 1, 0)
        end
        function eggs.noteOff(note_id) end
    
        engine.loadfolder(_path.audio .. 'johann/classic')
    end
end

return {
    nicknames = engine_nicknames,
    names = engine_names,
    init = init_engine,
}

--don't put any code down here, it wont run ! put it before "return", but after polysub
