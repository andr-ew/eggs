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

for track = 1,2 do
    local off = track==2 and 2 or 0
    local outs = { cv = 1+off, gate = 2+off }
    
    local mode = TRANSIENT

    crow_outs[track].set_gate = function(v)
        if mode == SUSTAIN then
            crow.output[outs.gate](v > 0)
        else
            if v > 0 then crow.output[out]() end
        end
    end

    local cv = 0

    crow_outs[track].set_cv = function(v)
        cv = v
        crow.output[outs.cv].volts = v
    end
    
    crow_outs[track].set_slew = function(v)
        crow.output[outs.cv].slew = v
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

    crow_outs[track].params_count = 6

    crow_outs[track].name = 'output '..outs.cv..' + '..outs.gate

    crow_outs[track].add_params = function()
        -- params:add_separator()

        params:add{
            id = 'shape '..track, name = 'shape',
            type = 'option', options = shape_names, default = shape,
            action = function(v)
                shape = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'mode '..track, name = 'mode',
            type = 'option', options = mode_names, default = mode,
            action = function(v)
                mode = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'retrigger '..track, name = 'retrigger',
            type = 'binary', 
            behavior = 'toggle', default = retrigger,
            action = function(v)
                retrigger = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'time '..track, name = 'time', type = 'control',
            controlspec = cs.new(0.001, 16, 'exp', 0, time, "s"),
            action = function(v)
                time = v; update_dyn()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'ramp '..track, name = 'ramp', type = 'control',
            controlspec = cs.def { min = -1, max = 1, default = ramp },
            action = function(v)
                ramp = v; update_dyn()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'level '..track, name = 'level', type = 'control',
            controlspec = cs.def{ min = 0, max = 10, default = level },
            action = function(v)
                level = v; update_dyn()

                crops.dirty.screen = true
            end,
        }
    end
end

return crow_outs
