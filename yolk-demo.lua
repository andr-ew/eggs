pattern_time = include 'lib/pattern_time/pattern_time'

include 'lib/crops/core'
Grid = include 'lib/crops/components/grid'
Enc = include 'lib/crops/components/enc'
Key = include 'lib/crops/components/key'
Screen = include 'lib/crops/components/screen'
Produce = include 'lib/produce/produce'

multipattern = include 'lib/multipattern/multipattern'
yolk = include 'lib/yolk-lib/yolk-lib'

tune = include 'lib/tune/tune'
local tunings, scale_groups = include 'lib/tune/scales'
Tune = include 'lib/tune/ui'

tune.setup{ 
    tunings = tunings, scale_groups = scale_groups, presets = 8,
    action = function() 
        crops.dirty.grid = true 
        crops.dirty.screen = true
    end
}

polysub = require 'engine/polysub'
engine.name = 'PolySub'

scale = { 1/1, 9/8, 81/64, 3/2, 27/16 }

g = grid.connect()

pattern = { 
    pattern_time.new(),
    pattern_time.new() 
}
-- mpat = multipattern.new(pattern)

--TODO: block input during playback

params:add{
    type = 'number', id = 'oct 1',
    min = -2, max = 2, default = 0,
    action = function() crops.dirty.grid = true end
}

tune.params()
params:add_separator('')
polysub:params()

local Pages = {}

Pages[1] = function()
    local size = 128-16-16
    local wrap = 16

    local function action_on(idx)
        local x, y = (idx-1)%wrap + 1, (idx-1)//wrap + 1

        local hz = tune.hz(x, y, nil, params:get('oct 1')) * 55

        engine.start(idx, hz)
    end
    local function action_off(idx) engine.stop(idx) end

    local state, handlers = yolk.poly{
        action_on = action_on,
        action_off = action_off,
        pattern = pattern[1],
        size = size,
    }

    local _patrec = Produce.grid.pattern_recorder()

    local _oct = Grid.integer()
    local _oct_mark = Grid.fill()

    local _momentaries = Grid.momentaries()
    local _frets = Tune.grid.fretboard()

    return function()
        _patrec{
            x = 1, y = 2,
            pattern = pattern[1],
            events = handlers,
        }

        _oct_mark{ x = 6, y = 1, level = 4 }
        _oct{
            x = 4, y = 1, size = 5, levels = { 0, 15 },
            min = params:lookup_param('oct 1').min,
            state = crops.of_param('oct 1')
        }

        _frets{
            x = 1, y = 8, size = size, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 4 },
            toct = params:get('oct 1')
        }
        _momentaries{
            x = 1, y = 8, size = size, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 15 },
            state = state,
        }
    end
end

Pages[2] = function()
    local size = 128-16-16
    local wrap = 16

    local function action(idx, gate)
        local x, y = (idx-1)%wrap + 1, (idx-1)//wrap + 1

        local oct = y + ((x - 1) // #scale)
        local deg = ((x - 1) % #scale) + 1
        local ratio = scale[deg]
        local hz = 110 * 2^(oct - 3) * ratio

        if gate > 0 then
            engine.start(0, hz)
        else
            engine.stop(0)
        end
    end

    local states, handlers, interrupt = yolk.mono{
        action = action,
        pattern = pattern[2],
        size = size,
    }
    
    local _patrec = Produce.grid.pattern_recorder()
    local _momentaries = Grid.momentaries()
    local _integer = Grid.integer()

    return function()
        _patrec{
            x = 1, y = 2,
            pattern = pattern[2],
            events = handlers,
        }

        if crops.mode == 'input' then
            _momentaries{
                x = 1, y = 8, size = size, wrap = wrap,
                flow = 'right', flow_wrap = 'up',
                state = states.momentaries,
            }
        elseif crops.mode == 'redraw' then
            if states.gate[1] > 0 then
                _integer{
                    x = 1, y = 8, size = size, wrap = wrap,
                    flow = 'right', flow_wrap = 'up',
                    state = states.integer,
                }                
            end
        end
    end
end

Pages[3] = function()
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
    local _pages = {}
    for i,Page in ipairs(Pages) do _pages[i] = Page() end
    
    local tab = 1
    local _tab = Grid.integer()

    return function()
        _tab{
            x = 1, y = 1, size = #_pages, levels = { 4, 15 },
            state = { 
                tab, 
                function(v) tab = v; crops.dirty.grid = true end
            }
        }

        _pages[tab]()
    end
end

function App.norns()
    local x, y
    do
        local top, bottom = 8, 64-2
        local left, right = 2, 128-2
        local mul = { x = (right - left) / 2, y = (bottom - top) / 2 }
        x = { left, left + mul.x*5/4, [1.5] = 24  }
        y = { top, bottom - 22, bottom, [1.5] = 20, }
    end

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

_app = {
    grid = App.grid(), 
    norns = App.norns()
}

crops.connect_grid(_app.grid, g, 240)
crops.connect_enc(_app.norns)
crops.connect_key(_app.norns)
crops.connect_screen(_app.norns)

function init()
    params:set('hzlag', 0)
    params:bang()
end
