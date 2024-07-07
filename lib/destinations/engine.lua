local engine_dest = destination:new()

function engine_dest:new(id)
    local id_postfix = '_engine_dest_'..id

    local o = destination.new(self, id_postfix)

    o.id = id
    o.preset = id
    o.param_ids.macro = {}
    
    o.params_count = tab.count(o.param_ids) - 1 + (1 * eggs.macro_count) + 2

    o.name = 'engine dest '..id
        
    for ii = 1,eggs.macro_count do
        o.param_ids.macro[ii] = 'macro_'..ii..id_postfix
    end

    return o
end
    
function engine_dest:action_on(note, hz) eggs.noteOn(note, hz) end

function engine_dest:action_off(note) eggs.noteOff(note) end
    
function engine_dest:add_params()
    do
        local id_start = 'engine_eggs'
        local id_end = 'engine_dests_1'

        self:add_macro_params(id_start, id_end)
    end
    destination.add_params(self)
end

engine_dest.Components = { norns = {
    page = destination.Components.norns.page_macros
} }

return engine_dest
