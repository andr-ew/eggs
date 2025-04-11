-- eggs
--
-- pitch gesture looper 
-- for norns + grid
--
-- version 1.0.1 @andrew
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
musicutil = require 'musicutil'

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
channels = include 'lib/channels'                           --tuning class

arqueggiator = include 'lib/arqueggiator/arqueggiator'      --arqueggiation (arquencing) lib
Arqueggiator = include 'lib/arqueggiator/ui'

patcher = include 'lib/patcher/patcher'                     --modulation maxtrix
Patcher = include 'lib/patcher/ui/using_map_key'            --mod matrix patching UI utilities

nb = include 'lib/nb/lib/nb'                                --nb

--script files

eggs = include 'lib/globals'                                --global variables & objects

eggs.engines = include 'lib/engines'                        --DEFINE NEW ENGINES IN THIS FILE
eggs.setup = include 'lib/setup'                            --setup functions
eggs.params = include 'lib/params'                          --script params

destination = include 'lib/destinations/destination'        --destination prototype
jf_dest = include 'lib/destinations/jf'                     --just friends output
midi_dest = include 'lib/destinations/midi'                 --midi output
engine_dest = include 'lib/destinations/engine'             --engine output
nb_dest = include 'lib/destinations/nb'                     --nb output
crow_dests = include 'lib/destinations/crow'                --crow output

Components = include 'lib/ui/components'                    --ui components
App = {}
App.grid = include 'lib/ui/grid'                            --grid UI
App.norns = include 'lib/ui/norns'                          --norns UI

script_focus = 'eggs'

--setup

eggs.setup.destinations()
local add_actions = eggs.setup.modulation_sources()
local crow_add = eggs.setup.crow(add_actions)

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

    eggs.params.add_all_track_params()

    params:add_separator('patcher')
    params:add_group('assignments', #patcher.destinations)
    patcher.add_assignment_params(function() 
        crops.dirty.grid = true; crops.dirty.screen = true
    end)
    
    eggs.params.add_pset_params()

    params:read()
    params:bang()
    
    crow_add()

    eggs.setup.init()

    crops.connect_grid(_app.grid, g, 240)
end

function cleanup()
    if params:string('autosave pset') == 'yes' then params:write() end
end
