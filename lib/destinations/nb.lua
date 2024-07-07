local nb_dest = destination:new()

function nb_dest:new(id)
    local id_postfix = '_nb_dest_'..id

    local o = destination.new(self, id_postfix)

    o.id = id
    o.preset = id
    o.param_ids.macro = {}
    
    o.params_count = tab.count(o.param_ids) - 1 + (1 * eggs.macro_count) + 2

    o.name = 'nb dest '..id
        
    for ii = 1,eggs.macro_count do
        o.param_ids.macro[ii] = 'macro_'..ii..id_postfix
    end

    return o
end
    
function nb_dest:action_on(note, hz)
    local player = params:lookup_param('nb_voice_'..self.id):get_player()
    player:note_on(note, 1)
end

function nb_dest:action_off(note)
    local player = params:lookup_param('nb_voice_'..self.id):get_player()
    player:note_off(note)
end
    
function nb_dest:add_params()
    do
        local id_start = 'sep_nb'
        local id_end = 'nb_dests_1'

        self:add_macro_params(id_start, id_end)
    end
    destination.add_params(self)
end

nb_dest.Components = { norns = {
    page = destination.Components.norns.page_macros
} }

return nb_dest
