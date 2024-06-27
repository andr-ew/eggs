local midi_dest = {}

midi_dest.devices = {}
midi_dest.device_names = { 'engine', 'nb' }
local ENGINE, NB = 1, 2
for i = 1,#midi.vports do
    midi_dest.devices[i + 2] = midi.connect(i)
    midi_dest.device_names[i + 2] = util.trim_string_to_width(midi_dest.devices[i+2].name,80)
end

function midi_dest.new(i)
    local dest = {}

    local target = tab.key(midi_dest.device_names, 'engine')

    dest.preset = i
    dest.oct = 0
    dest.column = 0
    dest.row = -2
    dest.macro_ids = {}
    dest.cc_value = {}
    dest.cc_index = {}

    dest.voicing = 'poly'

    local held = {}

    local function update_cc(idx)
        if target == ENGINE then
        elseif target == NB then
        else
            midi_dest.devices[target]:cc(dest.cc_index[idx], dest.cc_value[idx], 1)
        end

        crops.dirty.screen = true
    end

    local function get_note_hz(idx)
        local x = (idx-1)%eggs.keymap_wrap + 1 + dest.column 
        local y = (idx-1)//eggs.keymap_wrap + 1 + dest.row 
        local note = eggs.tunes[dest.preset]:midi(x, y, nil, dest.oct) + 33
        local hz = eggs.tunes[dest.preset]:hz(x, y, nil, dest.oct) * 55

        return note, hz
    end
    local function note_on(note, hz)
        if target == ENGINE then
            eggs.noteOn(note, hz)
        elseif target == NB then
            local player = params:lookup_param('voice_'..i):get_player()
            player:note_on(note, 1)
        else
            midi_dest.devices[target]:note_on(note)
        end
    end
    local function note_off(note)
        if target == ENGINE then
            eggs.noteOff(note)
        elseif target == NB then
            local player = params:lookup_param('voice_'..i):get_player()
            player:note_off(note)
        else
            midi_dest.devices[target]:note_off(note)
        end
    end

    dest.note_on = function(idx)
        local note, hz = get_note_hz(idx)
        note_on(note, hz)

        table.insert(held, { idx = idx, note = note })
    end
    dest.note_off = function(idx) 
        local note = get_note_hz(idx)
        note_off(note)

        for i,h in ipairs(held) do if h.note==note then
            table.remove(held, i)
            break
        end end
    end

    local function update_notes()
        for i,h in ipairs(held) do
            note_off(h.note)

            local new_note, new_hz = get_note_hz(h.idx)
            h.note = new_note
            note_on(new_note, new_hz)
        end
    end

    local param_ids = {
        target = 'target_midi_dest_'..i,
        tuning_preset = 'tuning_preset_midi_dest_'..i,
        oct = 'oct_midi_dest_'..i,
        row = 'row_midi_dest_'..i,
        column = 'column_midi_dest_'..i,
        cc_value = {},
        cc_index = {},
        macro = {},
    }
    dest.param_ids = param_ids
    
    dest.params_count = tab.count(param_ids) - 3 + 2 + (3 * eggs.macro_count) + 1

    dest.name = 'midi dest '..i
        
    local cc_value_names = {}
            
    for ii = 1,eggs.macro_count do
        param_ids.cc_index[ii] = 'cc_index_'..ii..'_midi_dest_'..i
        param_ids.cc_value[ii] = 'cc_value_'..ii..'_midi_dest_'..i
        cc_value_names[ii] = 'CC '..ii
        dest.macro_ids[ii] = param_ids.cc_value[ii]
    end
        

    dest.add_params = function()
        params:add{
            type = 'option', id = param_ids.target, name = 'destination',
            options = midi_dest.device_names, default = target,
            action = function(v)
                target = v
                crops.dirty.screen = true
            end
        }

        params:add_separator('macros')
        do
            for ii = 1,eggs.macro_count do
                local dest_names = { cc_value_names[ii] }
                local dest_ids = { param_ids.cc_value[ii] }
            
                for ii,v in ipairs(params.params) do
                    if v.t == params.tCONTROL then
                        table.insert(dest_names, v.name or v.id)
                        table.insert(dest_ids, v.id)
                    end
                end

                param_ids.macro[ii] = 'macro_'..ii..'_midi_dest_'..i

                params:add {
                    type = 'option', id = param_ids.macro[ii], name = 'macro '..ii,
                    options = dest_names, action = function(v)
                        dest.macro_ids[ii] = dest_ids[v]
                        crops.dirty.screen = true
                    end
                }
            end
        end
        
        params:add_separator('midi CCs')
        do
            local cc_spec = cs.def{ default = 0, min = 0, max = 127, step = 1 }

            for ii = 1,eggs.macro_count do
                params:add{
                    type = 'number', id = param_ids.cc_index[ii], name = 'CC address '..ii,
                    min = 0, max = 127, default = ii,
                    action = function(v)
                        dest.cc_index[ii] = v; update_cc(ii)
                    end
                }
                patcher.add_destination_and_param{
                    type = 'control', id = param_ids.cc_value[ii], name = cc_value_names[ii],
                    controlspec = cc_spec,
                    action = function(v)
                        dest.cc_value[ii] = v; update_cc(ii)
                    end
                }
                params:hide(param_ids.cc_value[ii])
            end
        end

        params:add_separator('keymap')

        params:add{
            type = 'number', id = param_ids.tuning_preset, name = 'tuning preset',
            min = 1, max = #eggs.tunes, default = dest.preset, 
            action = function(v) 
                dest.preset = v; update_notes()

                for _,t in ipairs(eggs.tunes) do
                    t:update_tuning()
                end 
            end,
        }
        params:add{
            type = 'number', id = param_ids.oct, name = 'oct',
            min = -5, max = 5, default = dest.oct,
            action = function(v) 
                dest.oct = v; update_notes()

                crops.dirty.grid = true 
            end
        }
        do
            local min, max = -12, 12
            params:add{
                type = 'control', id = param_ids.column, name = 'column',
                controlspec = cs.def{ 
                    min = min, max = max, default = dest.column * eggs.volts_per_column, 
                    quantum = (1/(max - min)) * eggs.volts_per_column, units = 'v',
                },
                action = function(v) 
                    local last = dest.column
                    dest.column = v // eggs.volts_per_column
            
                    if last ~= dest.column then update_notes() end

                    crops.dirty.grid = true 
                    crops.dirty.screen = true 
                end
            }
        end
        params:add{
            type = 'number', id = param_ids.row, name = 'row',
            min = -16, max = 16, default = dest.row,
            action = function(v) 
                local last = dest.row
                dest.row = v
        
                if last ~= dest.row then update_notes() end

                crops.dirty.grid = true 
                crops.dirty.screen = true 
            end
        }
    end

    dest.Components = { norns = {} }

    local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

    dest.Components.norns.page = function()
        local _target = Components.enc_screen.param()

        local dots = {}
        for i = 1,eggs.macro_page_count do
            table.insert(dots, ".")
        end

        local macro_focus = 1
        local _macro_focus = {
            key = Key.integer(),
            screen = Screen.list(),
        }

        local _macros = {}
        for ii = 1,2 do
            _macros[ii] = Components.enc_screen.param()
        end

        return function()
            _target{ id = param_ids.target, n = 1, is_dest = false }

            _macro_focus.key{
                n_next = 3, n_prev = 2, min = 1, max = eggs.macro_page_count,
                state = crops.of_variable(macro_focus, function(v) 
                    macro_focus = v; crops.dirty.screen = true
                end)
            }
            _macro_focus.screen{
                x = k[2].x, y = k[2].y, text = dots, focus = macro_focus,
                font_size = 16, margin = 3,
            }

            for ii = 1,2 do
                local i_macro = (macro_focus - 1)*2 + ii
                local id = dest.macro_ids[i_macro]
                local is_cc = id == param_ids.cc_value[i_macro]

                _macros[ii]{
                    id = id, n = 1 + ii, is_dest = is_cc,
                }

                if not is_cc then
                    crops.dirty.screen = true --hahahah well there's not really a better solution
                end
            end
        end
    end

    return dest
end

return midi_dest
