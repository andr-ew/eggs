local crow_outs = { {}, {} }

local TRANSIENT, SUSTAIN, CYCLE = 1,2,3
local mode_names = { 'transient', 'sustain', 'cycle' }
local shape_names = {
    'linear',
    'sine',
    'logarithmic',
    'exponential',
    'now',
    'wait',
    'over',
    'under',
    'rebound',
}

for i = 1,2 do
    local off = i==2 and 2 or 0
    local outs = { cv = 1+off, gate = 2+off }
    
    local mode = SUSTAIN

    local preset = 2 + i
    local oct = 0
    local column = 0
    local row = -2
    local index = 0
    local volts = { cv = 0, gate = 0 }

    local function update_volts_cv()
        local x = (index-1)%eggs.keymap_wrap + 1 + column 
        local y = (index-1)//eggs.keymap_wrap + 1 + row 

        local cv = math.max(0, eggs.tunes[preset]:volts(x, y, nil, oct))
        crow.output[outs.cv].volts = cv
                
        crops.dirty.screen = true
    end
    
    local slew_times = { 0.05, 0.07, 0.1, 0.2, 0.3, 0.4, 0.5, 1 }

    local slew_enable = 0
    local slew_time = slew_times[1]

    local function update_slew()
        crow.output[outs.cv].slew = slew_enable * slew_time
    end

    crow_outs[i].voicing = 'mono'

    crow_outs[i].set_note = function(idx, gate)
        if gate > 0 then
            index = idx; update_volts_cv()
        end

        if mode == SUSTAIN then
            crow.output[outs.gate](gate > 0)
        else
            if gate > 0 then crow.output[outs.gate]() end
        end
    end
    
    local time = 0.04
    local ramp = 0
    local level = 7
    local shape = tab.key(shape_names, 'linear')
    local retrigger = 0

    local function update_dyn()
        local a, r

        if ramp > 0 then
            r = time * (0.5 + ramp/2)
            a = time * (0.5 - ramp/2)
        else
            r = time * (0.5 - -ramp/2)
            a = time * (0.5 + -ramp/2)
        end

        crow.output[outs.gate].dyn.l = level
        crow.output[outs.gate].dyn.a = a
        crow.output[outs.gate].dyn.r = r
    end

    local function update_asl()
        local shp = "'"..shape_names[shape].."'"
        local rt = retrigger > 0
        local lock = rt and "" or "lock{"
        local end_lock = rt and "" or "}"

        if mode == TRANSIENT then
            crow.output[outs.gate].action = "{"..
                "to(dyn{ l = 7 }, dyn{a = 1}, "..shp.."),"..
                    lock..
                        "to(0, dyn{r = 1}, "..shp..")"..
                    end_lock..
                "}"
        elseif mode == SUSTAIN then
            crow.output[outs.gate].action = "{"..
                "held{ to(dyn{ l = 7 }, dyn{a = 1}, "..shp..") },"..
                lock..
                    "to(0, dyn{r = 1}, "..shp..")"..
                end_lock..
            "}"
        elseif mode == CYCLE then
            crow.output[outs.gate].action = "{"..
                lock..
                    "loop{"..
                        "to(dyn{ l = 7 }, dyn{a = 1}, "..shp.."),"..
                        "to(0, dyn{r = 1}, "..shp.."),"..
                    "}"..
                end_lock..
            "}"
        end

        update_dyn()
    end

    crow_outs[i].add = function()
        update_asl()
        update_slew()
        update_volts_cv()
    end

    crow_outs[i].params_count = 14

    crow_outs[i].name = 'output '..outs.cv..' + '..outs.gate

    local param_ids = {
        tuning_preset = 'tuning_preset_crow_outs_'..i,
        oct = 'oct_crow_outs_'..i,
        row = 'row_crow_outs_'..i,
        column = 'column_crow_outs_'..i,
        shape = 'shape_crow_outs_'..i,
        mode = 'mode_crow_outs_'..i,
        retrigger = 'retrigger_crow_outs_'..i,
        time = 'time_crow_outs_'..i,
        ramp = 'ramp_crow_outs_'..i,
        level = 'level_crow_outs_'..i,
        slew_enable = 'slew_enable_crow_outs_'..i,
        slew_time = 'slew_time_crow_outs_'..i,
    }
    crow_outs[i].param_ids = param_ids

    crow_outs[i].add_params = function()
        params:add_separator('function generator')

        params:add{
            id = param_ids.shape, name = 'shape',
            type = 'option', options = shape_names, default = shape,
            action = function(v)
                shape = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = param_ids.mode, name = 'mode',
            type = 'option', options = mode_names, default = mode,
            action = function(v)
                mode = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = param_ids.retrigger, name = 'retrigger',
            type = 'binary', 
            behavior = 'toggle', default = retrigger,
            action = function(v)
                retrigger = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = param_ids.time, name = 'time', type = 'control',
            controlspec = cs.new(0.001, 16, 'exp', 0, time, "s"),
            action = function(v)
                time = v; update_dyn()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = param_ids.ramp, name = 'ramp', type = 'control',
            controlspec = cs.def { min = -1, max = 1, default = ramp },
            action = function(v)
                ramp = v; update_dyn()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = param_ids.level, name = 'level', type = 'control',
            controlspec = cs.def{ min = 0, max = 10, default = level },
            action = function(v)
                level = v; update_dyn()

                crops.dirty.screen = true
            end,
        }

        params:add_separator('CV')

        params:add{
            type = 'number', id = param_ids.tuning_preset, name = 'tuning preset',
            min = 1, max = presets, default = preset, 
            action = function(v) 
                preset = v

                for _,t in ipairs(eggs.tunes) do
                    t:update_tuning()
                end 
            end,
        }
        params:add{
            type = 'number', id = param_ids.oct, name = 'oct',
            min = -5, max = 5, default = oct,
            action = function(v) 
                oct = v; update_volts_cv()

                crops.dirty.grid = true 
            end
        }
        params:add{
            type = 'number', id = param_ids.column, name = 'column',
            min = -16, max = 16, default = column,
            action = function(v) 
                column = v; update_volts_cv()

                crops.dirty.grid = true 
            end
        }
        params:add{
            type = 'number', id = param_ids.row, name = 'row',
            min = -16, max = 16, default = row,
            action = function(v) 
                row = v; update_volts_cv()

                crops.dirty.grid = true 
            end
        }
        params:add{
            id = param_ids.slew_enable, name = 'slew enable',
            type = 'binary', behavior = 'momentary', default = slew_enable,
            action = function(v)
                slew_enable = v; update_slew()

                crops.dirty.grid = true
            end,
        }
        params:add{
            type = 'option', id = param_ids.slew_time, name = 'slew time',
            options = slew_times,
            action = function(v)
                slew_time = slew_times[v]; update_slew()

                crops.dirty.grid = true
            end
        }
    end

    for k,out in pairs(outs) do
        crow.output[out].receive = function(v)
            volts[k] = v
            crops.dirty.screen = true
        end
    end

    local fps = 40
    clock.run(function() while true do
        crow.output[outs.cv].query()
        crow.output[outs.gate].query()
        clock.sleep(1/fps)
    end end)

    crow_outs[i].Components = { norns = {} }

    crow_outs[i].Components.norns.page = function()
        local _e1 = Components.enc_screen.param()
        local _e2 = Components.enc_screen.param()
        local _e3 = Components.enc_screen.param()

        local _k2 = Components.key_screen.param()

        return function()
            _e1{ id = param_ids.time, n = 1 }
            _e2{ id = param_ids.shape, n = 2 }
            _e3{ id = param_ids.ramp, n = 3 }
            
            _k2{ id = param_ids.mode, id_hold = param_ids.retrigger, n = 2 }

            if crops.device == 'screen' and crops.mode == 'redraw' then
                for ii,k in ipairs{ 'cv', 'gate' } do
                    screen.level(8)
                    screen.move(eggs.x[1], eggs.e[1].y + 2 + (ii + (i - 1)*2)*6)
                    screen.line_width(1)
                    screen.line_rel(volts[k] * eggs.w * (1/10) * 1 + 1, 0)
                    screen.stroke()
                end
            end
        end
    end
end

return crow_outs
