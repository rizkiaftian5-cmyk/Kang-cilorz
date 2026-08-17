-- Mountain Auto Play - Roblox Studio LocalScript
-- Features: Pathfinding, 23 checkpoints, 10s checkpoint delay,
-- Repeat, Pause/Resume, Stop, anti-stuck, repath, Next/Previous, TP Current.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer

local CHECKPOINTS = {
 {name="awal",position=Vector3.new(-3416,1818,-1918)},
 {name="2",position=Vector3.new(-1,7,88)},
 {name="3",position=Vector3.new(-132,99,-1372)},
 {name="4",position=Vector3.new(512,114,-1829)},
 {name="5",position=Vector3.new(1149,18,-1812)},
 {name="6",position=Vector3.new(2167,16,-2175)},
 {name="8",position=Vector3.new(2209,351,-2468)},
 {name="9",position=Vector3.new(1967,385,-3491)},
 {name="10",position=Vector3.new(1144,457,-3772)},
 {name="11",position=Vector3.new(424,409,-3563)},
 {name="12",position=Vector3.new(-182,429,-3762)},
 {name="13",position=Vector3.new(-882,434,-4189)},
 {name="14",position=Vector3.new(-1484,678,-3849)},
 {name="15",position=Vector3.new(-1678,1110,-3889)},
 {name="16",position=Vector3.new(-2464,930,-4505)},
 {name="17",position=Vector3.new(-3079,930,-5134)},
 {name="18",position=Vector3.new(-3861,963,-5664)},
 {name="19",position=Vector3.new(-4120,998,-4842)},
 {name="20",position=Vector3.new(-4236,1239,-3873)},
 {name="21",position=Vector3.new(-3764,1374,-3347)},
 {name="22",position=Vector3.new(-3751,1674,-3103)},
 {name="23",position=Vector3.new(-3723,1725,-2438)},
}

local CONFIG = {
 Repeat=false, CheckpointDelay=10, AgentRadius=2, AgentHeight=5,
 AgentCanJump=true, AgentCanClimb=true, WaypointSpacing=3,
 ReachDistance=5, RepathDelay=0.2, MaxRetries=5,
 MinMoveTimeout=5, MaxMoveTimeout=20, StuckTimeout=2.5,
}

local Character,Humanoid,RootPart
local running,paused=false,false
local currentIndex=1
local runId=0

local function setupCharacter(c)
 Character=c
 Humanoid=c:WaitForChild("Humanoid")
 RootPart=c:WaitForChild("HumanoidRootPart")
end
if Player.Character then setupCharacter(Player.Character) end
Player.CharacterAdded:Connect(setupCharacter)

local function getRoot()
 if not Character or not Character.Parent or not Humanoid or Humanoid.Health<=0 then return nil end
 if not RootPart or not RootPart.Parent then RootPart=Character:FindFirstChild("HumanoidRootPart") end
 return RootPart
end


-- =========================================================
-- KAYA NGAMBEKAN | EXTRA CONTROLLERS
-- =========================================================
local EXTRA = {
    FishingEnabled = false,
    AutoCollectEvent = false,
    Turu = false, -- Anti-AFK
    InfinityJump = false,
    MovementSpeed = 16,
    FishingDelay = 7.5,
    EventInterval = 1.0,
    Transparency = 0.08,
}

local fishingCountdown = 0
local eventBusy = false
local antiAfkConnection

-- Anti-AFK "TURU": uses Roblox's idle event and VirtualUser when available.
local function setTuru(enabled)
    EXTRA.Turu = enabled
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection=nil
    end
    if enabled then
        local VirtualUser=game:GetService("VirtualUser")
        antiAfkConnection=Player.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end
end

local function applyMovementSpeed()
    if Humanoid then
        Humanoid.WalkSpeed=EXTRA.MovementSpeed
    end
end

-- Fishing implementation based on the supplied Mount Lonely source.
local function getFishingSystem()
    local rs=game:GetService("ReplicatedStorage")
    return rs:FindFirstChild("FishingSystem")
end

local function findRod()
    local backpack=Player:FindFirstChildOfClass("Backpack")
    local char=Character
    if not backpack or not Humanoid then return nil end
    local tool=char and char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    for _,item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and string.find(string.lower(item.Name),"rod") then
            pcall(function() Humanoid:EquipTool(item) end)
            task.wait(0.25)
            return item
        end
    end
    return nil
end

local function fishOnce()
    local system=getFishingSystem()
    if not system then return false,"FishingSystem tidak ditemukan" end
    local cast=system:FindFirstChild("CastReplication")
    local cleanup=system:FindFirstChild("CleanupCast")
    local giver=system:FindFirstChild("FishGiver")
    if not cast or not cleanup or not giver then
        return false,"Remote fishing tidak lengkap"
    end
    local root=getRoot()
    local humanoid=Humanoid
    if not root or not humanoid then return false,"Character belum siap" end
    local rod=findRod()
    if not rod then return false,"Fishing rod tidak ditemukan" end

    local hook=root.Position+(root.CFrame.LookVector*12)
    pcall(function()
        cast:FireServer(hook,Vector3.new(3.9,5,-24.6),rod.Name,92.2)
    end)

    local started=os.clock()
    while EXTRA.FishingEnabled and os.clock()-started<EXTRA.FishingDelay do
        fishingCountdown=math.max(0,EXTRA.FishingDelay-(os.clock()-started))
        task.wait(0.1)
        if not Character or not Character.Parent then break end
    end
    fishingCountdown=0
    if not EXTRA.FishingEnabled then return false,"OFF" end

    pcall(function() cleanup:FireServer() end)
    local hookPosition=hook-Vector3.new(0,4,0)
    pcall(function()
        giver:FireServer({[1]={hookPosition=hookPosition,power=0}})
    end)
    return true,"Fish cycle selesai"
end

task.spawn(function()
    while task.wait(0.2) do
        if EXTRA.FishingEnabled then
            local ok,msg=fishOnce()
            if not ok and msg~="OFF" then
                setStatus("Fishing: "..msg)
                task.wait(1)
            end
        end
    end
end)

-- Event collector based on the supplied source's BenderaHitbox pattern.
local function collectEventOnce()
    if eventBusy then return end
    eventBusy=true
    local ws=game:GetService("Workspace")
    local root=getRoot()
    if root then
        for _,obj in ipairs(ws:GetDescendants()) do
            if not EXTRA.AutoCollectEvent then break end
            if obj.Name=="BenderaHitbox" then
                local prompt=obj:FindFirstChildWhichIsA("ProximityPrompt",true)
                if prompt and typeof(fireproximityprompt)=="function" then
                    pcall(function() fireproximityprompt(prompt) end)
                end
                local click=obj:FindFirstChildWhichIsA("ClickDetector",true)
                if click and typeof(fireclickdetector)=="function" then
                    pcall(function() fireclickdetector(click) end)
                end
                local part=(obj:IsA("BasePart") and obj)
                    or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true)))
                if part and typeof(firetouchinterest)=="function" then
                    pcall(function()
                        firetouchinterest(root,part,0)
                        firetouchinterest(root,part,1)
                    end)
                end
            end
        end
    end
    eventBusy=false
end

task.spawn(function()
    while task.wait(EXTRA.EventInterval) do
        if EXTRA.AutoCollectEvent then collectEventOnce() end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Humanoid then applyMovementSpeed() end
    end
end)

local Gui=Instance.new("ScreenGui")
Gui.Name="MountainWaypointAutoPlay"
Gui.ResetOnSpawn=false
Gui.Parent=Player:WaitForChild("PlayerGui")

local Main=Instance.new("Frame")
Main.Size=UDim2.fromOffset(680,390)
Main.Position=UDim2.new(0.5,-340,0.5,-195)
Main.BackgroundColor3=Color3.fromRGB(24,24,30)
Main.BorderSizePixel=0
Main.Parent=Gui
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,12)

local Stroke=Instance.new("UIStroke",Main)
Stroke.Color=Color3.fromRGB(90,90,105)
Stroke.Thickness=1

local TitleBar=Instance.new("Frame",Main)
TitleBar.Size=UDim2.new(1,0,0,38)
TitleBar.BackgroundTransparency=1

local Title=Instance.new("TextLabel",TitleBar)
Title.Size=UDim2.new(1,-90,1,0)
Title.Position=UDim2.fromOffset(10,0)
Title.BackgroundTransparency=1
Title.Text="⛰  MOUNTAIN AUTO PLAY"
Title.TextColor3=Color3.fromRGB(255,255,255)
Title.Font=Enum.Font.GothamBold
Title.TextSize=18
Title.TextXAlignment=Enum.TextXAlignment.Left
local MinimizeButton=Instance.new("TextButton",TitleBar)
MinimizeButton.Size=UDim2.fromOffset(34,28)
MinimizeButton.Position=UDim2.new(1,-44,0.5,-14)
MinimizeButton.BackgroundColor3=Color3.fromRGB(45,45,55)
MinimizeButton.BorderSizePixel=0
MinimizeButton.Text="—"
MinimizeButton.TextColor3=Color3.fromRGB(255,255,255)
MinimizeButton.Font=Enum.Font.GothamBold
MinimizeButton.TextSize=18
Instance.new("UICorner",MinimizeButton).CornerRadius=UDim.new(1,0)

local RestoreButton=Instance.new("TextButton",Gui)
RestoreButton.Size=UDim2.fromOffset(52,52)
RestoreButton.Position=UDim2.new(1,-70,1,-75)
RestoreButton.BackgroundColor3=Color3.fromRGB(35,110,155)
RestoreButton.BorderSizePixel=0
RestoreButton.Text="⛰"
RestoreButton.TextColor3=Color3.fromRGB(255,255,255)
RestoreButton.Font=Enum.Font.GothamBold
RestoreButton.TextSize=24
RestoreButton.Visible=false
Instance.new("UICorner",RestoreButton).CornerRadius=UDim.new(1,0)
local restoreStroke=Instance.new("UIStroke",RestoreButton)
restoreStroke.Color=Color3.fromRGB(130,220,255)
restoreStroke.Thickness=2

MinimizeButton.MouseButton1Click:Connect(function()
    Main.Visible=false
    RestoreButton.Visible=true
end)
RestoreButton.MouseButton1Click:Connect(function()
    Main.Visible=true
    RestoreButton.Visible=false
end)

local dragging=false
local dragStart,startPosition
TitleBar.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  dragging=true;dragStart=input.Position;startPosition=Main.Position
 end
end)
TitleBar.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
UserInputService.InputChanged:Connect(function(input)
 if not dragging then return end
 if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
 local d=input.Position-dragStart
 Main.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+d.X,startPosition.Y.Scale,startPosition.Y.Offset+d.Y)
end)

local Status=Instance.new("TextLabel",Main)
Status.Size=UDim2.new(1,-330,0,22)
Status.Position=UDim2.fromOffset(10,39)
Status.BackgroundTransparency=1
Status.Text="Status: Ready"
Status.TextColor3=Color3.fromRGB(180,180,190)
Status.Font=Enum.Font.Gotham
Status.TextSize=13
Status.TextXAlignment=Enum.TextXAlignment.Left
local function setStatus(t) Status.Text="Status: "..t end

local Current=Instance.new("TextLabel",Main)
Current.Size=UDim2.fromOffset(300,22)
Current.Position=UDim2.fromOffset(330,39)
Current.BackgroundTransparency=1
Current.TextColor3=Color3.fromRGB(120,210,255)
Current.Font=Enum.Font.GothamBold
Current.TextSize=13
Current.TextXAlignment=Enum.TextXAlignment.Left
local function updateCurrent()
 local c=CHECKPOINTS[currentIndex]
 Current.Text=c and string.format("Checkpoint: %d/%d [%s]",currentIndex,#CHECKPOINTS,c.name) or "Checkpoint: -"
end
Current.Parent=Main


local function makeSlider(label,x,y,w,minValue,maxValue,initial,step,onChange)
    local holder=Instance.new("Frame",Main)
    holder.Size=UDim2.fromOffset(w,48)
    holder.Position=UDim2.fromOffset(x,y)
    holder.BackgroundTransparency=1

    local text=Instance.new("TextLabel",holder)
    text.Size=UDim2.new(1,0,0,18)
    text.BackgroundTransparency=1
    text.Text=label..": "..tostring(initial)
    text.TextColor3=Color3.fromRGB(225,225,235)
    text.Font=Enum.Font.Gotham
    text.TextSize=11
    text.TextXAlignment=Enum.TextXAlignment.Left

    local bar=Instance.new("Frame",holder)
    bar.Size=UDim2.new(1,0,0,8)
    bar.Position=UDim2.fromOffset(0,24)
    bar.BackgroundColor3=Color3.fromRGB(55,55,68)
    bar.BorderSizePixel=0
    Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)

    local fill=Instance.new("Frame",bar)
    fill.Size=UDim2.new((initial-minValue)/(maxValue-minValue),0,1,0)
    fill.BackgroundColor3=Color3.fromRGB(80,170,230)
    fill.BorderSizePixel=0
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

    local knob=Instance.new("TextButton",bar)
    knob.Size=UDim2.fromOffset(18,18)
    knob.AnchorPoint=Vector2.new(0.5,0.5)
    knob.Position=UDim2.new((initial-minValue)/(maxValue-minValue),0,0.5,0)
    knob.BackgroundColor3=Color3.fromRGB(235,235,245)
    knob.BorderSizePixel=0
    knob.Text=""
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    local draggingSlider=false
    local function setValueFromX(px)
        local ratio=math.clamp((px-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        local raw=minValue+(maxValue-minValue)*ratio
        local value=math.floor(raw/step+0.5)*step
        value=math.clamp(value,minValue,maxValue)
        local r=(value-minValue)/(maxValue-minValue)
        fill.Size=UDim2.new(r,0,1,0)
        knob.Position=UDim2.new(r,0,0.5,0)
        text.Text=label..": "..tostring(value)
        if onChange then onChange(value) end
    end
    knob.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            draggingSlider=true
        end
    end)
    knob.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            draggingSlider=false
        end
    end)
    bar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            draggingSlider=true
            setValueFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            setValueFromX(input.Position.X)
        end
    end)
    return holder
end

local function makeButton(text,x,y,w,fn)
 local b=Instance.new("TextButton",Main)
 b.Size=UDim2.fromOffset(w,36);b.Position=UDim2.fromOffset(x,y)
 b.BackgroundColor3=Color3.fromRGB(45,45,55);b.BorderSizePixel=0
 b.Text=text;b.TextColor3=Color3.fromRGB(255,255,255)
 b.Font=Enum.Font.GothamBold;b.TextSize=12
 Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
 b.MouseButton1Click:Connect(fn)
 return b
end

local List=Instance.new("ScrollingFrame",Main)
List.Size=UDim2.fromOffset(300,220)
List.Position=UDim2.fromOffset(10,68)
List.BackgroundColor3=Color3.fromRGB(17,17,22)
List.BorderSizePixel=0;List.ScrollBarThickness=4
Instance.new("UICorner",List).CornerRadius=UDim.new(0,8)
local Layout=Instance.new("UIListLayout",List)
Layout.Padding=UDim.new(0,4);Layout.SortOrder=Enum.SortOrder.LayoutOrder
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
 List.CanvasSize=UDim2.fromOffset(0,Layout.AbsoluteContentSize.Y+8)
end)

local function refreshList()
 for _,child in ipairs(List:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
 for index,c in ipairs(CHECKPOINTS) do
  local row=Instance.new("Frame",List)
  row.Size=UDim2.new(1,-8,0,28);row.BackgroundColor3=Color3.fromRGB(32,32,40)
  row.BorderSizePixel=0;row.LayoutOrder=index
  Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)
  local label=Instance.new("TextLabel",row)
  label.Size=UDim2.new(1,-65,1,0);label.Position=UDim2.fromOffset(8,0)
  label.BackgroundTransparency=1;label.Text=string.format("%02d  %s",index,c.name)
  label.TextColor3=Color3.fromRGB(235,235,240);label.Font=Enum.Font.Gotham
  label.TextSize=12;label.TextXAlignment=Enum.TextXAlignment.Left
  local tp=Instance.new("TextButton",row)
  tp.Size=UDim2.fromOffset(38,22);tp.Position=UDim2.new(1,-45,0.5,-11)
  tp.Text="TP";tp.Font=Enum.Font.GothamBold;tp.TextSize=10
  tp.TextColor3=Color3.fromRGB(255,255,255);tp.BackgroundColor3=Color3.fromRGB(55,95,165)
  Instance.new("UICorner",tp).CornerRadius=UDim.new(0,5)
  tp.MouseButton1Click:Connect(function()
   local root=getRoot()
   if not root then setStatus("Character belum siap");return end
   root.CFrame=CFrame.new(c.position+Vector3.new(0,3,0))
   currentIndex=index;updateCurrent();setStatus("TP: "..c.name)
  end)
 end
end
refreshList()

local function calculatePath(destination)
 local root=getRoot()
 if not root then return nil end
 local path=PathfindingService:CreatePath({
  AgentRadius=CONFIG.AgentRadius,AgentHeight=CONFIG.AgentHeight,
  AgentCanJump=CONFIG.AgentCanJump,AgentCanClimb=CONFIG.AgentCanClimb,
  WaypointSpacing=CONFIG.WaypointSpacing,
 })
 local ok=pcall(function() path:ComputeAsync(root.Position,destination) end)
 if not ok or path.Status~=Enum.PathStatus.Success then return nil end
 return path
end

local function checkpointDelay(c,token)
 local remaining=CONFIG.CheckpointDelay
 while remaining>0 and running and runId==token do
  while paused and running and runId==token do
   setStatus("Paused di "..c.name);task.wait(0.1)
  end
  if not running or runId~=token then return false end
  setStatus(string.format("%s - lanjut %ds",c.name,math.ceil(remaining)))
  task.wait(1);remaining-=1
 end
 return true
end

local function moveToCheckpoint(c,token)
 local retry=0
 while running and runId==token do
  while paused and running and runId==token do
   if Humanoid then Humanoid:Move(Vector3.zero) end
   task.wait(0.1)
  end
  if not running or runId~=token then return false end
  local root=getRoot()
  if not root then task.wait(0.5);continue end
  if (root.Position-c.position).Magnitude<=CONFIG.ReachDistance then return true end

  local path=calculatePath(c.position)
  if not path then
   retry+=1;setStatus(string.format("Path gagal %d/%d: %s",retry,CONFIG.MaxRetries,c.name))
   if retry>=CONFIG.MaxRetries then return false end
   task.wait(1);continue
  end
  retry=0
  local waypoints=path:GetWaypoints()
  if #waypoints==0 then retry+=1;task.wait(0.5);continue end

  local blocked=false;local blockedIndex=math.huge
  local blockedConnection=path.Blocked:Connect(function(index) blocked=true;blockedIndex=index end)
  local pathFailed=false

  for waypointIndex,waypoint in ipairs(waypoints) do
   if not running or runId~=token then pathFailed=true;break end
   while paused and running and runId==token do
    if Humanoid then Humanoid:Move(Vector3.zero) end
    task.wait(0.1)
   end
   if not running or runId~=token then pathFailed=true;break end
   if blocked and blockedIndex<=waypointIndex then pathFailed=true;break end

   local currentRoot=getRoot()
   if not currentRoot then pathFailed=true;break end
   if waypoint.Action==Enum.PathWaypointAction.Jump then Humanoid.Jump=true end
   Humanoid:MoveTo(waypoint.Position)

   local reached=false
   local connection=Humanoid.MoveToFinished:Connect(function(success) if success then reached=true end end)
   local distance=(currentRoot.Position-waypoint.Position).Magnitude
   local speed=math.max(Humanoid.WalkSpeed,8)
   local timeout=math.clamp((distance/speed)*2.5,CONFIG.MinMoveTimeout,CONFIG.MaxMoveTimeout)
   local started=os.clock();local lastPosition=currentRoot.Position;local lastMove=os.clock()

   while not reached and not pathFailed and running and runId==token do
    if paused then break end
    if os.clock()-started>=timeout then pathFailed=true;break end
    if blocked and blockedIndex<=waypointIndex then pathFailed=true;break end
    local r=getRoot()
    if not r then pathFailed=true;break end
    if (r.Position-waypoint.Position).Magnitude<=CONFIG.ReachDistance then reached=true;break end
    local movement=(r.Position-lastPosition).Magnitude
    if movement>0.5 then lastPosition=r.Position;lastMove=os.clock()
    elseif os.clock()-lastMove>=CONFIG.StuckTimeout then pathFailed=true;break end
    task.wait(0.1)
   end
   connection:Disconnect()
   if paused then break end
   if not reached then pathFailed=true;break end
  end

  blockedConnection:Disconnect()
  if not pathFailed then
   local finalRoot=getRoot()
   if finalRoot and (finalRoot.Position-c.position).Magnitude<=CONFIG.ReachDistance then return true end
  end

  retry+=1;setStatus(string.format("Repath %d/%d: %s",retry,CONFIG.MaxRetries,c.name))
  if retry>=CONFIG.MaxRetries then return false end
  task.wait(CONFIG.RepathDelay)
 end
 return false
end

local function stop()
 running=false;paused=false;runId+=1
 if Humanoid then Humanoid:Move(Vector3.zero) end
 setStatus("Stopped")
end

local function start()
 if running then setStatus("Sudah berjalan");return end
 running=true;paused=false;runId+=1
 local token=runId
 task.spawn(function()
  while running and runId==token do
   if currentIndex>#CHECKPOINTS then
    if CONFIG.Repeat then
     currentIndex=1;updateCurrent();setStatus("Repeat: kembali ke awal");task.wait(0.5)
    else
     running=false;setStatus("Semua checkpoint selesai");break
    end
   end
   local c=CHECKPOINTS[currentIndex]
   updateCurrent();setStatus("Menuju "..c.name)
   local reached=moveToCheckpoint(c,token)
   if not running or runId~=token then break end
   if reached then
    setStatus("Sampai "..c.name)
    if not checkpointDelay(c,token) then break end
    currentIndex+=1
   else
    setStatus("Gagal: "..c.name)
    if not CONFIG.Repeat then stop();break end
    task.wait(1)
   end
  end
 end)
end

local repeatButton
makeButton("▶ START",330,72,105,start)
makeButton("Ⅱ PAUSE",445,72,105,function()
 if running then paused=true;if Humanoid then Humanoid:Move(Vector3.zero) end;setStatus("Paused") end
end)
makeButton("▶ RESUME",560,72,105,function()
 if running then paused=false;setStatus("Resumed") end
end)

makeButton("■ STOP",330,116,105,stop)
repeatButton=makeButton("↻ REPEAT: OFF",445,116,220,function()
 CONFIG.Repeat=not CONFIG.Repeat
 repeatButton.Text=CONFIG.Repeat and "↻ REPEAT: ON" or "↻ REPEAT: OFF"
 repeatButton.BackgroundColor3=CONFIG.Repeat and Color3.fromRGB(45,130,80) or Color3.fromRGB(45,45,55)
end)

makeButton("⏮ AWAL",330,160,105,function()
 currentIndex=1;updateCurrent();if not running then start() end
end)
makeButton("‹ PREV",445,160,105,function()
 if currentIndex>1 then currentIndex-=1;updateCurrent();setStatus("Previous: "..CHECKPOINTS[currentIndex].name) end
end)
makeButton("NEXT ›",560,160,105,function()
 if currentIndex<#CHECKPOINTS then currentIndex+=1;updateCurrent();setStatus("Next: "..CHECKPOINTS[currentIndex].name) end
end)

makeButton("⌖ TP CURRENT",330,204,220,function()
 local c=CHECKPOINTS[currentIndex];local root=getRoot()
 if root and c then root.CFrame=CFrame.new(c.position+Vector3.new(0,3,0));updateCurrent();setStatus("TP: "..c.name) end
end)
makeButton("— MINIMIZE",560,204,105,function()
 Main.Visible=false
 RestoreButton.Visible=true
end)

local TuruButton=makeButton("☾ TURU: OFF",330,250,105,function()
 setTuru(not EXTRA.Turu)
 TuruButton.Text=EXTRA.Turu and "☾ TURU: ON" or "☾ TURU: OFF"
 TuruButton.BackgroundColor3=EXTRA.Turu and Color3.fromRGB(90,80,145) or Color3.fromRGB(45,45,55)
 setStatus(EXTRA.Turu and "TURU aktif" or "TURU nonaktif")
end)

local JumpButton=makeButton("∞ JUMP: OFF",445,250,105,function()
 EXTRA.InfinityJump=not EXTRA.InfinityJump
 JumpButton.Text=EXTRA.InfinityJump and "∞ JUMP: ON" or "∞ JUMP: OFF"
 JumpButton.BackgroundColor3=EXTRA.InfinityJump and Color3.fromRGB(120,70,170) or Color3.fromRGB(45,45,55)
end)

local FishButton=makeButton("🎣 FISH: OFF",560,250,105,function()
 EXTRA.FishingEnabled=not EXTRA.FishingEnabled
 FishButton.Text=EXTRA.FishingEnabled and "🎣 FISH: ON" or "🎣 FISH: OFF"
 FishButton.BackgroundColor3=EXTRA.FishingEnabled and Color3.fromRGB(45,130,180) or Color3.fromRGB(45,45,55)
 setStatus(EXTRA.FishingEnabled and "Auto Fishing ON" or "Auto Fishing OFF")
end)

local EventButton=makeButton("🎁 EVENT: OFF",330,294,105,function()
 EXTRA.AutoCollectEvent=not EXTRA.AutoCollectEvent
 EventButton.Text=EXTRA.AutoCollectEvent and "🎁 EVENT: ON" or "🎁 EVENT: OFF"
 EventButton.BackgroundColor3=EXTRA.AutoCollectEvent and Color3.fromRGB(150,85,45) or Color3.fromRGB(45,45,55)
 setStatus(EXTRA.AutoCollectEvent and "Auto Event ON" or "Auto Event OFF")
end)

makeButton("💰 SELL ALL",445,294,105,function()
 local rs=game:GetService("ReplicatedStorage")
 local system=rs:FindFirstChild("FishingSystem")
 local remote=system and system:FindFirstChild("InventoryEvents")
 local sell=remote and remote:FindFirstChild("Inventory_SellAll")
 if sell then
  pcall(function() sell:InvokeServer() end)
  setStatus("Sell All dikirim")
 else
  setStatus("Remote Sell All tidak ditemukan")
 end
end)

local FishingTimer=Instance.new("TextLabel",Main)
FishingTimer.Size=UDim2.fromOffset(105,30)
FishingTimer.Position=UDim2.fromOffset(560,294)
FishingTimer.BackgroundColor3=Color3.fromRGB(45,20,20)
FishingTimer.BackgroundTransparency=0.05
FishingTimer.Text="7.5s"
FishingTimer.TextColor3=Color3.fromRGB(255,75,75)
FishingTimer.Font=Enum.Font.GothamBold
FishingTimer.TextSize=13
Instance.new("UICorner",FishingTimer).CornerRadius=UDim.new(0,7)

makeSlider("Fishing Delay",330,330,215,1,15,7.5,0.5,function(v)
 EXTRA.FishingDelay=v
end)
makeSlider("Movement Speed",555,330,110,8,60,16,1,function(v)
 EXTRA.MovementSpeed=v
 applyMovementSpeed()
end)

makeSlider("Transparency",330,374,335,0,0.7,0.08,0.05,function(v)
 EXTRA.Transparency=v
 Main.BackgroundTransparency=v
end)

task.spawn(function()
 while task.wait(0.1) do
  FishingTimer.Text=string.format("%.1fs",fishingCountdown)
  if fishingCountdown>0 then
   FishingTimer.TextColor3=Color3.fromRGB(255,60,60)
  else
   FishingTimer.TextColor3=Color3.fromRGB(180,70,70)
  end
 end
end)

UserInputService.JumpRequest:Connect(function()
 if EXTRA.InfinityJump and Humanoid then
  Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
 end
end)

UserInputService.InputBegan:Connect(function(input,processed)
 if processed then return end
 if input.KeyCode==Enum.KeyCode.F6 then Main.Visible=not Main.Visible
 elseif input.KeyCode==Enum.KeyCode.F7 then
  if running then
   paused=not paused
   if paused and Humanoid then Humanoid:Move(Vector3.zero) end
   setStatus(paused and "Paused" or "Resumed")
  end
 elseif input.KeyCode==Enum.KeyCode.F8 then stop() end
end)


-- Lightweight loading screen.
local Loading=Instance.new("Frame",Gui)
Loading.Size=UDim2.fromScale(1,1)
Loading.BackgroundColor3=Color3.fromRGB(8,10,15)
Loading.BackgroundTransparency=0.05
Loading.ZIndex=100
local LoadingTitle=Instance.new("TextLabel",Loading)
LoadingTitle.Size=UDim2.new(1,0,0,55)
LoadingTitle.Position=UDim2.new(0,0,0.42,0)
LoadingTitle.BackgroundTransparency=1
LoadingTitle.Text="KAYA NGAMBEKAN"
LoadingTitle.TextColor3=Color3.fromRGB(230,245,255)
LoadingTitle.Font=Enum.Font.GothamBlack
LoadingTitle.TextSize=28
LoadingTitle.ZIndex=101
local LoadingSub=Instance.new("TextLabel",Loading)
LoadingSub.Size=UDim2.new(1,0,0,30)
LoadingSub.Position=UDim2.new(0,0,0.52,0)
LoadingSub.BackgroundTransparency=1
LoadingSub.Text="Loading controller..."
LoadingSub.TextColor3=Color3.fromRGB(150,170,190)
LoadingSub.Font=Enum.Font.Gotham
LoadingSub.TextSize=13
LoadingSub.ZIndex=101
task.spawn(function()
 for i=1,18 do
  LoadingSub.Text="Loading controller"..string.rep(".",i%4)
  task.wait(0.08)
 end
 task.wait(0.2)
 Loading.Visible=false
end)

updateCurrent()
setStatus("Ready - "..#CHECKPOINTS.." checkpoint")
print("[Mountain Auto Play] Loaded "..#CHECKPOINTS.." checkpoints")
