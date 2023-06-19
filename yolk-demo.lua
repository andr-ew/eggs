pattern_time = include 'lib/pattern_time_extended/pattern_time_extended'
mute_group = include 'lib/pattern_time_extended/mute_group'
Pattern_time = include 'lib/pattern_time_extended/ui'

include 'lib/crops/core'
Grid = include 'lib/crops/components/grid'
Enc = include 'lib/crops/components/enc'
Key = include 'lib/crops/components/key'
Screen = include 'lib/crops/components/screen'
Produce = {}
Produce.grid = include 'lib/produce/grid'
Produce.screen = include 'lib/produce/screen'

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

local pat_count = 9

pattern_groups = {}
mute_groups = {}

for i = 1,2 do
    pattern_groups[i] = {}
    for ii = 1,pat_count do
        pattern_groups[i][ii] = pattern_time.new()
    end

    mute_groups[i] = mute_group.new(pattern_groups[i])
end

k1 = false

local size = 128-16-16
local wrap = 16

local function note_on_poly(idx)
    local column = (idx-1)%wrap + 1 + params:get('column')
    local row = (idx-1)//wrap + 1 + params:get('row')

    local hz = tune.hz(column, row, nil, params:get('oct')) * 55

    engine.start(idx, hz)
end
local function note_off_poly(idx) engine.stop(idx) end
    
local function note_mono(idx, gate)
    local column = (idx-1)%wrap + 1 + params:get('column')
    local row = (idx-1)//wrap + 1 + params:get('row')

    local hz = tune.hz(column, row, nil, params:get('oct')) * 55

    if gate > 0 then
        engine.start(0, hz)
    else
        engine.stop(0)
    end
end
    
do
    params:add_separator('transpose')
    params:add{
        type = 'number', id = 'oct', name = 'oct',
        min = -5, max = 5, default = 0,
        action = function() crops.dirty.grid = true end
    }
    params:add{
        type = 'number', id = 'column', name = 'column',
        min = -16, max = 16, default = 0,
        action = function() crops.dirty.grid = true end
    }
    params:add{
        type = 'number', id = 'row', name = 'row',
        min = -16, max = 16, default = 0,
        action = function() crops.dirty.grid = true end
    }
end
    
arq = arqueggiator.new()

params:add_separator('arqueggiator')
arq:params()
arq:start()

arq.action_on = note_on_poly
arq.action_off = note_off_poly

function clear_arqs() arq.sequence = {} end

tune.params()
params:add_separator('')
polysub:params()

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
        action = function()
            params:write()
        end
    }
end

local Pages = {
    [1] = {}, --poly
    [2] = {}, --mono
    [3] = {}, --sequeggiator
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
    for i = 1, #pattern_groups[1] do
        _patrecs[i] = Produce.grid.pattern_recorder()
    end

    local _rate_rev = Rate_reverse()

    local _frets = Tune.grid.fretboard()
    local _keymap = Pattern_time.grid.keymap_poly{
        action_on = note_on_poly,
        action_off = note_off_poly,
        pattern = mute_groups[1],
        size = size,
    }

    return function()
        for i,_patrec in ipairs(_patrecs) do
            _patrec{
                x = 4 + i - 1, y = 1,
                pattern = pattern_groups[1][i],
            }
        end

        _rate_rev{
            mute_group = mute_groups[1],
        }

        _frets{
            x = 1, y = 8, size = size, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 4 },
            toct = params:get('oct'),
            column_offset = params:get('column'),
            row_offset = params:get('row'),
        }
        _keymap{
            x = 1, y = 8, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 15 },
        }
    end
end

Pages[2].grid = function()
    local _patrecs = {}
    for i = 1, #pattern_groups[2] do
        _patrecs[i] = Produce.grid.pattern_recorder()
    end
    
    local _rate_rev = Rate_reverse()
    
    local _frets = Tune.grid.fretboard()
    local _keymap = Pattern_time.grid.keymap_mono{
        action = note_mono,
        pattern = mute_groups[2],
        size = size,
    }

    return function()
        for i,_patrec in ipairs(_patrecs) do
            _patrec{
                x = 4 + i - 1, y = 1,
                pattern = pattern_groups[2][i],
            }
        end
        
        _rate_rev{
            mute_group = mute_groups[2],
        }

        _frets{
            x = 1, y = 8, size = size, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 4 },
            toct = params:get('oct'),
            column_offset = params:get('column'),
            row_offset = params:get('row'),
        }
        _keymap{
            x = 1, y = 8, size = size, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
        }
    end
end


Pages[3].grid = function()
    local _frets = Tune.grid.fretboard()
    local _keymap = Arqueggiator.grid.keymap()

    local function set_arq(new)
        arq.sequence = new

        crops.dirty.grid = true;
    end

    return function()
        _frets{
            x = 1, y = 8, size = size, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 1 },
            toct = params:get('oct'),
            column_offset = params:get('column'),
            row_offset = params:get('row'),
        }
        _keymap{
            x = 1, y = 8, size = size, wrap = wrap,
            flow = 'right', flow_wrap = 'up', levels = { 4, 8, 15 }, 
            step = arq.step, gate = arq.gate,
            state = crops.of_variable(arq.sequence, set_arq)
        }
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
    local tab = 1
    local _tab = Grid.integer()
    
    local _column = Produce.grid.integer_trigger()
    local _row = Produce.grid.integer_trigger()

    local _pages = {}
    for i,Page in ipairs(Pages) do _pages[i] = Page.grid() end

    local _tuning = Pages.tuning.grid()
    
    return function()
        if not k1 then
            _tab{
                x = 1, y = 1, size = #_pages, levels = { 4, 15 },
                state = { 
                    tab, 
                    function(v) 
                        tab = v

                        for _,mute_group in ipairs(mute_groups) do
                            mute_group:stop()
                        end
                        clear_arqs()

                        crops.dirty.grid = true 
                    end
                }
            }
        
            _column{
                x_next = 14, y_next = 1,
                x_prev = 13, y_prev = 1,
                levels = { 4, 15 }, wrap = false,
                min = params:lookup_param('column').min,
                max = params:lookup_param('column').max,
                state = crops.of_param('column')
            }
            _row{
                x_next = 16, y_next = 1,
                x_prev = 16, y_prev = 2,
                levels = { 4, 15 }, wrap = false,
                min = params:lookup_param('row').min,
                max = params:lookup_param('row').max,
                state = crops.of_param('row')
            }

            _pages[tab]()
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

crops.connect_grid(_app.grid, g, 240)
crops.connect_enc(_app.norns)
crops.connect_key(_app.norns)
crops.connect_screen(_app.norns)

function init()
    params:read()
    params:set('hzlag', 0)
    params:bang()
end

function cleanup()
    if params:string('autosave pset') == 'yes' then params:write() end
end
