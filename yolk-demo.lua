pattern_time = include 'lib/pattern_time_extended/pattern_time_extended'
mute_group = include 'lib/pattern_time_extended/mute_group'

include 'lib/crops/core'
Grid = include 'lib/crops/components/grid'
Enc = include 'lib/crops/components/enc'
Key = include 'lib/crops/components/key'
Screen = include 'lib/crops/components/screen'
Produce = {}
Produce.grid = include 'lib/produce/grid'
Produce.screen = include 'lib/produce/screen'

keymap = include 'lib/keymap/keymap'
Keymap = include 'lib/keymap/ui'

tune = include 'lib/tune/tune'
local tunings, scale_groups = include 'lib/tune/scales'
Tune = include 'lib/tune/ui'

arqueggiator = include 'lib/arqueggiator/arqueggiator'
Arqueggiator = include 'lib/arqueggiator/ui'

polysub = require 'engine/polysub'
engine.name = 'PolySub'

g = grid.connect()

track_count = 2
track_focus = 1

tune_count = 8
tunes = {}

function get_tune(track)
    return tunes[params:get('tuning_preset_'..track)]
end

for i = 1,tune_count do
    tunes[i] = tune.new{ 
        tunings = tunings, id = i,
        scale_groups = scale_groups,
        add_param_separator = false,
        add_param_group = true,
        visibility_condition = function() 
            local visible = false

            for track = 1,track_count do
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
pattern_groups = {}
mute_groups = {}

for i = 1,track_count do
    pattern_groups[i] = { manual = {}, arq = {} }
    for k,_ in pairs(pattern_groups[i]) do
        for ii = 1,pat_count do
            pattern_groups[i][k][ii] = pattern_time.new()
        end
    end

    mute_groups[i] = {
        manual = mute_group.new(pattern_groups[i].manual),
        arq = mute_group.new(pattern_groups[i].arq),
    }
end

local keymap_size = 128-16-16
local keymap_wrap = 16

k1 = false

local function note_on_poly(track, idx)
    local column = (idx-1)%keymap_wrap + 1 + params:get('column_'..track)
    local row = (idx-1)//keymap_wrap + 1 + params:get('row_'..track)

    local hz = get_tune(track):hz(column, row, nil, params:get('oct_'..track)) * 55

    engine.start(idx, hz)
end
local function note_off_poly(track, idx) engine.stop(idx) end
    
local function note_mono(track, idx, gate)
    local column = (idx-1)%keymap_wrap + 1 + params:get('column_'..track)
    local row = (idx-1)//keymap_wrap + 1 + params:get('row_'..track)

    local hz = get_tune(track):hz(column, row, nil, params:get('oct_'..track)) * 55

    if gate > 0 then
        engine.start(0, hz)
    else
        engine.stop(0)
    end
end


local NORMAL, LATCH, ARQ = 1, 2, 3
local mode_names = { 'normal', 'latch', 'arq' }
    
for i = 1,track_count do
    params:add_separator('track '..i)

    params:add{
        type = 'option', id = 'mode_'..i, name = 'mode',
        options = mode_names,
        action = function(v) 
            for _,mute_group in pairs(mute_groups[i]) do
                mute_group:stop()
            end

            keymaps[i]:set_latch(v == LATCH)

            if v ~= LATCH then
                keymaps[i]:clear()
            end
            if v ~= ARQ then
                arqs[i].sequence = {}
            end
            
            crops.dirty.grid = true 
        end
    }
    params:add{
        type = 'number', id = 'oct_'..i, name = 'oct',
        min = -5, max = 5, default = 0,
        action = function() crops.dirty.grid = true end
    }
    params:add{
        type = 'number', id = 'column_'..i, name = 'column',
        min = -16, max = 16, default = 0,
        action = function() crops.dirty.grid = true end
    }
    params:add{
        type = 'number', id = 'row_'..i, name = 'row',
        min = -16, max = 16, default = 0,
        action = function() crops.dirty.grid = true end
    }
end

keymaps = {
    [1] = keymap.poly.new{
        action_on = function(idx) note_on_poly(1, idx) end,
        action_off = function(idx) note_off_poly(1, idx) end,
        pattern = mute_groups[1].manual,
        size = keymap_size,
    },
    [2] = keymap.mono.new{
        action = function(idx, gate) note_mono(2, idx, gate) end,
        pattern = mute_groups[2].manual,
        size = keymap_size,
    }    
}

local snapshot_count = 4
    
arqs = {}
snapshots = {}
for i = 1,track_count do
    local arq = arqueggiator.new(i)

    params:add_separator('arqueggiator '..i)
    arq:params()
    arq:start()

    params:set_action(arq:pfix('division'), function() crops.dirty.grid = true end)
    params:set_action(arq:pfix('reverse'), function() crops.dirty.grid = true end)

    arqs[i] = arq

    snapshots[i] = { manual = {}, arq = {} }
end
    
arqs[1].action_on = function(idx) note_on_poly(1, idx) end
arqs[1].action_off = function(idx) note_off_poly(1, idx) end
arqs[2].action_on = function(idx) note_mono(2, idx, 1) end
arqs[2].action_off = function(idx) note_mono(2, idx, 0) end

do
    params:add_separator('tuning')

    for i = 1,track_count do
        params:add{
            type = 'number', id = 'tuning_preset_'..i, name = 'track '..i..' preset',
            min = 1, max = presets, default = 1, 
            action = function() for _,t in ipairs(tunes) do
                t:update_tuning()
            end end,
        }
    end

    for i,t in ipairs(tunes) do
        t:add_params('preset '..i)
    end
end

params:add_separator('')
polysub:params()

POLY, MONO = 1, 2
track = POLY

--add pset params
do
    params:add_separator('pset')

    params:add{
        id = 'reset all params', type = 'binary', behavior = 'trigger',
        action = function()
            for _,p in ipairs(params.params) do if p.save then
                params:set(p.id, p.default or (p.controlspec and p.controlspec.default) or 0, true)
            end end
    
            params:bang()
        end
    }
    params:add{
        id = 'overwrite default pset', type = 'binary', behavior = 'trigger',
        action = function()
            params:write()
        end
    }
    params:add{
        id = 'autosave pset', type = 'option', options = { 'yes', 'no' },
        -- action = function()
        --     params:write()
        -- end
    }
end

local Arq = function(args)
    local _frets = Tune.grid.fretboard()
    local _keymap = Arqueggiator.grid.keymap()

    local arq = args.arq
    local mute_group = args.mute_group
    local pattern_group = args.pattern_group
    local snapshot_count = args.snapshot_count

    --TODO: mulipattern alongside div & reverse (?)
    local function process_arq(new)
        arq.sequence = new

        crops.dirty.grid = true;
    end
    mute_group.process = process_arq

    local function set_arq(new)
        process_arq(new)
        mute_group:watch(new)
    end

    local _patrecs = {}
    for i = 1, #pattern_group do
        _patrecs[i] = Produce.grid.pattern_recorder()
    end

    local _snapshots = {}
    for i = 1, snapshot_count do
        _snapshots[i] = Produce.grid.triggerhold()
    end
    
    local _reverse = Grid.toggle()
    local _rate_mark = Grid.fill()
    local _rate = Grid.integer()

    return function(props)
        local ss = props.snapshots

        for i,_patrec in ipairs(_patrecs) do
            _patrec{
                x = 4 + i - 1, y = 1,
                pattern = pattern_group[i],
            }
        end

        for i,_snapshot in ipairs(_snapshots) do
            local filled = (ss[i] and #ss[i] > 0)

            function snapshot()
                ss[i] = arq.sequence
            end
            function clear_snapshot()
                ss[i] = {}
                -- arq.sequence = {}
            end
            function recall()
                if #(ss[i] or {}) > 0 then 
                    set_arq(ss[i])
                end
            end
            _snapshot{
                x = 9 + i - 1, y = 1,
                levels = { filled and 4 or 0, filled and 15 or 8 },
                action_tap = filled and recall or snapshot,
                action_hold = clear_snapshot,
            }
        end
        
        if #arq.sequence > 0 then
            _reverse{
                x = 4, y = 2, levels = { 4, 15 },
                state = crops.of_param(arq:pfix('reverse'))
            }
            _rate_mark{
                x = 8, y = 2, level = 4,
            }
            _rate{
                x = 5, y = 2, size = 8,
                state = crops.of_param(arq:pfix('division'))
            }
        end

        _frets{
            x = 1, y = 8, size = keymap_size, wrap = keymap_wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 1 },
            tune = get_tune(props.track),
            toct = params:get('oct_'..props.track),
            column_offset = params:get('column_'..props.track),
            row_offset = params:get('row_'..props.track),
        }
        _keymap{
            x = 1, y = 8, size = keymap_size, wrap = keymap_wrap,
            flow = 'right', flow_wrap = 'up', levels = { 4, 8, 15 }, 
            step = arq.step, gate = arq.gate,
            state = crops.of_variable(arq.sequence, set_arq)
        }
    end
end

local function Rate_reverse()
    local _reverse = Grid.toggle()
    local _rate_mark = Grid.fill()
    local _rate = Grid.integer()
    local _loop = Grid.toggle()

    return function(props)
        local pattern = props.mute_group:get_playing_pattern()

        if pattern then
            _reverse{
                x = 4, y = 2, levels = { 4, 15 },
                state = {
                    pattern.reverse and 1 or 0,
                    function(v)
                        pattern:set_reverse(v == 1)

                        crops.dirty.grid = true
                    end
                }
            }
            _rate_mark{
                x = 8, y = 2, level = 4,
            }
            do
                local tf = pattern.time_factor
                _rate{
                    x = 5, y = 2, size = 7, min = -3,
                    state = {
                        (tf < 1) and ((1/tf) - 1) or ((-tf) + 1),
                        function(v)
                            pattern.time_factor = (v >= 0) and (1/(v + 1)) or (-(v - 1))

                            crops.dirty.grid = true
                        end
                    }
                }
            end
            _loop{
                x = 12, y = 2, levels = { 4, 15 },
                state = {
                    pattern.loop and 1 or 0,
                    function(v)
                        pattern:set_loop(v == 1)

                        crops.dirty.grid = true
                    end
                }
            }
        end
    end
end

function Grid_page(args)
    local track = args.track

    local _patrecs = {}
    for i = 1, #pattern_groups[track].manual do
        _patrecs[i] = Produce.grid.pattern_recorder()
    end
    
    local _snapshots = {}
    for i = 1, snapshot_count do
        _snapshots[i] = {}
        _snapshots[i].latch = Produce.grid.triggerhold()
        _snapshots[i].normal = Grid.momentary() 
    end
    local snapshots_normal_held = {}

    local _rate_rev = Rate_reverse()

    local _mode_arq = Grid.toggle()
    local _mode_latch = Grid.toggle()

    local _arq = Arq{
        arq = arqs[track],
        pattern_group = pattern_groups[track].arq,
        mute_group = mute_groups[track].arq,
        snapshot_count = snapshot_count,
    }

    local _frets = Tune.grid.fretboard()
    local _keymap = Keymap.grid[args.voicing]()

    return function()
        local mode = params:get('mode_'..track)

        _mode_arq{
            x = 3, y = 1, levels = { 4, 15 },
            state = crops.of_variable(
                mode==ARQ and 1 or 0,
                function(v)
                    params:set('mode_'..track, v==1 and ARQ or NORMAL)
                end
            )
        }
        _mode_latch{
            x = 8, y = 1, levels = { 4, 15 },
            state = crops.of_variable(
                mode==LATCH and 1 or 0,
                function(v)
                    params:set('mode_'..track, v==1 and LATCH or NORMAL)
                end
            )
        }

        if mode==ARQ then
            _arq{ track = track, snapshots = snapshots[track].arq }
        else
            local ss = snapshots[track].manual

            for i,_patrec in ipairs(_patrecs) do
                _patrec{
                    x = 4 + i - 1, y = 1,
                    pattern = pattern_groups[track].manual[i],
                }
            end
            _rate_rev{
                mute_group = mute_groups[track].manual,
            }

            for i,_snapshot in ipairs(_snapshots) do
                local filled = (ss[i] and next(ss[i]))

                function snapshot()
                    ss[i] = keymaps[track]:get()
                end
                function clear_snapshot()
                    ss[i] = {}
                    -- keymaps[track]:clear()
                end
                function recall()
                    keymaps[track]:set(ss[i] or {})
                end
                
                if mode==LATCH then
                    _snapshot.latch{
                        x = 9 + i - 1, y = 1,
                        levels = { filled and 4 or 0, filled and 15 or 8 },
                        action_tap = filled and recall or snapshot,
                        action_hold = clear_snapshot,
                    }
                else
                    _snapshot.normal{
                        x = 9 + i - 1, y = 1,
                        levels = { filled and 4 or 0, filled and 15 or 8 },
                        state = crops.of_variable(snapshots_normal_held[i], function(v)
                            snapshots_normal_held[i] = v

                            if v > 0 then
                                if filled then recall() 
                                elseif next(keymaps[track]:get()) then snapshot() end
                            else
                                keymaps[track]:set({})
                            end

                            crops.dirty.grid = true
                        end)
                    }
                end
            end

            _frets{
                x = 1, y = 8, size = keymap_size, wrap = keymap_wrap,
                flow = 'right', flow_wrap = 'up',
                levels = { 0, 4 },
                tune = get_tune(track),
                toct = params:get('oct_'..track),
                column_offset = params:get('column_'..track),
                row_offset = params:get('row_'..track),
            }
            _keymap{
                x = 1, y = 8, size = keymap_size, wrap = keymap_wrap,
                flow = 'right', flow_wrap = 'up',
                levels = { 0, 15 },
                state = keymaps[track]:get_state(),
                mode = mode_names[mode]
            }
        end
    end
end

function Grid_tuning()
    local _tonic = Tune.grid.tonic()
    
    local _degs_bg = Tune.grid.scale_degrees_background()
    local _degs = {}
    for i = 1, 12 do 
        _degs[i] = Tune.grid.scale_degree()
    end

    return function(props)
        local track = props.track

        _tonic{
            left = 1, top = 7, levels = { 4, 15 },
            state = Tune.of_param(get_tune(track), 'tonic'), tune = get_tune(track),
        }
        _degs_bg{
            left = 1, top = 4, level = 4
        }
        for i,_deg in ipairs(_degs) do
            _deg{
                left = 1, top = 4, levels = { 8, 15 },
                tune = get_tune(track),
                degree = i, state = Tune.of_param(get_tune(track), 'enable_'..i),
            }
        end
    end
end

local App = {}

function App.grid()
    local _track = Grid.integer()
    
    local _column = Produce.grid.integer_trigger()
    local _row = Produce.grid.integer_trigger()

    local _pages = {
        [1] = Grid_page{ track = 1, voicing = 'poly' },
        [2] = Grid_page{ track = 2, voicing = 'mono' },
    }

    local _tuning = Grid_tuning()
    
    return function()
        if not k1 then
            _track{
                x = 1, y = 1, size = #_pages, levels = { 0, 15 },
                state = { 
                    track_focus, 
                    function(v) 
                        track_focus = v

                        crops.dirty.grid = true 
                    end
                }
            }
        
            _column{
                x_next = 14, y_next = 1,
                x_prev = 13, y_prev = 1,
                levels = { 4, 15 }, wrap = false,
                min = params:lookup_param('column_'..track_focus).min,
                max = params:lookup_param('column_'..track_focus).max,
                state = crops.of_param('column_'..track_focus)
            }
            _row{
                x_next = 16, y_next = 1,
                x_prev = 16, y_prev = 2,
                levels = { 4, 15 }, wrap = false,
                min = params:lookup_param('row_'..track_focus).min,
                max = params:lookup_param('row_'..track_focus).max,
                state = crops.of_param('row_'..track_focus)
            }

            _pages[track_focus]()
        else
            _tuning{ track = track_focus }
        end
    end
end
    
local x, y
do
    local top, bottom = 8, 64-2
    local left, right = 2, 128-2
    local mul = { x = (right - left) / 2, y = (bottom - top) / 2 }
    x = { left, left + mul.x*5/4, [1.5] = 24  }
    y = { top, bottom - 22, bottom, [1.5] = 20, }
end

function Tuning_norns()
    local _degs = Tune.screen.scale_degrees()    
    
    local _scale = { enc = Enc.integer(), screen = Screen.list() }
    local _tuning = { enc = Enc.integer(), screen = Screen.list() }
    local _rows = { enc = Enc.integer(), screen = Screen.list() }
    local _frets = { key = Key.integer(), screen = Screen.list() }

    local fret_id = get_tune(track):get_param_id('fret_marks')
    local fret_opts = params:lookup_param(fret_id).options
    local frets_text = { 'frets' }
    for _,v in ipairs(fret_opts) do table.insert(frets_text, v) end

    return function(props)
        local track = props.track

        _degs{
            x = x[1], y = y[1.5], tune = get_tune(track),
        }
        do
            local id = get_tune(track):get_scale_param_id()
            _scale.enc{
                n = 1, max = #params:lookup_param(id).options,
                state = crops.of_param(id)
            }
            _scale.screen{
                x = x[1], y = y[1],
                text = { scale = params:string(id) }
            }
        end
        do
            local id = get_tune(track):get_param_id('tuning')
            _tuning.enc{
                n = 2, max = #params:lookup_param(id).options,
                state = crops.of_param(id)
            }
            _tuning.screen{
                x = x[1], y = y[2], flow = 'down',
                text = { tuning = params:string(id) }
            }
        end
        do
            local id = get_tune(track):get_param_id('row_tuning')
            _rows.enc{
                n = 3, max = params:lookup_param(id).max,
                state = crops.of_param(id)
            }
            _rows.screen{
                x = x[2], y = y[2], flow = 'down',
                text = { rows = params:string(id) }
            }
        end
        do
            _frets.key{
                n_prev = 2, n_next = 3, max = #fret_opts,
                state = crops.of_param(fret_id)
            }
            _frets.screen{
                x = x[1], y = y[3],
                text = frets_text, focus = params:get(fret_id) + 1,
            }
        end
    end
end

function App.norns()
    local _text = Screen.text()
    local _tuning = Tuning_norns()

    local _k1 = Key.momentary()

    return function()
        _k1{
            n = 1,
            state = {
                k1 and 1 or 0,
                function(v) 
                    k1 = (v==1) 

                    crops.dirty.grid = true
                    crops.dirty.screen = true
                end
            }
        }

        if not k1 then 
            _text{ x = x[1], y = y[1], text = 'yolk-demo' }
        else
            _tuning{ track = track_focus }
        end
    end
end

_app = {
    grid = App.grid(), 
    norns = App.norns()
}

local function action_read(file, name, slot)
    print('pset action read', file, name, slot)

    local name = 'pset-'..string.format("%02d", slot)
    local fname = norns.state.data..name..'.data'
    local data, err = tab.load(fname)

    if err then print('ERROR pset action read: '..err) end
    if data then
        snapshots = data.snapshots or {}
        
        for i = 1,track_count do
            arqs[i].sequence = data.sequences[i] or {}

            for k,_ in pairs(data.pattern_groups[i]) do
                for ii,_ in ipairs(data.pattern_groups[i][k]) do
                    pattern_groups[i][k][ii]:import(data.pattern_groups[i][k][ii], true)
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
        snapshots = snapshots,
        pattern_groups = {},
    }

    for i = 1,track_count do
        data.sequences[i] = arqs[i].sequence

        data.pattern_groups[i] = {}
        for k,_ in pairs(pattern_groups[i]) do
            data.pattern_groups[i][k] = {}
            for ii, pattern in ipairs(pattern_groups[i][k]) do
                print('export pattern', i, k, ii)
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

crops.connect_enc(_app.norns)
crops.connect_key(_app.norns)
crops.connect_screen(_app.norns)

function init()
    params:read()
    params:set('hzlag', 0)
    params:bang()

    crops.connect_grid(_app.grid, g, 240)
end

function cleanup()
    if params:string('autosave pset') == 'yes' then params:write() end
end
