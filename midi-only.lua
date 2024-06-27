-- eggs (midi only)
--
-- pitch gesture looper 
-- for norns + grid
--
-- version 0.4.1 @andrew
--
-- required: grid (any size)
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
Patcher = include 'lib/patcher/ui/using_map_key'            --mod matrix patching UI utilities

nb = include 'lib/nb/lib/nb'                                --nb

--script files

eggs = include 'lib/globals'                                --global variables & objects

eggs.engines = include 'lib/engines'                        --DEFINE NEW ENGINES IN THIS FILE

Components = include 'lib/ui/components'                    --ui components

midi_outs = include 'lib/midi_outs'                         --midi output

eggs.midi_out_count = 4
midi_outs.init(eggs.midi_out_count)

--set up pages

eggs.track_dest = {}
eggs.keymaps = {}

for i = 1,4 do
    eggs.track_dest[i] = midi_outs[i]

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

--params stuff pre-init

params:add_separator('sep_engine', 'engine')
eggs.params.add_engine_selection_param()

params:read(nil, true) --read a first time before init to check the engine
params:lookup_param('engine'):bang()

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
    nb:init()

    --params-stuff post-init

    eggs.params.add_engine_params()

    params:add_separator('nb')
    for i = 1,eggs.midi_out_count do
        nb:add_param('voice_'..i, 'voice '..i)
    end
    nb:add_player_params()

    params:add_separator('midi')
    for i,midi_out in ipairs(midi_outs) do
        params:add_group('midi_outs_'..i, midi_out.name, midi_out.params_count)
        midi_out.add_params()
    end

    eggs.params.add_keymap_params()

    params:add_separator('patcher')
    params:add_group('assignments', #patcher.destinations)
    patcher.add_assignment_params(function() 
        crops.dirty.grid = true; crops.dirty.screen = true
    end)
    
    eggs.params.add_pset_params()

    params:read()
    
    for i = 1,eggs.track_count do
        local arq = eggs.arqs[i]:start()
    end

    crops.connect_grid(_app.grid, g, 240)
end

function cleanup()
    if params:string('autosave pset') == 'yes' then params:write() end
end
