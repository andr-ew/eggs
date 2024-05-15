-- eggs
--
-- pitch gesture looper 
-- for norns + grid
--
-- version 0.3.0 @andrew
--
-- required: grid (any size)
--           crow
--
-- documentation:
-- github.com/andr-ew/eggs

--device globals

g = grid.connect()

local wide = g and g.device and g.device.cols >= 16 or false

--system libs

cs = require 'controlspec'
-- lfos = require 'lfo'

--git submodule libs

pattern_time = include 'lib/pattern_time_extended/pattern_time_extended' --pattern_time fork
mute_group = include 'lib/pattern_time_extended/mute_group'              --pattern_time mute groups

include 'lib/crops/core'                                    --crops, a UI component framework
Grid = include 'lib/crops/components/grid'
Enc = include 'lib/crops/components/enc'
Key = include 'lib/crops/components/key'
Screen = include 'lib/crops/components/screen'
Produce = {}                                                --additional components for crops
Produce.grid = include 'lib/produce/grid'
Produce.screen = include 'lib/produce/screen'

keymap = include 'lib/keymap/keymap'                        --patterning grid keyboard
Keymap = include 'lib/keymap/ui'

tune = include 'lib/tune/tune'                              --diatonic tuning lib
tunings, scale_groups = include 'lib/tune/scales'
Tune = include 'lib/tune/ui'

arqueggiator = include 'lib/arqueggiator/arqueggiator'      --arqueggiation (arquencing) lib
Arqueggiator = include 'lib/arqueggiator/ui'

patcher = include 'lib/patcher/patcher'                     --modulation maxtrix

--script files

eggs = include 'lib/globals'                                --global variables & objects

Components = include 'lib/ui/components'                    --ui components
mod_sources = include 'lib/modulation_sources'              --add modulation sources (crow ins)

jf_out = include 'lib/jf_out'                               --just friends output
midi_outs = include 'lib/midi_outs'                         --midi output
crow_outs = include 'lib/crow_outs'                         --crow output

midi_outs.init(1)

--setup pages

eggs.outs = {
    midi_outs[1],
    jf_out,
    crow_outs[1],
    crow_outs[2]
}

eggs.keymaps = {
    [1] = keymap.poly.new{
        action_on = midi_outs[1].note_on,
        action_off = midi_outs[1].note_off,
        pattern = eggs.pattern_shims[1].manual,
        size = eggs.keymap_size,
    },
    [2] = keymap.poly.new{
        action_on = jf_out.note_on,
        action_off = jf_out.note_off,
        pattern = eggs.pattern_shims[2].manual,
        size = eggs.keymap_size,
    },
    [3] = keymap.mono.new{
        action = crow_outs[1].set_note,
        pattern = eggs.pattern_shims[3].manual,
        size = eggs.keymap_size,
    },
    [4] = keymap.mono.new{
        action = crow_outs[2].set_note,
        pattern = eggs.pattern_shims[4].manual,
        size = eggs.keymap_size,
    }    
}
    
eggs.arqs[1].action_on = midi_outs[1].note_on
eggs.arqs[1].action_off = midi_outs[1].note_off
eggs.arqs[2].action_on = jf_out.note_on
eggs.arqs[2].action_off = jf_out.note_off
eggs.arqs[3].action_on = function(idx) crow_outs[1].set_note(idx, 1) end
eggs.arqs[3].action_off = function(idx) crow_outs[1].set_note(idx, 0) end
eggs.arqs[4].action_on = function(idx) crow_outs[2].set_note(idx, 1) end
eggs.arqs[4].action_off = function(idx) crow_outs[2].set_note(idx, 0) end

--setup modulation

local function crow_add()
    for _,out in ipairs(crow_outs) do
        out.add()
    end

    mod_sources.crow.add()
end
norns.crow.add = crow_add

--more script files

eggs.params = include 'lib/params'                          --script params
App = {}
App.grid = include 'lib/ui/grid'                            --grid UI
App.norns = include 'lib/ui/norns'                          --norns UI

--add params

eggs.params.add_destination_params()
eggs.params.add_keymap_params()
eggs.params.add_modulation_params()

params:add_separator('engine')
----------------------------------------- EDIT ENGINE HERE ----------------------------------------

engine.name = 'PolySub'               -- STEP 1: set engine.name to the proper name of your engine
                                      --         (must be installed on your norns)

polysub = require 'engine/polysub'    -- STEP 2: include or require any files needed for params/etc
polysub:params()                      -- STEP 3: call the function to add the params

function eggs.noteOn(note_number, hz)   
    engine.start(note_number, hz)     -- STEP 4: call the note on function here
end
function eggs.noteOff(note_number)
    engine.stop(note_number)          -- STEP 5: call the note off function here
end
---------------------------------------------------------------------------------------------------

eggs.params.add_pset_params()

params.action_read = eggs.params.action_read
params.action_write = eggs.params.action_write
params.action_delete = eggs.params.action_delete

--create, connect UI components

_app = {
    grid = App.grid({ wide = wide }), 
    norns = App.norns()
}

crops.connect_enc(_app.norns)
crops.connect_key(_app.norns)
crops.connect_screen(_app.norns)

--init/cleanup

function init()
    -- mod_sources.lfos.reset_params()
    -- for i = 1,2 do mod_sources.lfos[i]:start() end

    params:read()
    -- params:set('hzlag', 0)
    params:bang()
    
    crow_add()

    for i = 1,eggs.track_count do
        local arq = eggs.arqs[i]:start()
    end

    crops.connect_grid(_app.grid, g, 240)
end

function cleanup()
    if params:string('autosave pset') == 'yes' then params:write() end
end
