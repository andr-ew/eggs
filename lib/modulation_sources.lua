local src = {}

do
    src.crow = {}

    source_actions = {}

    for input = 1,2 do
    end
    
    function src.crow.add()
        for input = 1,2 do
            crow.input[input].stream = source_actions[input].stream
            crow.input[input].change = source_actions[input].change
        end
    end
end

-- do
--     src.lfos = {}
    
--     for i = 1,2 do
--         local action = patcher.add_source('lfo '..i, 0)

--         src.lfos[i] = lfos:add{
--             min = -5,
--             max = 5,
--             depth = 0.1,
--             mode = 'free',
--             period = 0.25,
--             baseline = 'center',
--             action = action,
--         }
--     end

--     src.lfos.reset_params = function()
--         for i = 1,2 do
--             params:set('lfo_mode_lfo_'..i, 2)
--             -- params:set('lfo_max_lfo_'..i, 5)
--             -- params:set('lfo_min_lfo_'..i, -5)
--             params:set('lfo_baseline_lfo_'..i, 2)
--             params:set('lfo_lfo_'..i, 2)
--         end
--     end
-- end


return src
