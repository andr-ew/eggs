pattern_time = include 'lib/pattern_time/pattern_time'

include 'lib/crops/core'
Grid = include 'lib/crops/components/grid'
Enc = include 'lib/crops/components/enc'
Key = include 'lib/crops/components/key'
Screen = include 'lib/crops/components/screen'
Produce = include 'lib/produce/produce'

multipattern = include 'lib/multipattern/multipattern'

polysub = require 'engine/polysub'
engine.name = 'PolySub'

scale = { 1/1, 9/8, 81/64, 3/2, 27/16 }

g = grid.connect()

pattern = pattern_time.new() 
mpat = multipattern.new(pattern)

local App = {}

function App.grid()
    local count = 128-16
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

    local keys = {}
    local set_keys = function(value)
        local news, olds = value, keys
        
        for i = 1, count do
            local new = news[i] or 0
            local old = olds[i] or 0

            if new==1 and old==0 then note_on(i)
            elseif new==0 and old==1 then note_off(i) end
        end

        keys = value
        crops.dirty.grid = true
        crops.dirty.screen = true
    end
    local set_keys_wr = mpat:wrap('keys', set_keys)

    local clear = function() set_keys({}) end
    local snapshot = function() 
        local has_keys = false
        for i = 1, count do if (keys[i] or 0) > 0 then  
            has_keys = true; break
        end end

        if has_keys then set_keys_wr(keys) end
    end

    local keys_stash = {}
    local stash = function()
        keys_stash = keys
        set_keys({})
    end
    local pop = function()
        set_keys(keys_stash)
    end

    local _patrec = Produce.grid.pattern_recorder()
    local _momentaries = Grid.momentaries()

    return function()
        _patrec{
            x = 1, y = 1,
            pattern = pattern,
            pre_clear = clear,
            pre_rec_stop = snapshot,
            post_rec_start = snapshot,
            post_stop = stash,
            pre_resume = pop,
        }

        _momentaries{
            x = 1, y = 8, size = count, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 15 },
            state = { keys, set_keys_wr },
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
