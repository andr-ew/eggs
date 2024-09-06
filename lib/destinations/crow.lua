local crow_dests = { {}, {} }

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
    
local fps = 70
-- clock.run(function() while true do
--     for i = 1,2 do
--         local off = i==2 and 2 or 0
--         local jacks = { cv = 1+off, gate = 2+off }
--         crow.output[jacks.cv].query()
--         crow.output[jacks.gate].query()
--         clock.sleep(1/fps)
--     end
-- end end)


for i = 1,2 do
    local off = i==2 and 2 or 0
    local jacks = { cv = 1+off, gate = 2+off }
    
    local dest = {}
    
    dest.mode = SUSTAIN
    dest.preset = 2 + i
    dest.oct = 0
    dest.column = 0
    dest.row = -2
    dest.index = 0
    dest.volts = { cv = 0, gate = 0 }
    dest.patched = 1

    dest.keyboard_gate = 0
    dest.manual_gate = 0

    dest.cv_callback = function(volts) end
    dest.gate_callback = function(state) end

    dest.update_notes = function() end

    local function update_volts_cv()
        local x = (dest.index-1)%eggs.keymap_wrap + 1 + dest.column 
        local y = (dest.index-1)//eggs.keymap_wrap + 1 + dest.row 

        local cv = math.max(0, eggs.tunes[dest.preset]:volts(x, y, nil, dest.oct))
        crow.output[jacks.cv].volts = cv
        dest.cv_callback(cv)
                
        crops.dirty.screen = true
    end

    local function update_gate()
        local state = ((dest.keyboard_gate & dest.patched) | dest.manual_gate) > 0

        if dest.mode == SUSTAIN then
            crow.output[jacks.gate](state)
            dest.gate_callback(state)
        elseif state then 
            crow.output[jacks.gate]() 
            dest.gate_callback()
        end
    end
    
    local slew_times = { 0.05, 0.07, 0.1, 0.2, 0.3, 0.4, 0.5, 1 }

    local slew_enable = 0
    local slew_time = slew_times[1]

    local function update_slew()
        crow.output[jacks.cv].slew = slew_enable * slew_time
    end

    dest.voicing = 'mono'

    dest.set_note = function(_, idx, gate)
        if gate > 0 then
            dest.index = idx; update_volts_cv()
        end

        dest.keyboard_gate = gate; update_gate()
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

        if dest.mode == TRANSIENT then
            crow.output[jacks.gate].action = "{"..
                "to(dyn{ l = 7 }, dyn{a = 1}, "..shp.."),"..
                    lock..
                        "to(0, dyn{r = 1}, "..shp..")"..
                    end_lock..
                "}"
        elseif dest.mode == SUSTAIN then
            crow.output[jacks.gate].action = "{"..
                "held{ to(dyn{ l = 7 }, dyn{a = 1}, "..shp..") },"..
                lock..
                    "to(0, dyn{r = 1}, "..shp..")"..
                end_lock..
            "}"
        elseif dest.mode == CYCLE then
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

    dest.add = function()
        update_asl()
        update_slew()
        update_volts_cv()
    end

    dest.name = 'output '..jacks.cv..' + '..jacks.gate
    dest.shortname = '^^'

    local param_ids = {
        tuning_preset = 'tuning_preset_crow_dests_'..i,
        oct = 'oct_crow_dests_'..i,
        row = 'row_crow_dests_'..i,
        column = 'column_crow_dests_'..i,
        shape = 'shape_crow_dests_'..i,
        mode = 'mode_crow_dests_'..i,
        retrigger = 'retrigger_crow_dests_'..i,
        time = 'time_crow_dests_'..i,
        ramp = 'ramp_crow_dests_'..i,
        level = 'level_crow_dests_'..i,
        slew_enable = 'slew_enable_crow_dests_'..i,
        slew_time = 'slew_time_crow_dests_'..i,
        trigger = 'trigger_'..i,
        patched = 'patched_'..i,
    }
    dest.param_ids = param_ids
    
    dest.params_count = 2 + tab.count(param_ids)

    dest.add_params = function(_)
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
            type = 'option', options = mode_names, default = dest.mode,
            action = function(v)
                dest.mode = v; update_asl()

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
            behavior = 'momentary', default = dest.manual_gate,
            action = function(v)
                dest.manual_gate = v; update_gate()

                crops.dirty.screen = true
            end,
        }
        patcher.add_destination_and_param{
            id = param_ids.patched, name = 'patched',
            type = 'binary', 
            behavior = 'toggle', default = dest.patched,
            action = function(v)
                dest.patched = v

                params:set(param_ids.trigger, 0)
                update_gate()

                crops.dirty.screen = true
            end,
        }

        params:add_separator('crow_cv_'..i, 'CV')

        params:add{
            type = 'number', id = param_ids.tuning_preset, name = 'tuning preset',
            min = 1, max = #eggs.tunes, default = dest.preset, 
            action = function(v) 
                dest.preset = v

                for _,t in ipairs(eggs.tunes) do
                    t:update_tuning()
                end 
            end,
        }
        params:add{
            type = 'number', id = param_ids.oct, name = 'oct',
            min = -5, max = 5, default = dest.oct,
            action = function(v) 
                dest.oct = v; update_volts_cv()

                crops.dirty.grid = true 
            end
        }
        do
            local min, max = -12, 12
            patcher.add_destination_and_param{
                type = 'control', id = param_ids.column, name = 'column',
                controlspec = cs.def{ 
                    min = min, max = max, default = dest.column * eggs.volts_per_column, 
                    quantum = (1/(max - min)) * eggs.volts_per_column, units = 'v',
                },
                action = function(v) 
                    dest.column = v // eggs.volts_per_column; update_volts_cv()

                    crops.dirty.grid = true 
                    crops.dirty.screen = true 
                end
            }
        end
        patcher.add_destination_and_param{
            type = 'number', id = param_ids.row, name = 'row',
            min = -16, max = 16, default = dest.row,
            action = function(v) 
                dest.row = v; update_volts_cv()

                crops.dirty.grid = true 
                crops.dirty.screen = true 
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
        patcher.add_destination_and_param{
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
            dest.volts[k] = v
            -- crops.dirty.screen = true
        end
    end

    dest.Components = { norns = {} }

    dest.Components.norns.page = function()
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
        end
    end

    crow_dests[i] = dest
end

return crow_dests
