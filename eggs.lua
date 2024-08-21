-- eggs
--
-- pitch gesture looper 
-- for norns + grid
--
-- version 1.0.0 @andrew
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
pattern_param_factory = include 'lib/pattern_time_extended/params'       --pattern_time params

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
engine_dest = include 'lib/destinations/engine'             --engine output
nb_dest = include 'lib/destinations/nb'                     --nb output
crow_dests = include 'lib/destinations/crow'                --crow output

--setup destinations

eggs.midi_dests = {}
eggs.engine_dests = {}
eggs.nb_dests = {}

for i = 1,eggs.track_count do
    eggs.midi_dests[i] = midi_dest:new(i)
    eggs.engine_dests[i] = engine_dest:new(i)
    eggs.nb_dests[i] = nb_dest:new(i)
end
eggs.crow_dests = crow_dests
eggs.jf_dest = jf_dest

eggs.dests = {
    { eggs.engine_dests[1], eggs.midi_dests[1], eggs.nb_dests[1] },
    { jf_dest, eggs.engine_dests[2], eggs.midi_dests[2], eggs.nb_dests[2] },
    { crow_dests[1], eggs.engine_dests[3], eggs.midi_dests[3], eggs.nb_dests[3] },
    { crow_dests[2], eggs.engine_dests[4], eggs.midi_dests[4], eggs.nb_dests[4] },
}
eggs.dest_names = {
    { 'engine', 'midi', 'nb' },
    { 'jf', 'engine', 'midi', 'nb' },
    { 'crow 1+2', 'engine', 'midi', 'nb' },
    { 'crow 3+4', 'engine', 'midi', 'nb' },
}

for i = 1,eggs.track_count do
    eggs.set_dest(i, 1)
end

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

params:add_separator('destination')
eggs.params.add_destination_params()

params:add_separator('sep_engine', 'engine')
eggs.params.add_engine_selection_param()

params:read(nil, true) --read a first time before init to check the engine
params:lookup_param('engine_eggs'):bang()

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
    eggs.params.add_nb_params()

    params:add_separator('midi')
    for i,midi_dest in ipairs(eggs.midi_dests) do
        params:add_group('midi_dests_'..i, 'track '..i..' options', midi_dest.params_count)
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
    -- eggs.params.add_pattern_params()

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
