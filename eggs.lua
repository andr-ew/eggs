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

destination = include 'lib/destinations/destination'        --destination prototype
jf_dest = include 'lib/destinations/jf'                     --just friends output
midi_dest = include 'lib/destinations/midi'                 --midi output
crow_dests = include 'lib/destinations/crow'                --crow output

--setup pages

eggs.dests = {
    midi_dest:new(1),
    jf_dest,
    crow_dests[1],
    crow_dests[2]
}

eggs.keymaps = {
    [1] = keymap.poly.new{
        action_on = function(...) eggs.dests[1]:note_on(...) end,
        action_off = function(...) eggs.dests[1]:note_off(...) end,
        pattern = eggs.pattern_shims[1].manual,
        size = eggs.keymap_size,
    },
    [2] = keymap.poly.new{
        action_on = eggs.dests[2].note_on,
        action_off = eggs.dests[2].note_off,
        pattern = eggs.pattern_shims[2].manual,
        size = eggs.keymap_size,
    },
    [3] = keymap.mono.new{
        action = eggs.dests[3].set_note,
        pattern = eggs.pattern_shims[3].manual,
        size = eggs.keymap_size,
    },
    [4] = keymap.mono.new{
        action = eggs.dests[4].set_note,
        pattern = eggs.pattern_shims[4].manual,
        size = eggs.keymap_size,
    }    
}
    
eggs.arqs[1].action_on = function(...) eggs.dests[1]:note_on(...) end
eggs.arqs[1].action_off = function(...) eggs.dests[1]:note_off(...) end
eggs.arqs[2].action_on = eggs.dests[2].note_on
eggs.arqs[2].action_off = eggs.dests[2].note_off
eggs.arqs[3].action_on = function(idx) eggs.dests[3].set_note(idx, 1) end
eggs.arqs[3].action_off = function(idx) eggs.dests[3].set_note(idx, 0) end
eggs.arqs[4].action_on = function(idx) eggs.dests[4].set_note(idx, 1) end
eggs.arqs[4].action_off = function(idx) eggs.dests[4].set_note(idx, 0) end

--set up modulation sources

local add_actions = {}
for i = 1,2 do
    add_actions[i] = patcher.crow.add_source(i)
end

do
    local stream = patcher.add_source{ name = 'cv 1', id = 'cv_1' }
    crow_dests[1].cv_callback = stream
end
do
    local stream, change

    local function assignment_callback(mode)
        if mode == 'stream' then
            crow_dests[1].gate_callback = function(state)
                stream(state and 5 or 0)
            end
        elseif mode == 'change' then
            crow_dests[1].gate_callback = change
        end
    end

    stream, change = patcher.add_source{ 
        name = 'gate 1', id = 'gate_1',
        assignment_callback = assignment_callback,
    }
end

--set up crow

local function crow_add()
    for _,dest in ipairs(crow_dests) do
        dest.add()
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
    for i = 1,4 do
        nb:add_param('voice_'..i, 'voice '..i)
    end
    nb:add_player_params()

    params:add_separator('midi')
    for i,midi_dest in ipairs({ eggs.dests[1] }) do
        params:add_group('midi_dests_'..i, midi_dest.name, midi_dest.params_count)
        midi_dest:add_params()
    end

    params:add_separator('just friends')
    params:add_group('jf_dest', jf_dest.name, jf_dest.params_count)
    jf_dest.add_params()

    params:add_separator('crow outputs')
    for i,crow_dest in ipairs(crow_dests) do
        params:add_group('crow_dests_pair_'..i, crow_dest.name, crow_dest.params_count)
        
        crow_dest.add_params()
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
