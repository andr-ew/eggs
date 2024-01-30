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

local function crow_add()
    for _,out in ipairs(crow_outs) do
        out.add()
    end

    mod_sources.crow.add()
end
norns.crow.add = crow_add

--more script files

include 'lib/params'                                        --add params
App = {}
App.grid = include 'lib/ui/grid'                            --grid UI
App.norns = include 'lib/ui/norns'                          --norns UI

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
    -- mod_sources.lfos.reset_params()
    -- for i = 1,2 do mod_sources.lfos[i]:start() end

    params:read()
    params:set('hzlag', 0)
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
