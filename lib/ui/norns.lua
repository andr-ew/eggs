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
        local out = eggs.track_dest[track]
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
                text = 'press K3 to restart?'
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
        local out = eggs.track_dest[track]
        local tune = eggs.tunes[params:get(out.param_ids.tuning_preset)]
        local keymap = eggs.keymaps[track]
        local arq = eggs.arqs[track]

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
        local mask_props = {
            x = 1, y = 1, size = eggs.keymap_size, wrap = eggs.keymap_wrap,
            flow = 'right', flow_wrap = 'up',
        }

        if props.arq then
            local index = arq.sequence[arq.step]
            local gate = arq.gate
            
            if index and gate > 0 then
                local x, y = Grid.util.index_to_xy(mask_props, index)
                screen.level(lvl_key)
                screen.pixel(
                    (x - 1)*2 + props.x, 
                    (y - 1)*2 + props.y
                )
                screen.fill()
            end
        elseif props.voicing == 'poly' then
            local keys = keymap:get_state()[1]

            for i = 1,eggs.keymap_size do
                if (keys[i] or 0) > 0 then
                    local x, y = Grid.util.index_to_xy(mask_props, i)

                    screen.level(lvl_key)
                    screen.pixel(
                        (x - 1)*2 + props.x, 
                        (y - 1)*2 + props.y
                    )
                    screen.fill()
                end
            end
        else
            local index, gate = table.unpack(keymap:get_state()[1] or { 1, 0 })
            if gate > 0 then
                local x, y = Grid.util.index_to_xy(mask_props, index)
                screen.level(lvl_key)
                screen.pixel(
                    (x - 1)*2 + props.x, 
                    (y - 1)*2 + props.y
                )
                screen.fill()
            end
        end
    end
end

local function App()
    local _map = Key.momentary()

    local _mapping_modal = Patcher.screen.last_connection()
    
    local _tuning = Tuning()

    local _keymaps = {}
    for track = 1,eggs.track_count do
        -- _pages[track] = eggs.track_dest[track].Components.norns.page()
        _keymaps[track] = Keymap()
    end
    
    local _dest_pages = {}
    for track,dests in ipairs(eggs.dests) do
        _dest_pages[track] = {}

        for i in ipairs(dests) do
            _dest_pages[track][i] = eggs.dests[track][i].Components.norns.page()
        end
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

                    patcher.last_assignment.src = nil
                    patcher.last_assignment.dest = nil
                end)
            }

            local i_dest = params:get('dest_track_'..eggs.track_focus)
            _dest_pages[eggs.track_focus][i_dest]{ dest = eggs.track_dest[eggs.track_focus] }

            local top = { 21, 36, 40, 43, }

            if eggs.mapping and patcher.last_assignment.src then
                _mapping_modal{
                    x_left = x[1], x_right = x[2], y = 30,
                }
            else
                if crops.device == 'screen' and crops.mode == 'redraw' then
                    for i = 1,2 do
                        local out = eggs.crow_dests[i]
                        for ii,k in ipairs{ 'cv', 'gate' } do
                            screen.level(8)
                            screen.move(eggs.x[i], top[2 + ii])
                            screen.line_width(1)
                            screen.line_rel(out.volts[k] * (eggs.w/2) * (1/10) * 1 + 1, 0)
                            screen.stroke()
                        end
                    end

                    screen.display_png(norns.state.lib..'img/grid_bg.png', x[1], top[1] - 10)
                end

                for i,_keymap in ipairs(_keymaps) do
                    _keymaps[i]{
                        track = i, x = x[(i - 1)%2 + 1], y = top[(i - 1)//2 + 1], 
                        voicing = eggs.track_dest[i].voicing, 
                        arq = params:get('mode_'..i) == eggs.ARQ,
                    }
                end
            end
            
            if crops.device == 'screen' and crops.mode == 'redraw' then
                do
                    local w = 88
                    screen.display_png(
                        norns.state.lib
                            ..'img/glyph_'..({ 
                                'flower', 'leaf', 'wing_left', 'wing_right' 
                            })[eggs.track_focus]
                            ..'.png', 
                        (128/2) - (w/2), 
                        -6
                    )
                end
                for i = 1,eggs.track_count do
                    local size = eggs.track_count / 2
                    local column = (i - 1) % size
                    local row = (i - 1) // size
                    local mar = 3
                    local w = 9
                    local h = 9

                    local x = eggs.x[3] - (size - 1 - column)*(w + mar) - mar
                    local y = eggs.e[1].y + h*row

                    screen.font_face(1)
                    screen.font_size(8)
                    screen.move(x, y)
                    screen.level(i == eggs.track_focus and 15 or 4)
                    screen.text(eggs.track_dest[i].shortname)
                end
            end
        else
            _tuning{ track = eggs.track_focus, view = eggs.view_focus }
        end
    end
end

return App
