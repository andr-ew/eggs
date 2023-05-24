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

local Pages = {}

Pages[1] = function()
    local size = 128-16-16
    local wrap = 16

    local function action_on(idx)
        local x, y = (idx-1)%wrap + 1, (idx-1)//wrap + 1

        local hz = tune.hz(x, y) * 440

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
    local _momentaries = Grid.momentaries()
    local _frets = Tune.grid.fretboard()

    return function()
        _patrec{
            x = 1, y = 2,
            pattern = pattern[1],
            events = handlers,
        }

        _frets{
            x = 1, y = 8, size = size, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 4 },
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

    return function()
        _tonic{
            left = 1, top = 7, levels = { 4, 15 },
            state = Tune.of_preset_param('tonic'),
        }
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

_app = {
    grid = App.grid(), 
}

function init()
    tune.params()
    params:add_separator('')
    polysub:params()
    params:set('hzlag', 0)

    crops.connect_grid(_app.grid, g)
    -- crops.connect_enc(_app.norns)
    -- crops.connect_key(_app.norns)
    -- crops.connect_screen(_app.norns)
end

