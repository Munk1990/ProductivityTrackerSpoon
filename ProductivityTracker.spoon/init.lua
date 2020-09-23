--- === ProductivityTracker===
---
--- Tool to help track the productive time in a day. 
---
--- Builds over CountDown Spoon available on Hammerspoon repo
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/CountDown.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/CountDown.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "ProductivityTracker"
obj.version = "1.0"
obj.author = "Mayank Kumar <mayank.kr@pm.me>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.canvas = nil
obj.timer = nil
obj.minutes = nil
obj.tot_productive_min = 4 * 60
obj.tot_completed_min = 0
obj.last_logged_date = nil

function obj:init()
    self.canvas = hs.canvas.new({x=0, y=0, w=0, h=0}):show()
    self.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    self.canvas:level(hs.canvas.windowLevels.status)
    self.canvas:alpha(0.20)
    self.canvas[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = hs.drawing.color.osx_green,
        frame = {x="0%", y="0%", w="0%", h="100%"}
    }
    self.canvas[2] = {
        type = "rectangle",
        action = "fill",
        fillColor = hs.drawing.color.osx_red,
        frame = {x="0%", y="0%", w="0%", h="100%"}
    }
end

-------------------LOCAL FUNCTIONS-----------------------------

local function updateCounterVariables(mins)
    if obj.last_logged_date ~= os.date("%d%m%Y") then
        obj.last_logged_date = os.date("%d%m%Y")
        obj.tot_completed_min = 0
    end
    if mins ~= nil then
        obj.tot_completed_min = obj.tot_completed_min + mins 
    end
end


local function zeroifnil(val2conv)
    print(string.format("Zeroifnil val passed: %s", val2conv))
    if val2conv == nil then
        return 0
    else
        return val2conv
    end
end

local function canvasCleanup()
    if obj.timer then
        obj.timer:stop()
        obj.timer = nil
        obj.minutes = nil
    end
    obj.canvas[1].frame.w = "0%"
    obj.canvas[2].frame.x = "0%"
    obj.canvas[2].frame.w = "0%"
    obj.canvas:frame({x=0, y=0, w=0, h=0})
end

local function roundToDec(num, numDecimalPlaces)
  result = tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
  print("command to round %s to %s decimal places, with result = %s", num, numDecimalPlaces, result)
  return result
end


-------------------PUBLIC FUNCTIONS-----------------------------



function obj:startFor(minutes)
    if obj.timer then
        updateCounterVariables(zeroifnil(obj.minutes) * obj.loopCount)        
        canvasCleanup()
    else
        obj.minutes = minutes
        local mainScreen = hs.screen.mainScreen()
        local mainRes = mainScreen:fullFrame()
        obj.canvas:frame({x=mainRes.x, y=mainRes.y, w=mainRes.w, h=22})
        -- Set minimum visual step to 2px (i.e. Make sure every trigger updates 2px on screen at least.)
        local minimumStep = 2
        local secCount = math.ceil(60*minutes)
        obj.loopCount = 0
        if mainRes.w/secCount >= 2 then
            obj.timer = hs.timer.doEvery(1, function()
                obj.loopCount = obj.loopCount+1/secCount
                obj:setProgress(obj.loopCount, minutes)
            end)
        else
            local interval = 2/(mainRes.w/secCount)
            obj.timer = hs.timer.doEvery(interval, function()
                obj.loopCount = obj.loopCount+1/mainRes.w*2
                obj:setProgress(obj.loopCount, minutes)
            end)
        end
    end

    return self
end


function obj:pauseOrResume()
    if obj.timer then
        if obj.timer:running() then
            obj.timer:stop()
            obj.canvas[2].fillColor = hs.drawing.color.osx_yellow
            print( self:getProductivityProgress())
            hs.notify.new({
                title = self:getTimerProgress(),
                informativeText = self:getProductivityProgress()
            }):send()
        else
            obj.timer:start()
            obj.canvas[2].fillColor = hs.drawing.color.osx_red
            print( self:getProductivityProgress())
            hs.notify.new({
                title = self:getTimerProgress(),
                informativeText = self:getProductivityProgress()
            }):send()
        end
    end
end


function obj:setProgress(progress, notifystr)
    if obj.canvas:frame().h == 0 then
        -- Make the canvas actully visible
        local mainScreen = hs.screen.mainScreen()
        local mainRes = mainScreen:fullFrame()
        obj.canvas:frame({x=mainRes.x, y=mainRes.h-5, w=mainRes.w, h=5})
    end
    if progress >= 1 then
        updateCounterVariables(obj.minutes)
        canvasCleanup()       
        if notifystr then
            hs.notify.new({
                title = "CountDown of (" .. notifystr .. " mins) is up!",
                informativeText = self:getProgress()
            }):send()
        end
    else
        obj.canvas[1].frame.w = tostring(progress)
        obj.canvas[2].frame.x = tostring(progress)
        obj.canvas[2].frame.w = tostring(1-progress)
	    obj.canvas[2].fillColor = hs.drawing.color.osx_red
    end
end

function obj:getTimerProgress()
	if obj.minutes then
        return math.floor(obj.loopCount*obj.minutes) .. " of " .. obj.minutes .. " mins completed in this timer.\n\n"
    end
end

function obj:getProductivityProgress()
    updateCounterVariables()

    timer_completed_mins = zeroifnil(obj.loopCount) * zeroifnil(obj.minutes)
    tot_completed_mins = zeroifnil(obj.tot_completed_min) + timer_completed_mins
    
    bar_length = 18
    bars_completed = math.min(math.floor(tot_completed_mins / obj.tot_productive_min * bar_length), bar_length)
    bar = ''
    for i = 0 , bars_completed -1 , 1
    do 
        bar = bar .. '▓'
    end
    for i = 0, bar_length - bars_completed - 1, 1
    do
        bar = bar .. '░'
    end
    
    promptstr = string.format("Today's productivity: %s hrs of %s hrs\n[%s]"
                               , roundToDec(tot_completed_mins/60, 1)
                               , roundToDec(obj.tot_productive_min/60, 1), bar)
    if (tot_completed_mins >= obj.tot_productive_min) then
        promptstr = promptstr .. "\nYou have completed your productivity quota for today!"
    end
    return promptstr
end




function obj:getProgress()
    promptstr = self:getTimerProgress()
    if promptstr == nil then promptstr = '' end
    promptstr = promptstr .. self:getProductivityProgress()
    return promptstr
end
    

function obj:getTotalProgressBar()
    timer_completed_mins = zeroifnil(obj.loopCount) * zeroifnil(obj.minutes)
    updateCounterVariables(0)
    return bar
end

function obj:isTimer()
    return obj.timer ~= nil
end
    
    


return obj


---------------------------------


