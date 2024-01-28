local eggs = {}

eggs.track_count = 4

eggs.track_focus = 1

eggs.NORMAL, eggs.SCALE, eggs.KEY = 1, 2, 3
eggs.view_focus = eggs.NORMAL

local tune_count = 8
eggs.tunes = {}

function eggs.get_tune(track)
    return eggs.tunes[params:get('tuning_preset_'..track)]
end

for i = 1,tune_count do
    eggs.tunes[i] = tune.new{ 
        tunings = tunings, id = i,
        scale_groups = scale_groups,
        add_param_separator = false,
        add_param_group = true,
        visibility_condition = function() 
            local visible = false

            for track = 1,eggs.track_count do
                if params:get('tuning_preset_'..track) == i then
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

-- local function note_mono(track, idx, gate)
--     local target = params:get('target_'..track)

--     local column = (idx-1)%eggs.keymap_wrap + 1 + params:get('column_'..track)
--     local row = (idx-1)//eggs.keymap_wrap + 1 + params:get('row_'..track)
--     local oct = params:get('oct_'..track)

--     if target == ENGINE then
--         local hz = eggs.get_tune(track):hz(column, row, nil, oct) * 55

--         if gate > 0 then
--             engine.start(0, hz)
--         else
--             engine.stop(0)
--         end
--     else
--         local note = eggs.get_tune(track):midi(column, row, nil, oct) + 33

--         if gate > 0 then
--             eggs.midi_devices[target]:note_on(note)
--         else
--             eggs.midi_devices[target]:note_off(note)
--         end
--     end
-- end


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
        action_on = midi_outs[2].note_on,
        action_off = midi_outs[2].note_off,
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
eggs.arqs[2].action_on = midi_outs[2].note_on
eggs.arqs[2].action_off = midi_outs[2].note_off
eggs.arqs[3].action_on = function(idx) crow_outs[1].set_note(idx, 1) end
eggs.arqs[3].action_off = function(idx) crow_outs[1].set_note(idx, 0) end
eggs.arqs[4].action_on = function(idx) crow_outs[2].set_note(idx, 1) end
eggs.arqs[4].action_off = function(idx) crow_outs[2].set_note(idx, 0) end

local function action_read(file, name, slot)
    print('pset action read', file, name, slot)

    local name = 'pset-'..string.format("%02d", slot)
    local fname = norns.state.data..name..'.data'
    local data, err = tab.load(fname)

    if err then print('ERROR pset action read: '..err) end
    if data then
        eggs.snapshots = data.snapshots or {}
        
        for i = 1,eggs.track_count do
            eggs.arqs[i].sequence = data.sequences[i] or {}

            for k,_ in pairs(data.pattern_groups[i]) do
                for ii,_ in ipairs(data.pattern_groups[i][k]) do
                    eggs.pattern_groups[i][k][ii]:import(data.pattern_groups[i][k][ii], true)
                end
            end
        end
    else
        print('pset action read: no data file found at '..fname)
    end

    params:bang()
end
local function action_write(file, name, slot)
    print('pset action write', file, name, slot)

    local name = 'pset-'..string.format("%02d", slot)
    local fname = norns.state.data..name..'.data'

    local data = {
        sequences = {},
        snapshots = eggs.snapshots,
        pattern_groups = {},
    }

    for i = 1,eggs.track_count do
        data.sequences[i] = eggs.arqs[i].sequence

        data.pattern_groups[i] = {}
        for k,_ in pairs(eggs.pattern_groups[i]) do
            data.pattern_groups[i][k] = {}
            for ii, pattern in ipairs(eggs.pattern_groups[i][k]) do
                data.pattern_groups[i][k][ii] = pattern:export()
            end
        end
    end

    local err = tab.save(data, fname)

    if err then print('ERROR pset action write: '..err) end
end
local function action_delete(file, name, slot)
    print('pset action delete', file, name, slot)

    --TODO: delete files
end

params.action_read = action_read
params.action_write = action_write
params.action_delete = action_delete

return eggs
