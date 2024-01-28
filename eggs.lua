-- eggs
--
-- pitch gesture looper for norns + grid
--
-- version 0.2.0 @andrew
--
-- required: grid (128)
--
-- documentation:
-- github.com/andr-ew/eggs

--device globals

g = grid.connect()

--system libs

polysub = require 'engine/polysub'
engine.name = 'PolySub'
cs = require 'controlspec'

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

--script files

crow_outs = include 'lib/crow_outs'
midi_outs = include 'lib/midi_outs'

midi_outs.init({ 1, 2 })

eggs = include 'lib/globals'
include 'lib/params'
App = {}
App.grid = include 'lib/ui/grid'                    --grid UI
App.norns = include 'lib/ui/norns'                  --norns UI

--create, connect UI components

_app = {
    grid = App.grid(), 
    norns = App.norns()
}

crops.connect_enc(_app.norns)
crops.connect_key(_app.norns)
crops.connect_screen(_app.norns)

--init/cleanup

function init()
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
