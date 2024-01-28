local crow_outs = { {}, {} }
local Crow_outs = { { norns = {} }, { norns = {} } }

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
    local volts = 0
    
    local function update_volts()
        local x = (index-1)%eggs.keymap_wrap + 1 + column 
        local y = (index-1)//eggs.keymap_wrap + 1 + row 

        volts = eggs.tunes[preset]:volts(x, y, nil, oct) 
        crow.output[outs.cv].volts = volts
    end

    crow_outs[i].voicing = 'mono'

    crow_outs[i].set_note = function(idx, gate)
        if gate > 0 then
            index = idx; update_volts()
        end

        if mode == SUSTAIN then
            crow.output[outs.gate](gate > 0)
        else
            if gate > 0 then crow.output[outs.gate]() end
        end
    end
    
    -- crow_outs[i].set_slew = function(v)
    --     crow.output[outs.cv].slew = v
    -- end

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

    crow_outs[i].params_count = 12

    crow_outs[i].name = 'output '..outs.cv..' + '..outs.gate

    local param_ids = {
        tuning_preset = 'tuning_preset_crow_outs_'..i,
        oct = 'oct_crow_outs_'..i,
        row = 'row_crow_outs_'..i,
        column = 'column_crow_outs_'..i,
    }
    crow_outs[i].param_ids = param_ids

    crow_outs[i].add_params = function()
        params:add_separator('function generator')

        params:add{
            id = 'shape '..i, name = 'shape',
            type = 'option', options = shape_names, default = shape,
            action = function(v)
                shape = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'mode '..i, name = 'mode',
            type = 'option', options = mode_names, default = mode,
            action = function(v)
                mode = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'retrigger '..i, name = 'retrigger',
            type = 'binary', 
            behavior = 'toggle', default = retrigger,
            action = function(v)
                retrigger = v; update_asl()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'time '..i, name = 'time', type = 'control',
            controlspec = cs.new(0.001, 16, 'exp', 0, time, "s"),
            action = function(v)
                time = v; update_dyn()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'ramp '..i, name = 'ramp', type = 'control',
            controlspec = cs.def { min = -1, max = 1, default = ramp },
            action = function(v)
                ramp = v; update_dyn()

                crops.dirty.screen = true
            end,
        }
        params:add{
            id = 'level '..i, name = 'level', type = 'control',
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
                oct = v; update_volts()

                crops.dirty.grid = true 
            end
        }
        params:add{
            type = 'number', id = param_ids.column, name = 'column',
            min = -16, max = 16, default = column,
            action = function(v) 
                column = v; update_volts()

                crops.dirty.grid = true 
            end
        }
        params:add{
            type = 'number', id = param_ids.row, name = 'row',
            min = -16, max = 16, default = row,
            action = function(v) 
                row = v; update_volts()

                crops.dirty.grid = true 
            end
        }
    end

    Crow_outs[i].norns.page = function()
        -- local _time = { enc = Enc.control }        

        return function()
        end
    end
end

return crow_outs, Crow_outs
