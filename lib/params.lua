params:add_separator('midi')
for _,midi_out in ipairs(midi_outs) do
    midi_out.add_params()
end

params:add_separator('crow outputs')
for i,crow_out in ipairs(crow_outs) do
    params:add_group('crow_outs_pair_'..i, crow_out.name, crow_out.params_count)
    
    crow_out.add_params()
end

params:add_separator('keymap')
for i = 1,eggs.track_count do
    params:add_group('keymap_track_'..i, 'track '..i, 4)

    params:add{
        type = 'option', id = 'mode_'..i, name = 'mode',
        options = eggs.mode_names,
        action = function(v) 
            eggs.keymaps[i]:set_latch(v == eggs.LATCH)

            if v ~= eggs.ARQ then
                eggs.mute_groups[i].arq:stop()
                eggs.arqs[i].sequence = {}
            else
                eggs.mute_groups[i].manual:stop()
            end
            if v ~= eggs.LATCH then
                eggs.keymaps[i]:clear()
            end
            
            crops.dirty.grid = true 
        end
    }
    params:add{
        type = 'number', id = 'oct_'..i, name = 'oct',
        min = -5, max = 5, default = 0,
        action = function() crops.dirty.grid = true end
    }
    params:add{
        type = 'number', id = 'column_'..i, name = 'column',
        min = -16, max = 16, default = 0,
        action = function() crops.dirty.grid = true end
    }
    params:add{
        type = 'number', id = 'row_'..i, name = 'row',
        min = -16, max = 16, default = -2,
        action = function() crops.dirty.grid = true end
    }
end

params:add_separator('arquencer')
for i = 1,eggs.track_count do
    local arq = eggs.arqs[i]

    params:add_group('arqueggiator_track_'..i, 'track '..i, arqueggiator.params_count)
    arq:params()
    -- arq:start()

    params:set_action(arq:pfix('division'), function() crops.dirty.grid = true end)
    params:set_action(arq:pfix('reverse'), function() crops.dirty.grid = true end)
end

do
    params:add_separator('tuning')

    tune.add_global_params(function() 
        crops.dirty.screen = true
        crops.dirty.grid = true
    end)
    
    for i = 1,eggs.track_count do
        params:add{
            type = 'number', id = 'tuning_preset_'..i, name = 'track '..i..' preset',
            min = 1, max = presets, default = i, 
            action = function() for _,t in ipairs(eggs.tunes) do
                t:update_tuning()
            end end,
        }
    end

    for i,t in ipairs(eggs.tunes) do
        t:add_params('preset '..i)

        params:set_action(eggs.tunes[i]:get_param_id('tonic'), function()
            crops.dirty.grid = true 
            crops.dirty.screen = true

            for track = 1,eggs.track_count do
                if params:get('tuning_preset_'..track) == i then
                    local arq = eggs.arqs[track]
                    local pat = eggs.mute_groups[track].manual:get_playing_pattern()

                    if params:get('mode_'..track) == eggs.ARQ then
                        if params:get(arq:pfix('loop')) == 0 then arq:restart() end
                    elseif pat and (not pat.loop) then
                        pat:start()
                    end
                end
            end
        end)
    end
end

params:add_separator('polysub')
polysub:params()

--add pset params
do
    params:add_separator('pset')

    params:add{
        id = 'reset all params', type = 'binary', behavior = 'trigger',
        action = function()
            for _,p in ipairs(params.params) do if p.save then
                params:set(p.id, p.default or (p.controlspec and p.controlspec.default) or 0, true)
            end end
    
            params:bang()
        end
    }
    params:add{
        id = 'overwrite default pset', type = 'binary', behavior = 'trigger',
        action = function()
            params:write()
        end
    }
    params:add{
        id = 'autosave pset', type = 'option', options = { 'yes', 'no' },
        -- action = function()
        --     params:write()
        -- end
    }
end

