local src = {}

--TODO: testing time !
do
    src.crow = {}

    -- local streams = {}
    -- for i = 1,2 do
    --     streams[i] = patcher.add_source('crow_'..i, 'crow '..i, 0)
    -- end
    -- -- src.crow.streams = streams

    -- local already_mapped = { false, false }
    -- function src.crow.update()
    --     local mapped = { false, false }

    --     for i = 1,2 do
    --         if #patcher.get_assignments_source('crow_'..i) > 0 then mapped[i] = true end
    --     end
        
    --     for i, map in ipairs(mapped) do 
    --         if map then 
    --             if not already_mapped[i] then
    --                 crow.input[i].mode('stream', 0.01)
    --             end
    --         else
    --             crow.input[i].mode('none')
    --         end 
    --     end
    --     if not mapped[1] and already_mapped[1] then re_enable_clock_source_crow() end

    --     already_mapped = mapped
    -- end

    -- function src.crow.add()
    --     for i = 1,2 do
    --         crow.input[i].stream = streams[i] 
    --     end

    --     src.crow.update()
    -- end

    local needs_re_enable = false
    
    -- src: https://github.com/monome/norns/blob/e8ae36069937df037e1893101e73bbdba2d8a3db/lua/core/crow.lua#L14
    local function re_enable_clock_source_crow()
        if params.lookup["clock_source"] then
            if params:string("clock_source") == "crow" then
                norns.crow.clock_enable()
            end
        end
    end

    source_actions = {}

    for input = 1,2 do
        local threshold = 0.1
        local hysteresis = 0.1
        local time = 0.01

        local function assignment_callback(mode, direction)
            if mode == 'stream' then
                crow.input[n].mode('stream', time)
            elseif mode == 'change' then
                crow.input[n].mode('change', threshold, hysteresis, direction)
            elseif mode == 'none' then
                crow.input[n].mode('none')
            end
        
            if input == 1 then
                if mode == 'none' then
                    re_enable_clock_source_crow()
                    needs_re_enable = false
                else needs_re_enable = true else
            end
        end
        
        source_actions[input] = patcher.add_source{ 
            name = 'name', 
            id = 'id', 
            default = default, 
            trigger_threshold = threshold, 
            assignment_callback = assignment_callback
        }
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
