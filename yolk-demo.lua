pattern_time = include 'lib/pattern_time/pattern_time'

include 'lib/crops/core'
Grid = include 'lib/crops/components/grid'
Enc = include 'lib/crops/components/enc'
Key = include 'lib/crops/components/key'
Screen = include 'lib/crops/components/screen'
Components = include 'lib/components'

multipattern = include 'lib/multipattern/multipattern'

polysub = require 'engine/polysub'
engine.name = 'PolySub'

scale = { 1/1, 9/8, 81/64, 3/2, 27/16 }

g = grid.connect()
grid_clear = function() end
grid_snapshot = function() end

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

    grid_clear = function() set_keys({}) end
    grid_snapshot = function() 
        local has_keys = false
        for i = 1, count do if (keys[i] or 0) > 0 then  
            has_keys = true; break
        end end

        if has_keys then set_keys_wr(keys) end
    end

    local _patrec = Components.grid.pattern_recorder()
    local _momentaries = Grid.momentaries()

    return function()
        _patrec{
            x = 1, y = 1,
            pattern = pattern,
            pre_clear = grid_clear,
            pre_rec_stop = grid_snapshot,
            post_rec_start = grid_snapshot,
        }

        _momentaries{
            x = 1, y = 8, size = count, wrap = wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 15 },
            state = { keys, set_keys_wr },
        }
    end
end

function App.norns()
    local x,y = {}, {}

    local mar = { left = 2, top = 7, right = 2, bottom = 0 }
    local w = 128 - mar.left - mar.right
    local h = 64 - mar.top - mar.bottom

    x[1] = mar.left
    x[2] = 128/2
    y[1] = mar.top
    y[2] = mar.top + h*(1.5/8)
    y[3] = mar.top + h*(5.5/8)
    y[4] = mar.top + h*(7/8)

    local e = {
        { x = x[1], y = y[1] },
        { x = x[1], y = y[3] },
        { x = x[2], y = y[3] },
    }
    local k = {
        { x = x[1], y = y[2] },
        { x = x[1], y = y[4] },
        { x = x[2], y = y[4] },
    }

    local _view_pattern = Screen.text()
    local _direction = Key.toggle()
    local _view_direction = Screen.text()

    return function()
        if crops.device == 'key' and crops.mode == 'input' then
            local n, z = table.unpack(crops.args) 
            if n==2 and z>0 then
                if pattern.rec == 0 then
                    if pattern.data.count > 0 then
                        pattern:stop()
                        grid_clear()
                        pattern:clear()
                    else
                        pattern:rec_start()
                        grid_snapshot()
                    end
                elseif pattern.rec == 1 then
                    grid_snapshot()
                    pattern:rec_stop()

                    if pattern.data.count > 0 then
                        pattern:start()
                    end
                end

                crops.dirty.screen = true
            end
        end
        _view_pattern{
            x = k[2].x,
            y = k[2].y,
            text = (
                pattern.rec==1 and (pattern.data.count>0 and 'recording...' or 'armed')
                or (pattern.data.count>0 and 'stop' or 'record')
            ),
        }

        _direction{
            n = 3,
            state = { 
                pattern.reverse and 1 or 0, 
                function(v) 
                    pattern:set_reverse(v>0)
                    crops.dirty.screen = true
                end
            }
        }
        _view_direction{
            x = k[3].x,
            y = k[3].y,
            text = 'reverse',
            level = ({ 4, 15 })[pattern.reverse and 2 or 1]
        }
    end
end

local _app = {
    grid = App.grid(), 
    norns = App.norns() 
}

function init()
    polysub:params()
end

crops.connect_grid(_app.grid, g)
crops.connect_enc(_app.norns)
crops.connect_key(_app.norns)
crops.connect_screen(_app.norns)
