local x, y
do
    local top, bottom = 8, 64-2
    local left, right = 2, 128-2
    local mul = { x = (right - left) / 2, y = (bottom - top) / 2 }
    x = { left, left + mul.x*5/4, [1.5] = 24  }
    y = { top, bottom - 22, bottom, [1.5] = 20, }
end

local function Tuning()
    local _degs = Tune.screen.scale_degrees()    
    
    local _scale = { enc = Enc.integer(), screen = Screen.list() }
    local _rows = { enc = Enc.integer(), screen = Screen.list() }
    local _frets = { key = Key.integer(), screen = Screen.list() }

    local _tuning = { enc = Enc.integer(), screen = Screen.list() }
    local _base_key = { enc = Enc.integer(), screen = Screen.list() }

    return function(props)
        local track = props.track
        local view = props.view

        _degs{
            x = x[1], y = y[1.5], tune = eggs.get_tune(track),
            -- width = 7, nudge = 6, -- 8x8 sizing
            width = 12, nudge = 3,
        }

        if view == eggs.SCALE then
            do
                local id = eggs.get_tune(track):get_scale_param_id()
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
                local id = eggs.get_tune(track):get_param_id('row_tuning')
                _rows.enc{
                    n = 2, max = params:lookup_param(id).max,
                    state = crops.of_param(id)
                }
                _rows.screen{
                    x = x[1], y = y[2], flow = 'down',
                    text = { rows = params:string(id) }
                }
            end
            do
                local fret_id = eggs.get_tune(props.track):get_param_id('fret_marks')
                local fret_opts = params:lookup_param(fret_id).options
                local frets_text = { 'frets' }
                for _,v in ipairs(fret_opts) do table.insert(frets_text, v) end

                _frets.key{
                    n_prev = 2, n_next = 3, max = #fret_opts,
                    state = crops.of_param(fret_id)
                }
                _frets.screen{
                    x = x[1], y = y[3],
                    text = frets_text, focus = params:get(fret_id) + 1,
                }
            end
        elseif view == eggs.KEY then
            do
                local id = eggs.get_tune(track):get_param_id('tuning')
                _tuning.enc{
                    n = 1, max = #params:lookup_param(id).options,
                    state = crops.of_param(id)
                }
                _tuning.screen{
                    x = x[1], y = y[1],
                    text = { tuning = params:string(id) }
                }
            end
            do
                local id = 'base_tonic'
                _tuning.enc{
                    n = 2, state = crops.of_param(id),
                    min = params:lookup_param(id).min, max = params:lookup_param(id).max,
                }
                _tuning.screen{
                    x = x[1], y = y[2], flow = 'down',
                    text = { ['base key'] = params:string(id) },
                }
            end
        end
    end
end

local function App()
    local _text = Screen.text()
    local _tuning = Tuning()
    local _dest = { enc = Enc.integer(), screen = Screen.list() }

    return function()
        if eggs.view_focus == eggs.NORMAL then 
            _text{ x = x[1], y = y[1], text = 'this is eggs' }
            
            do
                local id = 'target_'..eggs.track_focus
                _dest.enc{
                    n = 2, state = crops.of_param(id),
                    max = #params:lookup_param(id).options,
                }
                _dest.screen{
                    x = x[1], y = y[2], flow = 'down',
                    text = { ['destination'] = params:string(id) },
                }
            end
        else
            _tuning{ track = eggs.track_focus, view = eggs.view_focus }
        end
    end
end

return App
