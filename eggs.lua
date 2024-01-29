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

--global variables

eggs = {}
do
    local mar = { left = 2, top = 7, right = 2, bottom = 2 }
    local top, bottom = mar.top, 64-mar.bottom
    local left, right = mar.left, 128-mar.right
    local w = 128 - mar.left - mar.right
    local h = 64 - mar.top - mar.bottom
    local mul = { x = (right - left) / 2, y = (bottom - top) / 2 }
    local x = { left, left + mul.x*5/4, [1.5] = 24  }
    local y = { top, bottom - 22, bottom, [1.5] = 20, }
    eggs.x, eggs.y, eggs.w, eggs.h = x, y, w, h

    eggs.e = {
        { x = x[1], y = y[1] },
        { x = x[1], y = mar.top + h*(5.5/8) },
        { x = x[2], y = mar.top + h*(5.5/8) },
    }
    eggs.k = {
        {},
        { x = x[1], y = mar.top + h*(7/8) },
        { x = x[2], y = mar.top + h*(7/8) },
    }
end

--script files

Components = include 'lib/ui/components'

jf_out = include 'lib/jf_out'
midi_outs = include 'lib/midi_outs'
crow_outs = include 'lib/crow_outs'

midi_outs.init(1)

--more global variables

eggs.track_count = 4
eggs.track_focus = 1

eggs.mapping = false

eggs.outs = {
    midi_outs[1],
    jf_out,
    crow_outs[1],
    crow_outs[2]
}

eggs.NORMAL, eggs.SCALE, eggs.KEY = 1, 2, 3
eggs.view_focus = eggs.NORMAL

local tune_count = 8
eggs.tunes = {}

for i = 1,tune_count do
    eggs.tunes[i] = tune.new{ 
        tunings = tunings, id = i,
        scale_groups = scale_groups,
        add_param_separator = false,
        add_param_group = true,
        visibility_condition = function() 
            local visible = false

            for track = 1,eggs.track_count do
                if params:get(eggs.outs[track].param_ids.tuning_preset) == i then
                    visible = true
                    break
                end
            end

            return visible
        end,
        action = function() 
            crops.dirty.grid = true 
            crops.dirty.screen = true
        end
    }
end

local pat_count = 4
eggs.pattern_groups = {}
eggs.mute_groups = {}

for i = 1,eggs.track_count do
    eggs.pattern_groups[i] = { manual = {}, arq = {} }
    for k,_ in pairs(eggs.pattern_groups[i]) do
        for ii = 1,pat_count do
            eggs.pattern_groups[i][k][ii] = pattern_time.new()
        end
    end

    eggs.mute_groups[i] = {
        manual = mute_group.new(eggs.pattern_groups[i].manual),
        arq = mute_group.new(eggs.pattern_groups[i].arq),
    }
end

eggs.keymap_size = 128-16-16
eggs.keymap_wrap = 16

eggs.NORMAL, eggs.LATCH, eggs.ARQ = 1, 2, 3
eggs.mode_names = { 'normal', 'latch', 'arq' }
    
eggs.keymaps = {
    [1] = keymap.poly.new{
        action_on = midi_outs[1].note_on,
        action_off = midi_outs[1].note_off,
        pattern = eggs.mute_groups[1].manual,
        size = eggs.keymap_size,
    },
    [2] = keymap.poly.new{
        action_on = jf_out.note_on,
        action_off = jf_out.note_off,
        pattern = eggs.mute_groups[2].manual,
        size = eggs.keymap_size,
    },
    [3] = keymap.mono.new{
        action = crow_outs[1].set_note,
        pattern = eggs.mute_groups[3].manual,
        size = eggs.keymap_size,
    },
    [4] = keymap.mono.new{
        action = crow_outs[2].set_note,
        pattern = eggs.mute_groups[4].manual,
        size = eggs.keymap_size,
    }    
}

eggs.snapshot_count = 4
    
eggs.arqs = {}
eggs.snapshots = {}
for i = 1,eggs.track_count do
    local arq = arqueggiator.new(i)

    eggs.arqs[i] = arq

    eggs.snapshots[i] = { manual = {}, arq = {} }
end
    
eggs.arqs[1].action_on = midi_outs[1].note_on
eggs.arqs[1].action_off = midi_outs[1].note_off
eggs.arqs[2].action_on = jf_out.note_on
eggs.arqs[2].action_off = jf_out.note_off
eggs.arqs[3].action_on = function(idx) crow_outs[1].set_note(idx, 1) end
eggs.arqs[3].action_off = function(idx) crow_outs[1].set_note(idx, 0) end
eggs.arqs[4].action_on = function(idx) crow_outs[2].set_note(idx, 1) end
eggs.arqs[4].action_off = function(idx) crow_outs[2].set_note(idx, 0) end

norns.crow.add = function()
    for _,out in ipairs(crow_outs) do
        out.add()
    end
end

--more script files

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
