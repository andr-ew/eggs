local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k
local Patcher = Map_patcher

local function Tuning()
    return function(props)
        if crops.device == 'screen' and crops.mode == 'redraw' then 
            local i = props.track
            local view = props.view
            local out = eggs.track_dest[i]
            local bottom = e[2].y - 10
            local xx = x[1]
            local current, nxt, prev = eggs.channels:get_key_names(i)
            local keys = { prev, current, nxt }
                
            screen.font_face(1)
            screen.font_size(8)

            local yy = bottom - 1
            for ii,key in ipairs(keys) do
                screen.level(ii == 2 and 10 or 4)
                screen.move(xx, yy)
                screen.text(key)

                yy = yy - 12
            end

            local yy = yy + 24

            local offset = (
                patcher.get_value(eggs.channels:get_param_id(i, 'offset', true)) 
                / eggs.offset_volts_per_step
            )
            if offset ~= 0 then
                screen.level(10)
                screen.move(x[1] + 8, yy)
                screen.text((offset >= 0 and '+ ' or '- ')..math.abs(math.floor(offset)))
            end

            screen.level(10)
            screen.move(x[1] + 24, yy)
            screen.text(
                channels.base_names[eggs.channels[i].intervals][
                    patcher.get_value(eggs.channels:get_param_id(i, 'mode', true))
                ]
            )

            screen.move(64, yy)
            screen.text(channels.interval_names[eggs.channels[i].intervals])
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
        else
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
            _dest_pages[eggs.track_focus][i_dest]{ 
                dest = eggs.track_dest[eggs.track_focus]
            }

            local top = { 21, 36, 40, 43, }

            if eggs.mapping and patcher.last_assignment.src then
                _mapping_modal{
                    x_left = x[1], x_right = x[2], y = 30,
                }
            else
                if eggs.view_focus == eggs.NORMAL then 
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

                        screen.display_png(eggs.img_path..'grid_bg.png', x[1], top[1] - 10)
                    end

                    for i,_keymap in ipairs(_keymaps) do
                        _keymaps[i]{
                            track = i, x = x[(i - 1)%2 + 1], y = top[(i - 1)//2 + 1], 
                            voicing = eggs.track_dest[i].voicing, 
                            arq = params:get('mode_'..i) == eggs.ARQ,
                        }
                    end
                
                else
                    _tuning{ track = eggs.track_focus, view = eggs.view_focus }
                end
            end

            if crops.device == 'screen' and crops.mode == 'redraw' then
                do
                    local w = 88
                    screen.display_png(
                        eggs.img_path..'glyph_'..({ 
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
        end
    end
end

return App
