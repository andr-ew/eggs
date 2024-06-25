local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

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
        local out = eggs.outs[track]
        local tune = eggs.tunes[params:get(out.param_ids.tuning_preset)]

        _degs{
            x = x[1], y = y[1.5], tune = tune,
            -- width = 7, nudge = 6, -- 8x8 sizing
            width = 12, nudge = 3,
        }

        if view == eggs.SCALE then
            do
                local id = tune:get_scale_param_id()
                _scale.enc{
                    n = 1, max = #params:lookup_param(id).options,
                    state = crops.of_param(id)
                }
                _scale.screen{
                    x = x[1], y = e[1].y,
                    text = { scale = params:string(id) }
                }
            end
            do
                local id = tune:get_param_id('row_tuning')
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
                local fret_id = tune:get_param_id('fret_marks')
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
                local id = tune:get_param_id('tuning')
                _tuning.enc{
                    n = 1, max = #params:lookup_param(id).options,
                    state = crops.of_param(id)
                }
                _tuning.screen{
                    x = x[1], y = e[1].y,
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

local function Change_engine_modal()
    local _l1 = Screen.text()
    local _l2 = Screen.text()
    local _l3 = Screen.text()

    local _no = {
        key = Key.trigger(),
        screen = Screen.text(),
    }
    local _yes = {
        key = Key.trigger(),
        screen = Screen.text(),
    }

    return function(props)
        local left, right = x[1] + 1, x[3] - 1

        do
            local yy = y[1] + 5
            local x, flow, level = left, 'right', 8
            _l1{
                x = x, y = yy, --y = 64/2,
                flow = flow, level = level,
                text = 'you changed the engine!',
            } 
            yy = yy + 8

            _l2{
                x = x, y = yy, --y = 64/2,
                flow = flow, level = level,
                text = 'u gotta restart for that...'
            } 
            yy = yy + 8
            _l3{
                x = x, y = yy, --y = 64/2,
                flow = flow, level = level,
                text = '...restart?'
            } 
        end

        _no.key{
            n = 2, 
            input = function(z) if z==0 then
                eggs.change_engine_modal = false
                crops.dirty.screen = true
            end end
        }
        _no.screen{
            x = left, y = e[2].y,
            text = 'uhh no',
        } 
        _yes.key{
            n = 3, 
            input = function(z) if z==0 then
                norns.script.load(norns.state.script)
            end end
        }
        _yes.screen{
            x = right, y = e[3].y,
            text = 'ok :/',
            flow = 'left'
        } 
    end
end

local function Keymap()
    -- local _frets = Tune.screen.fretboard()

    return function(props)
        local track = props.track
        local out = eggs.outs[track]
        local tune = eggs.tunes[params:get(out.param_ids.tuning_preset)]
        local keymap = eggs.keymaps[track]

        -- can't use cause it's noticibly slower with all the single pixel draw calls :/
        -- _frets{
        --     x = props.x, y = props.y, 
        --     size = eggs.keymap_size, wrap = eggs.keymap_wrap,
        --     flow = 'right', flow_wrap = 'up',
        --     levels = { 0, 2 },
        --     tune = tune,
        --     toct = 0, --?
        --     column_offset = out.column,
        --     row_offset = out.row,
        -- }

        local lvl_key = 10

        --TODO: draw mono, arq
        if props.voicing == 'poly' then
            local keys = keymap:get_state()[1]

            for i = 1,eggs.keymap_size do
                if (keys[i] or 0) > 0 then
                    local x, y = Grid.util.index_to_xy({ 
                        x = 1, y = 1, size = eggs.keymap_size, wrap = eggs.keymap_wrap,
                        flow = 'right', flow_wrap = 'up',
                    }, i)

                    screen.level(lvl_key)
                    screen.pixel(
                        (x - 1)*2 + props.x, 
                        (y - 1)*2 + props.y
                    )
                    screen.fill()
                end
            end
        else
        end
    end
end

local function App()
    local _map = Key.momentary()
    
    local _tuning = Tuning()

    local _pages = {}
    local _keymaps = {}
    for track = 1,eggs.track_count do
        _pages[track] = eggs.outs[track].Components.norns.page()
        _keymaps[track] = Keymap()
    end

    local _change_engine_modal = Change_engine_modal()

    return function()
        if eggs.change_engine_modal then
            _change_engine_modal()
        elseif eggs.view_focus == eggs.NORMAL then 
            _map{
                n = 1, state = crops.of_variable(eggs.mapping, function(v) 
                    eggs.mapping = v>0
                    crops.dirty.screen = true
                    crops.dirty.grid = true
                end)
            }

            _pages[eggs.track_focus]()

            local top = { 21, 35, 40, 43, }

            --TODO: draw single PNG of all key grids
            _keymaps[1]{ track = 1, x = x[1], y = top[1], voicing = eggs.outs[1].voicing }
            _keymaps[2]{ track = 2, x = x[2], y = top[1], voicing = eggs.outs[2].voicing  }
            _keymaps[3]{ track = 3, x = x[1], y = top[2], voicing = eggs.outs[3].voicing  }
            _keymaps[4]{ track = 4, x = x[2], y = top[2], voicing = eggs.outs[4].voicing  }
            
            if crops.device == 'screen' and crops.mode == 'redraw' then
                for i = 1,2 do
                    local out = eggs.outs[2 + i]
                    for ii,k in ipairs{ 'cv', 'gate' } do
                        screen.level(8)
                        screen.move(eggs.x[i], top[2 + ii])
                        screen.line_width(1)
                        screen.line_rel(out.volts[k] * (eggs.w/2) * (1/10) * 1 + 1, 0)
                        screen.stroke()
                    end
                end
            end
        else
            _tuning{ track = eggs.track_focus, view = eggs.view_focus }
        end
    end
end

return App
