local midi_dest = destination:new()

midi_dest.devices = {}
midi_dest.device_names = { 'engine', 'nb' }
local ENGINE, NB = 1, 2
for i = 1,#midi.vports do
    midi_dest.devices[i + 2] = midi.connect(i)
    midi_dest.device_names[i + 2] = util.trim_string_to_width(midi_dest.devices[i+2].name,80)
end

function midi_dest:new(id)
    local id_postfix = '_midi_dest_'..id

    local o = destination.new(self, id_postfix)

    o.id = id
    o.preset = id
    o.target = tab.key(midi_dest.device_names, 'engine')
    o.param_ids.target = 'target'..id_postfix
    o.param_ids.cc_value = {}
    o.param_ids.cc_index = {}
    o.param_ids.macro = {}
    
    o.params_count = tab.count(o.param_ids) - 3 + 2 + (3 * eggs.macro_count) + 1

    o.name = 'midi dest '..id
        
    o.cc_value_names = {}
            
    for ii = 1,eggs.macro_count do
        o.param_ids.cc_index[ii] = 'cc_index_'..ii..id_postfix
        o.param_ids.cc_value[ii] = 'cc_value_'..ii..id_postfix        
        o.cc_value_names[ii] = 'CC '..ii
        o.macro_ids[ii] = o.param_ids.cc_value[ii]
    end

    return o
end
    
function midi_dest:update_cc(idx)
    if self.target == ENGINE then
    elseif self.target == NB then
    else
        midi_dest.devices[self.target]:cc(self.cc_index[idx], self.cc_value[idx], 1)
    end

    crops.dirty.screen = true
end

function midi_dest:action_on(note, hz)
    if self.target == ENGINE then
        eggs.noteOn(note, hz)
    elseif self.target == NB then
        local player = params:lookup_param('voice_'..self.id):get_player()
        player:note_on(note, 1)
    else
        midi_dest.devices[self.target]:note_on(note)
    end
end

function midi_dest:action_off(note)
    if self.target == ENGINE then
        eggs.noteOff(note)
    elseif self.target == NB then
        local player = params:lookup_param('voice_'..self.id):get_player()
        player:note_off(note)
    else
        midi_dest.devices[self.target]:note_off(note)
    end
end
    
function midi_dest:add_params()
    local param_ids = self.param_ids

    params:add{
        type = 'option', id = param_ids.target, name = 'destination',
        options = midi_dest.device_names, default = self.target,
        action = function(v)
            self.target = v
            crops.dirty.screen = true
        end
    }

    params:add_separator('macros')
    do
        for ii = 1,eggs.macro_count do
            local dest_names = { self.cc_value_names[ii] }
            local dest_ids = { param_ids.cc_value[ii] }
        
            for ii,v in ipairs(params.params) do
                if v.t == params.tCONTROL then
                    table.insert(dest_names, v.name or v.id)
                    table.insert(dest_ids, v.id)
                end
            end

            param_ids.macro[ii] = 'macro_'..ii..self.id_postfix

            params:add {
                type = 'option', id = param_ids.macro[ii], name = 'macro '..ii,
                options = dest_names, action = function(v)
                    self.macro_ids[ii] = dest_ids[v]
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
                    self.cc_index[ii] = v; self:update_cc(ii)
                end
            }
            patcher.add_destination_and_param{
                type = 'control', id = param_ids.cc_value[ii], name = self.cc_value_names[ii],
                controlspec = cc_spec,
                action = function(v)
                    self.cc_value[ii] = v; self:update_cc(ii)
                end
            }
            params:hide(param_ids.cc_value[ii])
        end
    end

    destination.add_params(self)
end

midi_dest.Components = { norns = {} }

local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

midi_dest.Components.norns.page = function()
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

    return function(props)
        local param_ids = props.dest.param_ids

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
            local id = props.dest.macro_ids[i_macro]
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

return midi_dest
