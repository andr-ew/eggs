pattern_time = include 'lib/pattern_time/pattern_time'

include 'lib/crops/core'
Grid = include 'lib/crops/components/grid'
Enc = include 'lib/crops/components/enc'
Key = include 'lib/crops/components/key'
Screen = include 'lib/crops/components/screen'
Produce = include 'lib/produce/produce'

multipattern = include 'lib/multipattern/multipattern'
yolk = include 'lib/yolk-lib/yolk-lib'

polysub = require 'engine/polysub'
engine.name = 'PolySub'

scale = { 1/1, 9/8, 81/64, 3/2, 27/16 }

g = grid.connect()

pattern = pattern_time.new() 
mpat = multipattern.new(pattern)

local App = {}

function App.grid()
    local size = 128-16
    local wrap = 16

    local function note_on(idx)
        local x, y = (idx-1)%wrap + 1, (idx-1)//wrap + 1

        local oct = y + ((x - 1) // #scale)
        local deg = ((x - 1) % #scale) + 1
        local ratio = scale[deg]
        local hz = 110 * 2^(oct - 3) * ratio

        engine.start(idx, hz)
    end
    local function note_off(idx) engine.stop(idx) end

    local state, handlers = yolk.poly{ 
        note_on = note_on, 
        note_off = note_off,
        multipattern = mpat,
        size = size,
    }

    local _patrec = Produce.grid.pattern_recorder()
    local _momentaries = Grid.momentaries()

    return function()
        _patrec{
            x = 1, y = 1,
            pattern = pattern,
            events = handlers,
        }

        _momentaries{
            x = 1, y = 8, size = size, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 15 },
            state = state,
        }
    end
end

_app = {
    grid = App.grid(), 
}

function init()
    polysub:params()
end

crops.connect_grid(_app.grid, g)
-- crops.connect_enc(_app.norns)
-- crops.connect_key(_app.norns)
-- crops.connect_screen(_app.norns)
