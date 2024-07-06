local engine_dest = destination:new()

function engine_dest:new(id)
    local id_postfix = '_engine_dest_'..id

    local o = destination.new(self, id_postfix)

    o.id = id
    o.preset = id
    o.param_ids.macro = {}
    
    o.params_count = tab.count(o.param_ids) - 1 + (1 * eggs.macro_count) + 1

    o.name = 'engine dest '..id
        
    for ii = 1,eggs.macro_count do
        o.param_ids.macro[ii] = 'macro_'..ii..id_postfix
    end

    return o
end
    
function engine_dest:action_on(note, hz)
    if self.target == ENGINE then
        eggs.noteOn(note, hz)
    elseif self.target == NB then
        local player = params:lookup_param('voice_'..self.id):get_player()
        player:note_on(note, 1)
    else
        engine_dest.devices[self.target]:note_on(note)
    end
end

function engine_dest:action_off(note)
    if self.target == ENGINE then
        eggs.noteOff(note)
    elseif self.target == NB then
        local player = params:lookup_param('voice_'..self.id):get_player()
        player:note_off(note)
    else
        engine_dest.devices[self.target]:note_off(note)
    end
end
    
function engine_dest:add_params()
    local param_ids = self.param_ids

    params:add_separator('macros')
    do
        local id_start = 'sep_engine_params'
        local id_end = 'sep_nb'

        local adding = false
        for ii = 1,eggs.macro_count do
            for ii,p in ipairs(params.params) do
                if adding then
                    if p.id == id_end then
                        adding = false
                    elseif p.t == params.tCONTROL then
                        table.insert(dest_names, p.name or p.id)
                        table.insert(dest_ids, p.id)
                    end
                elseif p.id == id_start then
                    adding = true
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
    
    destination.add_params(self)
end

engine_dest.Components = { norns = {} }

local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

engine_dest.Components.norns.page = function()
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

return engine_dest
