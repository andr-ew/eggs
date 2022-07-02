-- eggs before brds

--global variables

g = grid.connect()

--external libs

tab = require 'tabutil'
cs = require 'controlspec'
mu = require 'musicutil'
pattern_time = require 'pattern_time'

--git submodule libs

nest = include 'lib/nest/core'
Key, Enc = include 'lib/nest/norns'
Text = include 'lib/nest/text'
Grid = include 'lib/nest/grid'

multipattern = include 'lib/nest/util/pattern-tools/multipattern'
of = include 'lib/nest/util/of'
to = include 'lib/nest/util/to'
PatternRecorder = include 'lib/nest/examples/grid/pattern_recorder'

tune, Tune = include 'lib/tune/tune' 
tune.setup { presets = 8, scales = include 'lib/tune/scales' }

--script lib files

Eggs = include 'eggs/lib/ui'

--set up global patterns

function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

pattern, mpat = {}, {}
for i = 1,5 do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

--set up nest v2 UI

local _app = {
    grid = Eggs.grid(),
    --norns = function() end,
}

nest.connect_grid(_app.grid, g, 240)
-- nest.connect_enc(_app.norns)
-- nest.connect_key(_app.norns)
-- nest.connect_screen(_app.norns, 24)

--init/cleanup

function init()
    params:read()
    params:bang()
end

function cleanup() 
    params:write()
end
