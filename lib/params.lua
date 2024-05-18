local p = {}

function p.add_destination_params()
    params:add_separator('midi')
    for i,midi_out in ipairs(midi_outs) do
        params:add_group('midi_outs_'..i, midi_out.name, midi_out.params_count)
        midi_out.add_params()
    end

    params:add_separator('just friends')
    params:add_group('jf_out', jf_out.name, jf_out.params_count)
    jf_out.add_params()

    params:add_separator('crow outputs')
    for i,crow_out in ipairs(crow_outs) do
        params:add_group('crow_outs_pair_'..i, crow_out.name, crow_out.params_count)
        
        crow_out.add_params()
    end
end

function p.add_keymap_params()
    params:add_separator('keymap')
    for i = 1,eggs.track_count do
        params:add_group('keymap_track_'..i, 'track '..i, 1)

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
    end

    params:add_separator('arquencer')
    for i = 1,eggs.track_count do
        local arq = eggs.arqs[i]

        params:add_group('arqueggiator_track_'..i, 'track '..i, arqueggiator.params_count)
        arq:params()
        -- arq:start()

        -- params:set_action(arq:pfix('division'), function() crops.dirty.grid = true end)
        -- params:set_action(arq:pfix('reverse'), function() crops.dirty.grid = true end)

        for _,k in ipairs({ 'division', 'reverse', 'loop' }) do
            local id = arq:pfix(k)
            local action = params:lookup_param(id).action

            params:set_action(id, function(v) 
                action(v)
                crops.dirty.grid = true 
            end)
        end
    end

    do
        params:add_separator('tuning')

        tune.add_global_params(function() 
            crops.dirty.screen = true
            crops.dirty.grid = true
        end)
        
        -- for i = 1,eggs.track_count do
        -- end

        for i,t in ipairs(eggs.tunes) do
            t:add_params('preset '..i)

            params:set_action(eggs.tunes[i]:get_param_id('tonic'), function()
                crops.dirty.grid = true 
                crops.dirty.screen = true

                for track = 1,eggs.track_count do
                    if params:get(eggs.outs[track].param_ids.tuning_preset) == i then
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
end

function p.add_modulation_params()
    --LFO params
    -- for i = 1,2 do
    --     params:add_separator('lfo '..i)
    --     mod_sources.lfos[i]:add_params('lfo_'..i)
    -- end

    --patcher params
    do
        params:add_separator('patcher')

        params:add_group('assignments', #patcher.destinations)

        local function action(dest, v)
            crops.dirty.grid = true
            crops.dirty.screen = true
            crops.dirty.arc = true
        end

        patcher.add_assignment_params(action)
    end
end

function p.add_pset_params()
    params:add_separator('pset')

    params:add{
        id = 'reset all params', type = 'binary', behavior = 'trigger',
        action = function()
            for _,p in ipairs(params.params) do if p.save then
                params:set(p.id, p.default or (p.controlspec and p.controlspec.default) or 0, true)
            end end

            -- mod_sources.lfos.reset_params()
    
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

function p.action_read(file, name, slot)
    print('pset action read', file, name, slot)

    local name = 'pset-'..string.format("%02d", slot)
    local fname = norns.state.data..name..'.data'
    local data, err = tab.load(fname)

    if err then print('ERROR pset action read: '..err) end
    if data then
        eggs.snapshots = data.snapshots or {}
        
        for i = 1,eggs.track_count do
            eggs.arqs[i].sequence = data.sequences[i] or {}

            for k,_ in pairs(data.pattern_groups[i]) do
                for ii,_ in ipairs(data.pattern_groups[i][k]) do
                    eggs.pattern_groups[i][k][ii]:import(data.pattern_groups[i][k][ii], true)
                end
            end
        end
    else
        print('pset action read: no data file found at '..fname)
    end

    params:bang()
end
function p.action_write(file, name, slot)
    print('pset action write', file, name, slot)

    local name = 'pset-'..string.format("%02d", slot)
    local fname = norns.state.data..name..'.data'

    local data = {
        sequences = {},
        snapshots = eggs.snapshots,
        pattern_groups = {},
    }

    for i = 1,eggs.track_count do
        data.sequences[i] = eggs.arqs[i].sequence

        data.pattern_groups[i] = {}
        for k,_ in pairs(eggs.pattern_groups[i]) do
            data.pattern_groups[i][k] = {}
            for ii, pattern in ipairs(eggs.pattern_groups[i][k]) do
                data.pattern_groups[i][k][ii] = pattern:export()
            end
        end
    end

    local err = tab.save(data, fname)

    if err then print('ERROR pset action write: '..err) end
end
function p.action_delete(file, name, slot)
    print('pset action delete', file, name, slot)

    --TODO: delete files
end

return p
