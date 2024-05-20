-- eggs
--
-- pitch gesture looper 
-- for norns + grid
--
-- version 0.3.1 @andrew
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

jf_out = include 'lib/jf_out'                               --just friends output
midi_outs = include 'lib/midi_outs'                         --midi output
crow_outs = include 'lib/crow_outs'                         --crow output

midi_outs.init(4)

--set up pages

eggs.outs = {}
eggs.keymaps = {}

for i = 1,4 do
    eggs.outs[i] = midi_outs[i]

    eggs.keymaps[i] = keymap.poly.new{
        action_on = midi_outs[i].note_on,
        action_off = midi_outs[i].note_off,
        pattern = eggs.pattern_shims[i].manual,
        size = eggs.keymap_size,
    }

    eggs.arqs[i].action_on = midi_outs[i].note_on
    eggs.arqs[i].action_off = midi_outs[i].note_off
end

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
