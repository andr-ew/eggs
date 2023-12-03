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

tune.setup{ 
    tunings = tunings, scale_groups = scale_groups, presets = 8,
    action = function() 
        crops.dirty.grid = true 
        crops.dirty.screen = true
    end
}

polysub = require 'engine/polysub'
engine.name = 'PolySub'

g = grid.connect()

local pat_count = { manual = 9, arq = 3 }
track_count = 2

pattern_groups = {}
mute_groups = {}

for i = 1,track_count do
    pattern_groups[i] = { manual = {}, arq = {} }
    for k,_ in pairs(pat_count) do
        for ii = 1,pat_count[k] do
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

    local hz = tune.hz(column, row, nil, params:get('oct_'..track)) * 55

    engine.start(idx, hz)
end
local function note_off_poly(track, idx) engine.stop(idx) end
    
local function note_mono(track, idx, gate)
    local column = (idx-1)%keymap_wrap + 1 + params:get('column_'..track)
    local row = (idx-1)//keymap_wrap + 1 + params:get('row_'..track)

    local hz = tune.hz(column, row, nil, params:get('oct_'..track)) * 55

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

            if v ~= ARQ then
                arqs[i].sequence = {}
            else
                keymaps[i]:clear()
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

local snapshot_count = 5
    
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

    snapshots[i] = {}
end
    
arqs[1].action_on = function(idx) note_on_poly(1, idx) end
arqs[1].action_off = function(idx) note_off_poly(1, idx) end
arqs[2].action_on = function(idx) note_mono(2, idx, 1) end
arqs[2].action_off = function(idx) note_mono(2, idx, 0) end


tune.params()
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
    local snapshots = args.snapshots
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

    -- clear_arqs = function()
    --     set_arq({})
    -- end
    
    local _patrecs = {}
    for i = 1, (#pattern_group - snapshot_count) do
        _patrecs[i] = Produce.grid.pattern_recorder()
    end

    function snapshot(i)
        if #(snapshots[i] or {}) == 0 then 
            snapshots[i] = arq.sequence
        end
    end
    function clear_snapshot(i)
        snapshots[i] = {}
    end
    function recall(i)
        if #(snapshots[i] or {}) > 0 then 
            set_arq(snapshots[i])
        end
    end

    local _snapshots = {}
    for i = 1, snapshot_count do
        _snapshots[i] = Produce.grid.multitrigger()
    end
    
    local _reverse = Grid.toggle()
    local _rate_mark = Grid.fill()
    local _rate = Grid.integer()

    return function(props)
        for i,_patrec in ipairs(_patrecs) do
            _patrec{
                x = 4 + i - 1, y = 1,
                pattern = pattern_group[i],
            }
        end

        for i,_snapshot in ipairs(_snapshots) do
            local filled = (snapshots[i] and #snapshots[i] > 0)
            _snapshot{
                x = 12 - snapshot_count + i, y = 1,
                levels = { filled and 4 or 0, filled and 15 or 8 },
                action_tap = function() recall(i) end,
                action_double_tap = function() snapshot(i) end,
                action_hold = function() clear_snapshot(i) end,
            }
        end
        
        if #arq.sequence > 0 then
            _reverse{
                x = 1, y = 2, levels = { 4, 15 },
                state = crops.of_param(arq:pfix('reverse'))
            }
            _rate_mark{
                x = 5, y = 2, level = 4,
            }
            _rate{
                x = 2, y = 2, size = 11,
                state = crops.of_param(arq:pfix('division'))
            }
        end

        _frets{
            x = 1, y = 8, size = keymap_size, wrap = keymap_wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 1 },
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

local Pages = {
    [1] = {}, --poly
    [2] = {}, --mono
    tuning = {},
}

local function Rate_reverse()
    local _reverse = Grid.toggle()
    local _rate_mark = Grid.fill()
    local _rate = Grid.integer()

    return function(props)
        local pattern = props.mute_group:get_playing_pattern()

        if pattern then
            _reverse{
                x = 1, y = 2, levels = { 4, 15 },
                state = {
                    pattern.reverse and 1 or 0,
                    function(v)
                        pattern:set_reverse(v == 1)

                        crops.dirty.grid = true
                    end
                }
            }
            _rate_mark{
                x = 7, y = 2, level = 4,
            }
            do
                local tf = pattern.time_factor
                _rate{
                    x = 2, y = 2, size = 11, min = -5,
                    state = {
                        (tf < 1) and ((1/tf) - 1) or ((-tf) + 1),
                        function(v)
                            pattern.time_factor = (v >= 0) and (1/(v + 1)) or (-(v - 1))

                            crops.dirty.grid = true
                        end
                    }
                }
            end
        end
    end
end

Pages[1].grid = function()
    local _patrecs = {}
    for i = 1, #pattern_groups[1].manual do
        _patrecs[i] = Produce.grid.pattern_recorder()
    end

    local _rate_rev = Rate_reverse()

    local _mode_arq = Grid.toggle()
    local _arq = Arq{
        arq = arqs[1],
        pattern_group = pattern_groups[1].arq,
        mute_group = mute_groups[1].arq,
        snapshots = snapshots[1],
        snapshot_count = snapshot_count,
    }

    local _frets = Tune.grid.fretboard()
    local _keymap = Keymap.grid.poly()

    return function()
        local mode = params:get('mode_1')

        _mode_arq{
            x = 3, y = 1, levels = { 4, 15 },
            state = crops.of_variable(
                mode==ARQ and 1 or 0,
                function(v)
                    params:set('mode_1', v==1 and ARQ or NORMAL)

                    crops.dirty.grid = true
                end
            )
        }

        if mode==NORMAL then
            for i,_patrec in ipairs(_patrecs) do
                _patrec{
                    x = 5 + i - 1, y = 1,
                    pattern = pattern_groups[1].manual[i],
                }
            end
            _rate_rev{
                mute_group = mute_groups[1].manual,
            }

            _frets{
                x = 1, y = 8, size = keymap_size, wrap = keymap_wrap,
                flow = 'right', flow_wrap = 'up',
                levels = { 0, 4 },
                toct = params:get('oct_1'),
                column_offset = params:get('column_1'),
                row_offset = params:get('row_1'),
            }
            _keymap{
                x = 1, y = 8, size = keymap_size, wrap = keymap_wrap,
                flow = 'right', flow_wrap = 'up',
                levels = { 0, 15 },
                keymap = keymaps[1],
            }
        elseif mode==ARQ then
            _arq{ track = 1 }
        end
    end
end

Pages[2].grid = function()
    local _patrecs = {}
    for i = 1, #pattern_groups[2].manual do
        _patrecs[i] = Produce.grid.pattern_recorder()
    end
    
    local _rate_rev = Rate_reverse()
    
    local _mode_arq = Grid.toggle()
    local _arq = Arq{
        arq = arqs[2],
        pattern_group = pattern_groups[2].arq,
        mute_group = mute_groups[2].arq,
        snapshots = snapshots[2],
        snapshot_count = snapshot_count,
    }
    
    local _frets = Tune.grid.fretboard()
    local _keymap = Keymap.grid.mono()

    return function()
        local mode = params:get('mode_2')

        _mode_arq{
            x = 3, y = 1, levels = { 4, 15 },
            state = crops.of_variable(
                mode==ARQ and 1 or 0,
                function(v)
                    params:set('mode_2', v==1 and ARQ or NORMAL)

                    crops.dirty.grid = true
                end
            )
        }

        if mode==NORMAL then
            for i,_patrec in ipairs(_patrecs) do
                _patrec{
                    x = 5 + i - 1, y = 1,
                    pattern = pattern_groups[2].manual[i],
                }
            end
            
            _rate_rev{
                mute_group = mute_groups[2].manual,
            }

            _frets{
                x = 1, y = 8, size = keymap_size, wrap = keymap_wrap,
                flow = 'right', flow_wrap = 'up',
                levels = { 0, 4 },
                toct = params:get('oct_2'),
                column_offset = params:get('column_2'),
                row_offset = params:get('row_2'),
            }
            _keymap{
                x = 1, y = 8, size = keymap_size, wrap = keymap_wrap,
                flow = 'right', flow_wrap = 'up',
                keymap = keymaps[2],
            }
        elseif mode==ARQ then
            _arq{ track = 1 }
        end
    end
end

Pages.tuning.grid = function()
    local _tonic = Tune.grid.tonic()
    
    local _degs_bg = Tune.grid.scale_degrees_background()
    local _degs = {}
    for i = 1, 12 do 
        _degs[i] = Tune.grid.scale_degree()
    end

    return function()
        _tonic{
            left = 1, top = 7, levels = { 4, 15 },
            state = Tune.of_preset_param('tonic'),
        }
        _degs_bg{
            left = 1, top = 4, level = 4
        }
        for i,_deg in ipairs(_degs) do
            _deg{
                left = 1, top = 4, levels = { 8, 15 },
                degree = i, state = Tune.of_preset_param('enable_'..i)
            }
        end
    end
end

local App = {}

function App.grid()
    local _track = Grid.integer()
    
    local _column = Produce.grid.integer_trigger()
    local _row = Produce.grid.integer_trigger()

    local _pages = {}
    for i,Page in ipairs(Pages) do _pages[i] = Page.grid() end

    local _tuning = Pages.tuning.grid()
    
    return function()
        if not k1 then
            _track{
                x = 1, y = 1, size = #_pages, levels = { 0, 15 },
                state = { 
                    track, 
                    function(v) 
                        track = v

                        crops.dirty.grid = true 
                    end
                }
            }
        
            _column{
                x_next = 14, y_next = 1,
                x_prev = 13, y_prev = 1,
                levels = { 4, 15 }, wrap = false,
                min = params:lookup_param('column_'..track).min,
                max = params:lookup_param('column_'..track).max,
                state = crops.of_param('column_'..track)
            }
            _row{
                x_next = 16, y_next = 1,
                x_prev = 16, y_prev = 2,
                levels = { 4, 15 }, wrap = false,
                min = params:lookup_param('row_'..track).min,
                max = params:lookup_param('row_'..track).max,
                state = crops.of_param('row_'..track)
            }

            _pages[track]()
        else
            _tuning()
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


function Pages.tuning.norns()
    local _degs = Tune.screen.scale_degrees()    
    
    local _scale = { enc = Enc.integer(), screen = Screen.list() }
    local _tuning = { enc = Enc.integer(), screen = Screen.list() }
    local _rows = { enc = Enc.integer(), screen = Screen.list() }
    local _frets = { key = Key.integer(), screen = Screen.list() }

    local fret_id = tune.get_preset_param_id('fret_marks')
    local fret_opts = params:lookup_param(fret_id).options
    local frets_text = { 'frets' }
    for _,v in ipairs(fret_opts) do table.insert(frets_text, v) end

    return function()
        _degs{
            x = x[1], y = y[1.5]
        }
        do
            local id = tune.get_scale_param_id()
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
            local id = tune.get_preset_param_id('tuning')
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
            local id = tune.get_preset_param_id('row_tuning')
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
    local _tuning = Pages.tuning.norns()

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
        else _tuning() end
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
                    pattern_groups[i][ii]:import(data.pattern_groups[i][k][ii], true)
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
        for k,_ in pairs(data.pattern_groups[i]) do
            data.pattern_groups[i][k] = {}
            for ii, pattern in ipairs(pattern_groups[i][k]) do
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
