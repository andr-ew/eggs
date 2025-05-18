local p = {}

function p.add_destination_params()
    for i = 1,eggs.track_count do
        params:add{
            id = 'dest_track_'..i, name = 'track '..i, 
            type = 'option', options = eggs.dest_names[i],
            action = function(v)
                eggs.set_dest(i, v)

                crops.dirty.screen = true
                crops.dirty.grid = true
            end
        }
    end
end

function p.add_engine_selection_param()
    params:add{
        id = 'engine_eggs', name = 'engine', type = 'option', options = eggs.engines.nicknames,
        action = function(v)
            local name = eggs.engines.names[v or 1]
            local nickname = eggs.engines.nicknames[v or 1]

            if not eggs.current_engine then
                engine.name = name

                eggs.current_engine = nickname
            else
                eggs.change_engine_modal = (nickname ~= eggs.current_engine)
                crops.dirty.screen = true
            end
        end
    }
end

function p.add_engine_params()
    -- params:add_separator('sep_engine_params', eggs.current_engine)

    params:add_separator('sep_engine_params', 'engine: params')
    params:add{
        id = 'eggs_param_none', name = 'none', type = 'control', controlspec = cs.new(),
    }
    params:hide('eggs_param_none')

    eggs.engines.init[eggs.current_engine]()

    params:add_separator('sep_engine_options', 'engine: track options')
    
    for i, dest in ipairs(eggs.engine_dests) do
        params:add_group('engine_dests_'..i, 'track '..i, dest.params_count)
        dest:add_params()
    end
end

function p.add_nb_params()
    params:add_separator('sep_nb', 'nb')
    for i = 1,4 do
        nb:add_param('nb_voice_'..i, 'track '..i..' voice')
    end

    params:add{
        id = 'eggs_param_none_2', name = 'none', type = 'control', controlspec = cs.new(),
    }
    params:hide('eggs_param_none_2')

    nb:add_player_params()

    for i, dest in ipairs(eggs.nb_dests) do
        params:add_group('nb_dests_'..i, 'track '..i..' options', dest.params_count)
        dest:add_params()
    end
end

function p.add_midi_echo_params()
    local options = { 'off' }
    for _,name in ipairs(eggs.midi_device_names) do table.insert(options, name) end

    params:add_separator('sep_echo', 'midi echo')
    params:add{
        type = 'option', id = 'midi_echo_device', name = 'device',
        options = options, action = function(v)
            if eggs.midi_echo_device then 
                eggs.midi_echo_device.event = function() end 
            end

            eggs.midi_echo_device = eggs.midi_devices[v - 1]

            if eggs.midi_echo_device then 
                eggs.midi_echo_device.event = eggs.midi_echo_process
            end
        end
    }
end

function p.add_keymap_params()
    params:add_separator('keymap')
    for i = 1,eggs.track_count do
        params:add_group('keymap_track_'..i, 'track '..i, 2)

        params:add{
            type = 'option', id = 'mode_'..i, name = 'mode',
            options = eggs.mode_names,
            action = function(v) 
                eggs.keymaps[i]:set_latch(v == eggs.LATCH)

                if v ~= eggs.ARQ then
                    eggs.mute_groups[i].arq:stop()
                    eggs.arqs[i].sequence = {}
                else
                    local voicing = eggs.track_dest[i].voicing
                    eggs.mute_groups[i][voicing]:stop()
                end
                if v ~= eggs.LATCH then
                    eggs.keymaps[i]:clear()
                end
                
                crops.dirty.grid = true 
            end
        }
        local max_intervals = eggs.max_intervals
        params:add{
            type = 'number', id = 'view_'..i, name = 'view', 
            min = -max_intervals, 
            max = eggs.keymap_columns - eggs.keymap_view_width - max_intervals, 
            default = 0,
            action = function()
                crops.dirty.grid = true
            end
        }
    end

    params:add_separator('arquencer')
    for i = 1,eggs.track_count do
        local arq = eggs.arqs[i]

        params:add_group('arqueggiator_track_'..i, 'track '..i, arqueggiator.params_count)
        arq:params()
        
        for _,k in ipairs(arqueggiator.param_ids) do
            local id = arq:pfix(k)
            local p = params:lookup_param(id)
            local action = p.action
            local action_dirty = function(v) 
                action(v)
                crops.dirty.grid = true 
            end
            local action_patcher = patcher.add_destination{
                type = p.t,
                behavior = p.behavior,
                id = p.id,
                name = 'arq '..i..' '..p.name,
                action = action_dirty,
                controlspec = p.controlspec,
                default = p.default,
                min = p.min,
                max = p.max,
                options = p.options
            }

            params:set_action(id, action_patcher)
        end

        -- arq:start()

        -- params:set_action(arq:pfix('division'), function() crops.dirty.grid = true end)
        -- params:set_action(arq:pfix('reverse'), function() crops.dirty.grid = true end)
    end

    do
        params:add_separator('tuning')

        params:add_group(
            'tuning_group', 'tuning', 
            1 + eggs.track_count * (1 + eggs.channels.channel_params_count) + eggs.channels.params_count
        )
        params:add{
            type = 'number', name = 'base key', id = 'base_key', 
            min = -11, max = 11, default = tab.key(channels.modulation_names, 'A'),
            action = function(v)
                crops.dirty.screen = true 

                for i = 1,eggs.channels.count do
                    eggs.channels:update_modulation(i)
                end
            end,
            --TODO
            formatter = function(p)
                return channels.modulation_names[p:get()]
            end
        }
        for i = 1,eggs.channels.count do
            params:add_separator('track '..i)
            eggs.channels:add_channel_params(i)
        end
        eggs.channels:add_params()
    end
end

function p.add_pattern_params()
    params:add_separator('patterns')

    local action = function() 
        crops.dirty.grid = true; crops.dirty.screen = true
    end

    for i = 1,eggs.track_count do
        local count = 0
        do     
            for _,k in ipairs({ 'mono', 'poly', 'arq' }) do
                count = count + 1 + eggs.pattern_factories[i][k].params_count
            end
            for ii,_ in ipairs(eggs.pattern_factories[i].aux) do
                count = count + 1 + eggs.pattern_factories[i].aux[ii].params_count
            end
        end

        params:add_group('patterns_track_'..i, 'track '..i, count)

        for _,k in ipairs({ 'mono', 'poly', 'arq' }) do
            params:add_separator('sep_patterns_'..i..'_'..k, 'mode: '..k)
            eggs.pattern_factories[i][k]:add_params(action)
        end
        for ii,_ in ipairs(eggs.pattern_factories[i].aux) do
            params:add_separator('sep_patterns_'..i..'_aux_'..ii, 'aux pattern '..ii)
            eggs.pattern_factories[i].aux[ii]:add_params(action)
        end
    end
end

function p.add_all_track_params()
    eggs.params.add_engine_params()
    eggs.params.add_nb_params()

    params:add_separator('midi')
    for i,midi_dest in ipairs(eggs.midi_dests) do
        params:add_group('midi_dests_'..i, 'track '..i..' options', midi_dest.params_count)
        midi_dest:add_params()
    end

    params:add_separator('just friends')
    params:add_group('jf_dest', jf_dest.name, jf_dest.params_count)
    jf_dest.add_params()

    params:add_separator('crow outputs')
    for i,crow_dest in ipairs(crow_dests) do
        params:add_group('crow_dests_pair_'..i, crow_dest.name, crow_dest.params_count)
        
        crow_dest.add_params()
    end

    eggs.params.add_midi_echo_params()

    eggs.params.add_keymap_params()
    eggs.params.add_pattern_params()
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

function p.action_read(file, silent, slot)
    print('pset action read', file, silent, slot)

    -- params:bang()
    params:lookup_param('engine_eggs'):bang()

    if (not eggs.change_engine_modal) and (not silent) then
        local name = 'pset-'..string.format("%02d", slot)
        local fname = norns.state.data..name..'.data'
        local data, err = tab.load(fname)
        
        params:bang()

        if err then print('ERROR pset action read: '..err) end
        if data then
            eggs.snapshots = data.snapshots or {}

            for i = 1,eggs.track_count do
                if data.sequences then eggs.arqs[i].sequence = data.sequences[i] or {} end

                if data.keys then eggs.keymaps[i]:set(data.keys[i] or {}) end

                if data.pattern_groups then for k,_ in pairs(data.pattern_groups[i] or {}) do 
                    for ii,_ in ipairs(data.pattern_groups[i][k]) do
                        eggs.pattern_groups[i][k][ii]:import(data.pattern_groups[i][k][ii], true)
                    end
                end end
            end
        else
            print('pset action read: no data file found at '..fname)
        end
    end
end
function p.action_write(file, silent, slot)
    print('pset action write', file, silent, slot)

    local name = 'pset-'..string.format("%02d", slot)
    local fname = norns.state.data..name..'.data'

    local data = {
        sequences = {},
        snapshots = eggs.snapshots,
        pattern_groups = {},
        keys = {},
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

        data.keys[i] = eggs.keymaps[i]:get()
    end

    local err = tab.save(data, fname)

    if err then print('ERROR pset action write: '..err) end
end
function p.action_delete(file, name, slot)
    print('pset action delete', file, name, slot)

    --TODO: delete files
end

return p
