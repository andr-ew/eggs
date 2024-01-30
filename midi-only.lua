-- eggs
--
-- pitch gesture looper 
-- for norns + grid
--
-- version 0.3.0 @andrew
--
-- required: grid (any size)
--
-- documentation:
-- github.com/andr-ew/eggs

--device globals

g = grid.connect()

local wide = g and g.device and g.device.cols >= 16 or false

--system libs

polysub = require 'engine/polysub'
engine.name = 'PolySub'
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

midi_outs.init(4)

--setup pages

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

include 'lib/params'                                        --add params
App = {}
App.grid = include 'lib/ui/grid'                            --grid UI
App.norns = include 'lib/ui/norns'                          --norns UI

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
    params:set('hzlag', 0)
    params:bang()
    
    for i = 1,eggs.track_count do
        local arq = eggs.arqs[i]:start()
    end

    crops.connect_grid(_app.grid, g, 240)
end

function cleanup()
    if params:string('autosave pset') == 'yes' then params:write() end
end
