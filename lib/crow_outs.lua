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
local shape_nicknames = {
    'lin',
    'sine',
    'log',
    'exp',
    'now',
    'wait',
    'over',
    'under',
    'rebound',
}

for i = 1,2 do
    local off = i==2 and 2 or 0
    local jacks = { cv = 1+off, gate = 2+off }
    
    local out = {}
    
    out.mode = SUSTAIN
    out.preset = 2 + i
    out.oct = 0
    out.column = 0
    out.row = -2
    out.index = 0
    out.volts = { cv = 0, gate = 0 }
    out.patched = 1

    out.keyboard_gate = 0
    out.manual_gate = 0

    local function update_volts_cv()
        local x = (out.index-1)%eggs.keymap_wrap + 1 + out.column 
        local y = (out.index-1)//eggs.keymap_wrap + 1 + out.row 

        local cv = math.max(0, eggs.tunes[out.preset]:volts(x, y, nil, out.oct))
        crow.output[jacks.cv].volts = cv
                
        crops.dirty.screen = true
    end

    local function update_gate()
        local gate = (out.keyboard_gate & out.patched) | out.manual_gate

        if out.mode == SUSTAIN then
            crow.output[jacks.gate](gate > 0)
        else
            if gate > 0 then crow.output[jacks.gate]() end
        end
    end
    
    local slew_times = { 0.05, 0.07, 0.1, 0.2, 0.3, 0.4, 0.5, 1 }

    local slew_enable = 0
    local slew_time = slew_times[1]

    local function update_slew()
        crow.output[jacks.cv].slew = slew_enable * slew_time
    end

    out.voicing = 'mono'

    out.set_note = function(idx, gate)
        if gate > 0 then
            out.index = idx; update_volts_cv()
        end

        out.keyboard_gate = gate; update_gate()
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

        crow.output[jacks.gate].dyn.l = level
        crow.output[jacks.gate].dyn.a = a
        crow.output[jacks.gate].dyn.r = r
    end

    local function update_asl()
        local shp = "'"..shape_names[shape].."'"
        local rt = retrigger > 0
        local lock = rt and "" or "lock{"
        local end_lock = rt and "" or "}"

        if out.mode == TRANSIENT then
            crow.output[jacks.gate].action = "{"..
                "to(dyn{ l = 7 }, dyn{a = 1}, "..shp.."),"..
                    lock..
                        "to(0, dyn{r = 1}, "..shp..")"..
                    end_lock..
                "}"
        elseif out.mode == SUSTAIN then
            crow.output[jacks.gate].action = "{"..
                "held{ to(dyn{ l = 7 }, dyn{a = 1}, "..shp..") },"..
                lock..
                    "to(0, dyn{r = 1}, "..shp..")"..
                end_lock..
            "}"
        elseif out.mode == CYCLE then
            crow.output[jacks.gate].action = "{"..
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

    out.add = function()
        update_asl()
        update_slew()
        update_volts_cv()
    end

    out.name = 'output '..jacks.cv..' + '..jacks.gate

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
        trigger = 'trigger_'..i,
        patched = 'patched_'..i,
    }
    out.param_ids = param_ids
    
    out.params_count = 2 + tab.count(param_ids)

    out.add_params = function()
        params:add_separator('crow_fg_'..i, 'function generator')

        patcher.add_destination_and_param{
            id = param_ids.time, name = 'time', type = 'control',
            -- controlspec = cs.new(0.001, 16, 'exp', 0, time, "s"),
            controlspec = cs.def{ min = 0, max = 15, default = 4, quantum = 1/100/16*2, units = 'v' },
            action = function(v)
                time = 1/(2^(v - 12) * 440); update_dyn()

                crops.dirty.screen = true
            end,
        }
        patcher.add_destination_and_param{
            id = param_ids.shape, name = 'shp',
            type = 'option', options = shape_nicknames, default = shape,
            action = function(v)
                shape = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        patcher.add_destination_and_param{
            id = param_ids.ramp, name = 'rmp', type = 'control',
            controlspec = cs.def { min = -5, max = 5, default = ramp, units = 'v' },
            action = function(v)
                ramp = v/5; update_dyn()

                crops.dirty.screen = true
            end,
        }
        patcher.add_destination_and_param{
            id = param_ids.level, name = 'level', type = 'control',
            controlspec = cs.def{ min = 0, max = 10, default = level },
            action = function(v)
                level = v; update_dyn()

                crops.dirty.screen = true
            end,
        }
        patcher.add_destination_and_param{
            id = param_ids.mode, name = 'mode',
            type = 'option', options = mode_names, default = out.mode,
            action = function(v)
                out.mode = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        patcher.add_destination_and_param{
            id = param_ids.retrigger, name = 'retrigger',
            type = 'binary', 
            behavior = 'toggle', default = retrigger,
            action = function(v)
                retrigger = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        patcher.add_destination_and_param{
            id = param_ids.trigger, name = 'trigger',
            type = 'binary', 
            behavior = 'momentary', default = out.manual_gate,
            action = function(v)
                out.manual_gate = v; update_gate()

                crops.dirty.screen = true
            end,
        }
        patcher.add_destination_and_param{
            id = param_ids.patched, name = 'patched',
            type = 'binary', 
            behavior = 'toggle', default = out.patched,
            action = function(v)
                out.patched = v

                params:set(param_ids.trigger, 0)
                update_gate()

                crops.dirty.screen = true
            end,
        }

        params:add_separator('crow_cv_'..i, 'CV')

        params:add{
            type = 'number', id = param_ids.tuning_preset, name = 'tuning preset',
            min = 1, max = #eggs.tunes, default = out.preset, 
            action = function(v) 
                out.preset = v

                for _,t in ipairs(eggs.tunes) do
                    t:update_tuning()
                end 
            end,
        }
        params:add{
            type = 'number', id = param_ids.oct, name = 'oct',
            min = -5, max = 5, default = out.oct,
            action = function(v) 
                out.oct = v; update_volts_cv()

                crops.dirty.grid = true 
            end
        }
        do
            local min, max = -12, 12
            patcher.add_destination_and_param{
                type = 'control', id = param_ids.column, name = 'column',
                controlspec = cs.def{ 
                    min = min, max = max, default = out.column * eggs.volts_per_column, 
                    quantum = (1/(max - min)) * eggs.volts_per_column, units = 'v',
                },
                action = function(v) 
                    out.column = v // eggs.volts_per_column; update_volts_cv()

                    crops.dirty.grid = true 
                end
            }
        end
        patcher.add_destination_and_param{
            type = 'number', id = param_ids.row, name = 'row',
            min = -16, max = 16, default = out.row,
            action = function(v) 
                out.row = v; update_volts_cv()

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

    for k,jack in pairs(jacks) do
        crow.output[jack].receive = function(v)
            out.volts[k] = v
            crops.dirty.screen = true
        end
    end

    local fps = 40
    clock.run(function() while true do
        crow.output[jacks.cv].query()
        crow.output[jacks.gate].query()
        clock.sleep(1/fps)
    end end)

    out.Components = { norns = {} }

    out.Components.norns.page = function()
        local _e1 = Components.enc_screen.param()
        local _e2 = Components.enc_screen.param()
        local _e3 = Components.enc_screen.param()

        local _k2 = Components.key_screen.param()
        local _k3 = Components.key_screen.param()

        return function()
            _e1{ id = param_ids.time, n = 1 }
            _e2{ id = param_ids.shape, n = 2 }
            _e3{ id = param_ids.ramp, n = 3 }
            
            _k2{ id = param_ids.mode, id_hold = param_ids.retrigger, n = 2 }
            _k3{ id = param_ids.trigger, id_hold = param_ids.patched, n = 3 }

            if crops.device == 'screen' and crops.mode == 'redraw' then
                for ii,k in ipairs{ 'cv', 'gate' } do
                    screen.level(8)
                    screen.move(eggs.x[1], eggs.e[1].y + 2 + (ii + (i - 1)*2)*6)
                    screen.line_width(1)
                    screen.line_rel(out.volts[k] * eggs.w * (1/10) * 1 + 1, 0)
                    screen.stroke()
                end
            end
        end
    end

    crow_outs[i] = out
end

return crow_outs
