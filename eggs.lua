-- eggs
--
-- pitch gesture looper 
-- for norns + grid
--
-- version 0.4.1 @andrew
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
Patcher = include 'lib/patcher/ui/using_map_key'            --mod matrix patching UI utilities

nb = include 'lib/nb/lib/nb'                                --nb

--script files

eggs = include 'lib/globals'                                --global variables & objects

eggs.engines = include 'lib/engines'                        --DEFINE NEW ENGINES IN THIS FILE

Components = include 'lib/ui/components'                    --ui components

jf_out = include 'lib/jf_out'                               --just friends output
midi_outs = include 'lib/midi_outs'                         --midi output
crow_outs = include 'lib/crow_outs'                         --crow output

eggs.midi_out_count = 1
midi_outs.init(eggs.midi_out_count)

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

--set up modulation sources

local add_actions = {}
for i = 1,2 do
    add_actions[i] = patcher.crow.add_source(i)
end

do
    local stream = patcher.add_source{ name = 'cv 1', id = 'cv_1' }
    crow_outs[1].cv_callback = stream
end
do
    local stream, change

    local function assignment_callback(mode)
        if mode == 'stream' then
            crow_outs[1].gate_callback = function(state)
                stream(state and 5 or 0)
            end
        elseif mode == 'change' then
            crow_outs[1].gate_callback = change
        end
    end

    stream, change = patcher.add_source{ 
        name = 'gate 1', id = 'gate_1',
        assignment_callback = assignment_callback,
    }
end

--set up crow

local function crow_add()
    for _,out in ipairs(crow_outs) do
        out.add()
    end
    for _,action in ipairs(add_actions) do action() end
end
norns.crow.add = crow_add

--more script files

eggs.params = include 'lib/params'                          --script params
App = {}
App.grid = include 'lib/ui/grid'                            --grid UI
App.norns = include 'lib/ui/norns'                          --norns UI

--params stuff pre-init

params.action_read = eggs.params.action_read
params.action_write = eggs.params.action_write
params.action_delete = eggs.params.action_delete

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
crops.connect_screen(_app.norns, 60)
    
--init/cleanup

function init()
    nb:init()

    --params-stuff post-init

    eggs.params.add_engine_params()

    params:add_separator('nb')
    for i = 1,eggs.midi_out_count do
        nb:add_param('voice_'..i, 'voice '..i)
        nb:add_player_params()
    end

    params:add_separator('midi')
    for i,midi_out in ipairs(midi_outs) do
        params:add_group('midi_outs_'..i, midi_out.name, midi_out.params_count)
        midi_out.add_params()
    end

    params:add_separator('just friends')
    params:add_group('jf_out', jf_out.name, jf_out.params_count)
    jf_out.add_params()

    params:add_separator('crow outputs')
    for i,crow_out in ipairs(crow_outs) do
        params:add_group('crow_outs_pair_'..i, crow_out.name, crow_out.params_count)
        
        crow_out.add_params()
    end
    eggs.params.add_keymap_params()

    params:add_separator('patcher')
    params:add_group('assignments', #patcher.destinations)
    patcher.add_assignment_params(function() 
        crops.dirty.grid = true; crops.dirty.screen = true
    end)
    
    eggs.params.add_pset_params()

    params:read()
    
    crow_add()

    for i = 1,eggs.track_count do
        local arq = eggs.arqs[i]:start()
    end

    crops.connect_grid(_app.grid, g, 240)
end

function cleanup()
    if params:string('autosave pset') == 'yes' then params:write() end
end
