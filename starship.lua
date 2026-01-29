-- ============================================================================
-- STARSPACE PLAYBACK ENGINE v2.0 (Reimplemented from StarshipCore)
-- ============================================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Get UI Library reference
local UI = _G.Xan

-- Playback State
local isPlaying = false
local isPaused = false
local isReversing = false
local currentPlaybackFile = nil
local currentFrameData = nil
local currentPlaybackMetadata = nil
local currentPlaybackTime = 0
local playbackSpeed = 1.0
local playbackConnection = nil
local lastFrameIndex = 1
local lastPlaybackTime = 0
local lastAirState = nil
local wasInAirLastFrame = false

-- Extended State for Plugins
local isLooping = false
local isMoonwalk = false
local isGodMode = false
local isSpin = false
local isRespawnOnEnd = false
local skipSnapFrames = 0 -- NEW: Skip position snapping for X frames
local totalDuration = 0
local isPositionBasedPlayback = true -- Default to position-based for smooth movement

-- Configuration
local MAP_DISTANCE_THRESHOLD = 500 -- Max distance to start playback
local CLIMB_ANIM_CHECK_INTERVAL = 0.2
local KEY_CHECK_INTERVAL = 0.1

-- Performance Variables
local lastClimbAnimCheck = 0
local lastKeyCheck = 0
local cachedKeys = {}

-- Tool State (for equip/unequip during playback)
local TOOL_THROTTLE_INTERVAL = 0.1 -- Prevent rapid equip/unequip
local toolState = {
    lastEquipTime = 0,
    lastEquippedTool = nil
}

-- Path Visualization (PREMIUM ENHANCED)
local showPath = false
local pathVisualsFolder = nil
local pathAnimationConnection = nil
local currentPositionMarker = nil

-- Premium gradient colors (Green → Cyan → Blue → Purple → Pink)
local PATH_GRADIENT_COLORS = {
    Color3.fromRGB(34, 197, 94), -- Emerald Green (Start)
    Color3.fromRGB(6, 182, 212), -- Cyan
    Color3.fromRGB(59, 130, 246), -- Blue
    Color3.fromRGB(139, 92, 246), -- Purple
    Color3.fromRGB(236, 72, 153), -- Pink (End)
}

-- Interpolate between gradient colors based on progress (0-1)
local function GetGradientColor(progress)
    local numColors = #PATH_GRADIENT_COLORS
    local scaledProgress = progress * (numColors - 1)
    local colorIndex = math.floor(scaledProgress) + 1
    local colorAlpha = scaledProgress - math.floor(scaledProgress)

    local startColor = PATH_GRADIENT_COLORS[math.clamp(colorIndex, 1, numColors)]
    local endColor = PATH_GRADIENT_COLORS[math.clamp(colorIndex + 1, 1, numColors)]

    return startColor:Lerp(endColor, colorAlpha)
end

-- Initialize _G.StarSpace early
if not _G.StarSpace then _G.StarSpace = {} end

-- Table to store tool name mappings (Old Name -> New Name)
_G.StarSpace.ToolAliases = _G.StarSpace.ToolAliases or {
    ["Speed Coil"] = "Speed Coil 2",
    ["Gravity Coil"] = "Gravity Coil 2",
    ["Fusion Coil"] = "Fusion Coil 2",
}

-- Function to clear path visualization
local function ClearPlaybackPath()
    if pathAnimationConnection then
        pathAnimationConnection:Disconnect()
        pathAnimationConnection = nil
    end
    if currentPositionMarker then
        currentPositionMarker:Destroy()
        currentPositionMarker = nil
    end
    if pathVisualsFolder then
        pathVisualsFolder:Destroy()
        pathVisualsFolder = nil
    end
    
    -- Clean up any orphaned path parts in workspace
    for _, obj in pairs(workspace:GetChildren()) do
        if (obj.Name == "StarshipPathVisuals" or obj.Name == "PlaybackPath") then
            pcall(function() obj:Destroy() end)
        end
    end
end

-- Function to draw the full path visualization
local function DrawPlaybackPath(frames)
    ClearPlaybackPath()
    
    if not showPath then return end
    if not frames or #frames < 2 then return end

    pathVisualsFolder = Instance.new("Folder")
    pathVisualsFolder.Name = "StarshipPathVisuals"
    pathVisualsFolder.Parent = workspace

    local nodesFolder = Instance.new("Folder")
    nodesFolder.Name = "Nodes"
    nodesFolder.Parent = pathVisualsFolder

    local beamsFolder = Instance.new("Folder")
    beamsFolder.Name = "Beams"
    beamsFolder.Parent = pathVisualsFolder

    local markersFolder = Instance.new("Folder")
    markersFolder.Name = "Markers"
    markersFolder.Parent = pathVisualsFolder

    -- Collect all valid positions first
    local positions = {}
    for i = 1, #frames do
        local f = frames[i]
        local pos = f.posVector or (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z))
        if pos then
            table.insert(positions, { pos = pos, index = i })
        end
    end

    if #positions < 2 then return end

    -- Optimization: Limit to ~500 points for performance
    local totalPoints = #positions
    local step = math.max(1, math.floor(totalPoints / 500))
    local filteredPositions = {}
    local lastPos = nil
    local minDistance = 1.0

    for i = 1, totalPoints, step do
        local posData = positions[i]
        if not lastPos or (posData.pos - lastPos).Magnitude > minDistance then
            posData.progress = (i - 1) / math.max(1, totalPoints - 1)
            table.insert(filteredPositions, posData)
            lastPos = posData.pos
        end
    end

    -- Always include last position
    local lastPosData = positions[totalPoints]
    lastPosData.progress = 1
    if #filteredPositions > 0 and (filteredPositions[#filteredPositions].pos - lastPosData.pos).Magnitude > 0.1 then
        table.insert(filteredPositions, lastPosData)
    end

    -- Draw nodes and beams
    local prevPart = nil
    for i, posData in ipairs(filteredPositions) do
        local pos = posData.pos
        local progress = posData.progress
        local color = GetGradientColor(progress)

        local node = Instance.new("Part")
        node.Name = "PathNode_" .. i
        node.Size = Vector3.new(0.3, 0.3, 0.3)
        node.Shape = Enum.PartType.Ball
        node.Color = color
        node.Material = Enum.Material.Neon
        node.Transparency = 0.3
        node.Anchored = true
        node.CanCollide = false
        node.CanQuery = false
        node.CastShadow = false
        node.Position = pos
        node.Parent = nodesFolder

        if prevPart then
            local distance = (pos - prevPart.Position).Magnitude
            if distance > 0.1 then
                local midpoint = (pos + prevPart.Position) / 2
                local beam = Instance.new("Part")
                beam.Name = "PathBeam_" .. i
                beam.Size = Vector3.new(0.1, 0.1, distance)
                beam.Shape = Enum.PartType.Block
                beam.Color = color:Lerp(GetGradientColor(filteredPositions[i - 1].progress), 0.5)
                beam.Material = Enum.Material.Neon
                beam.Transparency = 0.5
                beam.Anchored = true
                beam.CanCollide = false
                beam.CanQuery = false
                beam.CastShadow = false
                beam.CFrame = CFrame.lookAt(midpoint, pos)
                beam.Parent = beamsFolder
            end
        end
        prevPart = node
    end

    -- START MARKER
    if #filteredPositions > 0 then
        local startPos = filteredPositions[1].pos
        local startMarker = Instance.new("Part")
        startMarker.Name = "StartMarker"
        startMarker.Size = Vector3.new(1.2, 1.2, 1.2)
        startMarker.Shape = Enum.PartType.Ball
        startMarker.Color = Color3.fromRGB(34, 197, 94)
        startMarker.Material = Enum.Material.Neon
        startMarker.Anchored = true
        startMarker.CanCollide = false
        startMarker.Position = startPos + Vector3.new(0, 0.5, 0)
        startMarker.Parent = markersFolder

        local startBillboard = Instance.new("BillboardGui")
        startBillboard.Size = UDim2.new(0, 60, 0, 40)
        startBillboard.StudsOffset = Vector3.new(0, 2, 0)
        startBillboard.AlwaysOnTop = true
        startBillboard.Parent = startMarker

        local startText = Instance.new("TextLabel")
        startText.Size = UDim2.new(1, 0, 1, 0)
        startText.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
        startText.BackgroundTransparency = 0.2
        startText.Text = "▶ START"
        startText.TextColor3 = Color3.new(1, 1, 1)
        startText.TextScaled = true
        startText.Font = Enum.Font.SourceSansBold
        startText.Parent = startBillboard
        Instance.new("UICorner", startText).CornerRadius = UDim.new(0.3, 0)

        local startRing = Instance.new("Part")
        startRing.Name = "StartRing"
        startRing.Size = Vector3.new(2.5, 0.1, 2.5)
        startRing.Shape = Enum.PartType.Cylinder
        startRing.Color = Color3.fromRGB(34, 197, 94)
        startRing.Material = Enum.Material.Neon
        startRing.Transparency = 0.5
        startRing.Anchored = true
        startRing.CanCollide = false
        startRing.CFrame = CFrame.new(startPos) * CFrame.Angles(0, 0, math.rad(90))
        startRing.Parent = markersFolder
    end

    -- END MARKER
    if #filteredPositions > 1 then
        local endPos = filteredPositions[#filteredPositions].pos
        local endMarker = Instance.new("Part")
        endMarker.Name = "EndMarker"
        endMarker.Size = Vector3.new(1.2, 1.2, 1.2)
        endMarker.Shape = Enum.PartType.Ball
        endMarker.Color = Color3.fromRGB(239, 68, 68)
        endMarker.Material = Enum.Material.Neon
        endMarker.Anchored = true
        endMarker.CanCollide = false
        endMarker.Position = endPos + Vector3.new(0, 0.5, 0)
        endMarker.Parent = markersFolder

        local endBillboard = Instance.new("BillboardGui")
        endBillboard.Size = UDim2.new(0, 60, 0, 40)
        endBillboard.StudsOffset = Vector3.new(0, 2, 0)
        endBillboard.AlwaysOnTop = true
        endBillboard.Parent = endMarker

        local endText = Instance.new("TextLabel")
        endText.Size = UDim2.new(1, 0, 1, 0)
        endText.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
        endText.BackgroundTransparency = 0.2
        endText.Text = "⏹ END"
        endText.TextColor3 = Color3.new(1, 1, 1)
        endText.TextScaled = true
        endText.Font = Enum.Font.SourceSansBold
        endText.Parent = endBillboard
        Instance.new("UICorner", endText).CornerRadius = UDim.new(0.3, 0)

        local endRing = Instance.new("Part")
        endRing.Name = "EndRing"
        endRing.Size = Vector3.new(2.5, 0.1, 2.5)
        endRing.Shape = Enum.PartType.Cylinder
        endRing.Color = Color3.fromRGB(239, 68, 68)
        endRing.Material = Enum.Material.Neon
        endRing.Transparency = 0.5
        endRing.Anchored = true
        endRing.CanCollide = false
        endRing.CFrame = CFrame.new(endPos) * CFrame.Angles(0, 0, math.rad(90))
        endRing.Parent = markersFolder
    end

    -- DIRECTION ARROWS
    local arrowStep = math.max(1, math.floor(#filteredPositions / 15))
    for i = arrowStep + 1, #filteredPositions - 1, arrowStep do
        local currPos = filteredPositions[i].pos
        local nextPos = filteredPositions[math.min(i + 1, #filteredPositions)].pos
        local direction = (nextPos - currPos)
        if direction.Magnitude > 0.5 then
            direction = direction.Unit
            local arrowColor = GetGradientColor(filteredPositions[i].progress)
            local arrow = Instance.new("Part")
            arrow.Name = "Arrow_" .. i
            arrow.Size = Vector3.new(0.5, 0.5, 0.5)
            arrow.Shape = Enum.PartType.Ball
            arrow.Color = arrowColor
            arrow.Material = Enum.Material.Neon
            arrow.Transparency = 0.2
            arrow.Anchored = true
            arrow.CanCollide = false
            arrow.Position = currPos + Vector3.new(0, 0.3, 0)
            arrow.Parent = markersFolder

            local arrowBB = Instance.new("BillboardGui")
            arrowBB.Size = UDim2.new(0, 30, 0, 30)
            arrowBB.StudsOffset = Vector3.new(0, 0.8, 0)
            arrowBB.AlwaysOnTop = true
            arrowBB.Parent = arrow

            local arrowIcon = Instance.new("TextLabel")
            arrowIcon.Size = UDim2.new(1, 0, 1, 0)
            arrowIcon.BackgroundTransparency = 1
            arrowIcon.Text = "➤"
            arrowIcon.TextColor3 = arrowColor
            arrowIcon.TextScaled = true
            arrowIcon.Font = Enum.Font.SourceSansBold
            arrowIcon.Rotation = math.deg(math.atan2(direction.X, direction.Z))
            arrowIcon.Parent = arrowBB
        end
    end

    -- ANIMATION
    local animTime = 0
    pathAnimationConnection = RunService.Heartbeat:Connect(function(dt)
        if not pathVisualsFolder or not pathVisualsFolder.Parent then
            if pathAnimationConnection then pathAnimationConnection:Disconnect() end
            return
        end
        animTime = animTime + dt

        local startMarker = markersFolder:FindFirstChild("StartMarker")
        if startMarker then
            local pulse = 0.9 + 0.1 * math.sin(animTime * 3)
            startMarker.Size = Vector3.new(1.2 * pulse, 1.2 * pulse, 1.2 * pulse)
        end

        local endMarker = markersFolder:FindFirstChild("EndMarker")
        if endMarker then
            local pulse = 0.9 + 0.1 * math.sin(animTime * 3 + math.pi)
            endMarker.Size = Vector3.new(1.2 * pulse, 1.2 * pulse, 1.2 * pulse)
        end

        local startRing = markersFolder:FindFirstChild("StartRing")
        if startRing then
            startRing.CFrame = CFrame.new(startRing.Position) * CFrame.Angles(0, animTime * 0.5, math.rad(90))
        end

        local endRing = markersFolder:FindFirstChild("EndRing")
        if endRing then
            endRing.CFrame = CFrame.new(endRing.Position) * CFrame.Angles(0, -animTime * 0.5, math.rad(90))
        end

        if isPlaying then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                if not currentPositionMarker or not currentPositionMarker.Parent then
                    currentPositionMarker = Instance.new("Part")
                    currentPositionMarker.Name = "CurrentPosMarker"
                    currentPositionMarker.Size = Vector3.new(1.5, 0.1, 1.5)
                    currentPositionMarker.Shape = Enum.PartType.Cylinder
                    currentPositionMarker.Color = Color3.fromRGB(250, 204, 21)
                    currentPositionMarker.Material = Enum.Material.Neon
                    currentPositionMarker.Transparency = 0.3
                    currentPositionMarker.Anchored = true
                    currentPositionMarker.CanCollide = false
                    currentPositionMarker.Parent = markersFolder
                end
                local ringSize = 1.5 + 0.3 * math.sin(animTime * 5)
                currentPositionMarker.Size = Vector3.new(ringSize, 0.1, ringSize)
                currentPositionMarker.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
            end
        elseif currentPositionMarker then
            currentPositionMarker:Destroy()
            currentPositionMarker = nil
        end
    end)
end

-- API to toggle path
function _G.StarSpace.SetShowPath(v) 
    showPath = v 
    if not v then
        ClearPlaybackPath()
    elseif currentFrameData then
        DrawPlaybackPath(currentFrameData)
    end
end

function _G.StarSpace.GetShowPath()
    return showPath
end

-- Force clear function (accessible globally)
function _G.StarSpace.ClearPath()
    ClearPlaybackPath()
end

-- ==== HELPERS ====

local function GaussianWeight(distance, sigma)
    return math.exp(-(distance * distance) / (2 * sigma * sigma))
end

local function CatmullRomSpline(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function CatmullRomVector3(v0, v1, v2, v3, t)
    return Vector3.new(
        CatmullRomSpline(v0.X, v1.X, v2.X, v3.X, t),
        CatmullRomSpline(v0.Y, v1.Y, v2.Y, v3.Y, t),
        CatmullRomSpline(v0.Z, v1.Z, v2.Z, v3.Z, t)
    )
end

-- Helper to convert external JSON formats (long names) to internal format (short names)
local function NormalizeFrames(frames)
    if not frames or #frames == 0 then return frames end
    
    -- Check if conversion needed (look at first frame)
    local f1 = frames[1]
    if not f1.pos and f1.position then
        -- Needs conversion
        for _, f in ipairs(frames) do
            -- Position
            if f.position then
                f.pos = {x = f.position.x, y = f.position.y, z = f.position.z}
            end
            -- Velocity
            if f.velocity then
                f.vel = {x = f.velocity.x, y = f.velocity.y, z = f.velocity.z}
            end
            -- Rotation (Radians to Degrees)
            if f.rotation then
                f.rot = math.deg(f.rotation)
            end
            -- MoveDirection
            if f.moveDirection then
                f.md = {x = f.moveDirection.x, y = f.moveDirection.y, z = f.moveDirection.z}
            end
            -- State
            if f.state then
                f.st = "Enum.HumanoidStateType." .. f.state
            end
            -- HipHeight
            if f.hipHeight then
                f.hh = f.hipHeight
            end
            -- Time
            if f.time then
                f.t = f.time
            end
        end
    end
    return frames
end

local function PreprocessFrames(frames)
    if not frames or #frames == 0 then return frames end
    if frames[1].posVector ~= nil or frames._preprocessed then return frames end
    
    for i = 1, #frames do
        local f = frames[i]
        if f.pos and not f.posVector then f.posVector = Vector3.new(f.pos.x, f.pos.y, f.pos.z) end
        if f.vel and not f.velVector then f.velVector = Vector3.new(f.vel.x, f.vel.y, f.vel.z) end
        if f.md and not f.mdVector then f.mdVector = Vector3.new(f.md.x, f.md.y, f.md.z) end
        if f.charLook and not f.charLookVector then f.charLookVector = Vector3.new(f.charLook.x, f.charLook.y or 0, f.charLook.z) end
        if f.camLook and not f.camLookVector then f.camLookVector = Vector3.new(f.camLook.x, f.camLook.y, f.camLook.z) end
        
        if f.st and not f.stEnum then
            local stateName = string.match(f.st, "Enum%.HumanoidStateType%.(%w+)")
            if stateName then f.stEnum = stateName end
        end
        
        if i % 10000 == 0 then task.wait() end
    end
    frames._preprocessed = true
    return frames
end

local function SmoothInterpolateFrames(frames, frameIdx, alpha)
    local n = #frames
    if n < 2 then return nil, nil, nil end

    local f1, f2 = frames[frameIdx], frames[frameIdx + 1]
    if not f1 or not f2 then return nil, nil, nil end
    
    -- Clamp alpha to [0, 1] to prevent extrapolation glitches
    alpha = math.clamp(alpha, 0, 1)

    local i0 = math.max(1, frameIdx - 1)
    local i3 = math.min(n, frameIdx + 2)
    local f0, f3 = frames[i0], frames[i3]

    local smoothPos, smoothVel, smoothLook

    -- Position Catmull-Rom
    if f0.posVector and f1.posVector and f2.posVector and f3.posVector then
        smoothPos = CatmullRomVector3(f0.posVector, f1.posVector, f2.posVector, f3.posVector, alpha)
    elseif f1.posVector and f2.posVector then
        smoothPos = f1.posVector:Lerp(f2.posVector, alpha)
    end

    -- Velocity Catmull-Rom
    if f0.velVector and f1.velVector and f2.velVector and f3.velVector then
        smoothVel = CatmullRomVector3(f0.velVector, f1.velVector, f2.velVector, f3.velVector, alpha)
    elseif f1.velVector and f2.velVector then
        smoothVel = f1.velVector:Lerp(f2.velVector, alpha)
    end

    -- Look Direction Catmull-Rom
    if f0.charLookVector and f1.charLookVector and f2.charLookVector and f3.charLookVector then
        smoothLook = CatmullRomVector3(f0.charLookVector, f1.charLookVector, f2.charLookVector, f3.charLookVector, alpha)
        if smoothLook.Magnitude > 0.01 then smoothLook = smoothLook.Unit end
    elseif f1.charLookVector and f2.charLookVector then
        smoothLook = f1.charLookVector:Lerp(f2.charLookVector, alpha)
        if smoothLook.Magnitude > 0.01 then smoothLook = smoothLook.Unit end
    end

    return smoothPos, smoothVel, smoothLook
end

local function GetSmoothedFrames(frames, strength, isFlexible)
    local processedFrames = {}
    for i, frame in ipairs(frames) do
        processedFrames[i] = {}
        for k, v in pairs(frame) do processedFrames[i][k] = v end
        if frame.pos then processedFrames[i].pos = {x=frame.pos.x, y=frame.pos.y, z=frame.pos.z} end
        if frame.vel then processedFrames[i].vel = {x=frame.vel.x, y=frame.vel.y, z=frame.vel.z} end
    end
    
    local iterations = math.clamp(strength or 1, 1, 5)
    local kernelRadius = math.clamp(math.ceil(strength / 2), 1, 3)
    local sigma = kernelRadius / 2
    
    local gaussianWeights = {}
    for d = 0, kernelRadius do gaussianWeights[d] = GaussianWeight(d, sigma) end

    for iter = 1, iterations do
        local tempPos = {}
        
        for i = 2, #processedFrames - 1 do
            local curr = processedFrames[i]
            
            if curr.pos then
                local weightSum, posSum = 0, Vector3.new(0,0,0)
                for j = math.max(1, i - kernelRadius), math.min(#processedFrames, i + kernelRadius) do
                    local neighbor = processedFrames[j]
                    if neighbor.pos then
                        local dist = math.abs(j - i)
                        local weight = gaussianWeights[dist]
                        posSum = posSum + Vector3.new(neighbor.pos.x, neighbor.pos.y, neighbor.pos.z) * weight
                        weightSum = weightSum + weight
                    end
                end
                if weightSum > 0 then
                    local smoothed = posSum / weightSum
                    local currVec = Vector3.new(curr.pos.x, curr.pos.y, curr.pos.z)
                    local final = currVec:Lerp(smoothed, 0.7)
                    tempPos[i] = {x=final.X, y=final.Y, z=final.Z}
                end
            end
            
            if i % 5000 == 0 then task.wait() end
        end
        
        for i, pos in pairs(tempPos) do processedFrames[i].pos = pos end
    end
    
    return processedFrames
end

local function FindFrameIndex(frames, time, hint)
    local low, high = 1, #frames
    if hint and hint > 0 and hint < #frames then
        if frames[hint].t <= time and frames[hint+1] and frames[hint+1].t > time then
            return hint
        end
    end
    while low <= high do
        local mid = math.floor((low + high) / 2)
        if frames[mid].t <= time then
            if not frames[mid+1] or frames[mid+1].t > time then
                return mid
            end
            low = mid + 1
        else
            high = mid - 1
        end
    end
    return math.max(1, low - 1)
end
-- ==== TOOL HANDLING ====

local function ColorMatches(tool, targetColor)
    if not targetColor then return true end
    local handle = tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return true end
    
    -- Support both BrickColor name (string) and RGB (table)
    if type(targetColor) == "string" then
        return handle.BrickColor.Name == targetColor
    elseif type(targetColor) == "table" and targetColor.r then
        local tolerance = 0.05
        return math.abs(handle.Color.R - targetColor.r) < tolerance
            and math.abs(handle.Color.G - targetColor.g) < tolerance
            and math.abs(handle.Color.B - targetColor.b) < tolerance
    end
    return true
end

local function ConfigMatches(tool, targetConfig)
    if not targetConfig then return true end
    local config = tool:FindFirstChild("Configuration") or tool:FindFirstChild("Config")
    if not config then return false end
    
    for name, value in pairs(targetConfig) do
        local child = config:FindFirstChild(name)
        if child and (child:IsA("ValueBase")) then
            if child.Value ~= value then return false end
        else
            return false
        end
    end
    return true
end

local function UpdateToolEquip(char, recordedToolName, recordedToolTip, recordedToolColor, recordedToolConfig)
    if not char then return end
    
    -- Apply Tool Aliases if they exist
    if recordedToolName and _G.StarSpace and _G.StarSpace.ToolAliases then
        local alias = _G.StarSpace.ToolAliases[recordedToolName]
        if alias then
            recordedToolName = alias
        end
    end
    
    if not char then return end
    
    -- Throttle tool changes
    local now = os.clock()
    if now - toolState.lastEquipTime < TOOL_THROTTLE_INTERVAL then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local currentTool = char:FindFirstChildOfClass("Tool")
    local currentToolName = currentTool and currentTool.Name or nil
    
    -- CASE 1: No tool recorded, but player has tool equipped → unequip
    if not recordedToolName then
        if currentTool then
            toolState.lastEquipTime = now
            toolState.lastEquippedTool = nil
            hum:UnequipTools()
        end
        return
    end
    
    -- CASE 2: Tool recorded, check if we need to equip
    -- Skip if same tool is already equipped (prevent double equip/speed stack)
    if currentTool and currentToolName == recordedToolName then
        toolState.lastEquippedTool = currentTool
        return
    end
    
    -- CASE 3: Need to equip a different tool
    toolState.lastEquipTime = now
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end
    
    local toolToEquip = nil
    
    -- Priority 1: Match name + tooltip + color + config (exact match)
    if recordedToolTip or recordedToolColor or recordedToolConfig then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == recordedToolName then
                local tipMatch = (not recordedToolTip) or (tool.ToolTip == recordedToolTip)
                local colorMatch = ColorMatches(tool, recordedToolColor)
                local configMatch = ConfigMatches(tool, recordedToolConfig)
                if tipMatch and colorMatch and configMatch then
                    toolToEquip = tool
                    break
                end
            end
        end
    end
    
    -- Priority 2: Match name + tooltip
    if not toolToEquip and recordedToolTip then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == recordedToolName and tool.ToolTip == recordedToolTip then
                toolToEquip = tool
                break
            end
        end
    end
    
    -- Priority 3: Match name + color
    if not toolToEquip and recordedToolColor then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == recordedToolName and ColorMatches(tool, recordedToolColor) then
                toolToEquip = tool
                break
            end
        end
    end
    
    -- Priority 4: Fallback to name-only match
    if not toolToEquip then
        toolToEquip = backpack:FindFirstChild(recordedToolName)
    end
    
    -- Priority 5: Fuzzy Match (Case Insensitive)
    if not toolToEquip then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower() == recordedToolName:lower() then
                toolToEquip = tool
                break
            end
        end
    end
    
    -- Only equip if we found a tool AND it's different from current
    if toolToEquip and toolToEquip:IsA("Tool") and toolToEquip ~= currentTool then
        toolState.lastEquippedTool = toolToEquip
        hum:EquipTool(toolToEquip)
    end
end

-- ==== API ====

if not _G.StarSpace then _G.StarSpace = {} end

-- print("[StarSpacePlayback] v2.0 Loaded!")

function _G.StarSpace.GetPlaybackState()
    return {
        isPlaying = isPlaying,
        isPaused = isPaused,
        currentTime = currentPlaybackTime,
        totalDuration = totalDuration,
        currentFile = currentPlaybackFile,
        isLooping = isLooping,
        isMoonwalk = isMoonwalk,
        isGodMode = isGodMode,
        isSpin = isSpin
    }
end

function _G.StarSpace.SetLooping(v) isLooping = v end
function _G.StarSpace.SetMoonwalk(v) isMoonwalk = v end
function _G.StarSpace.SetGodMode(v) isGodMode = v end
function _G.StarSpace.SetSpin(v) isSpin = v end
function _G.StarSpace.SetRespawnOnEnd(v) isRespawnOnEnd = v end
function _G.StarSpace.SetSpeed(v) playbackSpeed = v or 1.0 end
function _G.StarSpace.SetPlaybackSpeed(v) playbackSpeed = v or 1.0 end -- Alias for MapListPlugin compatibility
function _G.StarSpace.GetPlaybackSpeed() return playbackSpeed end

function _G.StarSpace.GetPlaybackState()
    return {
        isPlaying = isPlaying,
        isPaused = isPaused,
        isLooping = isLooping,
        currentTime = currentPlaybackTime,
        totalDuration = totalDuration,
        currentFile = currentPlaybackFile,
        showPath = showPath
    }
end

-- Stop playback completely
-- @param silent (optional) - if true, don't show notification
function _G.StarSpace.StopPlayback(silent)
    -- Early return if nothing is playing - no notification needed
    if not isPlaying and not playbackConnection then
        return
    end
    
    isPlaying = false
    isPaused = false
    currentPlaybackTime = 0
    lastFrameIndex = 1
    
    -- Disconnect playback connection
    if playbackConnection then 
        playbackConnection:Disconnect() 
        playbackConnection = nil
    end
    
    -- Clear path visualization
    ClearPlaybackPath()
    
    -- Reset character state
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        
        -- Remove playback constraints
        local att = root:FindFirstChild("PlaybackAtt")
        if att then att:Destroy() end
        local ao = root:FindFirstChild("PlaybackAO")
        if ao then ao:Destroy() end
    end
    
    if hum then
        hum.AutoRotate = true
        -- CARRY PRESERVATION: Skip stopping animations when ForceCarryMode is ON
        if not _G.StarshipForceCarryMode then
            for _, t in pairs(hum:GetPlayingAnimationTracks()) do
                t:Stop()
            end
            hum:Move(Vector3.zero)
        end
    end
    
    -- Only show notification if not silent (check both parameter and flag)
    local isSilent = silent or (_G.StarSpace and _G.StarSpace._silentStop)
    if not isSilent and UI and UI.Slide then
        UI.Slide("Playback", "Stopped")
    end
    
    print("[StarSpacePlayback] Playback stopped, path cleared")
end

-- ==== HELPERS ====

local function FindNearestFrame(frames, rPos)
    local minDst = math.huge
    local bestT = 0
    local bestFrameIdx = 1
    local minGroundDst = math.huge
    local bestGroundT = 0
    local bestGroundIdx = 1
    
    -- Sample every 10th frame for quick search
    local step = math.max(1, math.floor(#frames / 100))
    for i = 1, #frames, step do
        local f = frames[i]
        local pos = f.posVector or (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z))
        if pos then
            local dst = (rPos - pos).Magnitude
            if dst < minDst then
                minDst = dst
                bestT = f.t
                bestFrameIdx = i
            end
            
            -- Also track nearest ground frame
            local stateName = f.stEnum or (f.st and string.match(f.st, "Enum%.HumanoidStateType%.(%w+)"))
            local isGroundFrame = (stateName == nil) or (stateName == "Running") or (stateName == "Landed") or (stateName == "Climbing")
            
            if isGroundFrame and dst < minGroundDst then
                minGroundDst = dst
                bestGroundT = f.t
                bestGroundIdx = i
            end
        end
    end
    
    -- Fine search around best frame
    local searchRadius = step * 2
    local fineStart = math.max(1, bestFrameIdx - searchRadius)
    local fineEnd = math.min(#frames, bestFrameIdx + searchRadius)
    
    for i = fineStart, fineEnd do
        local f = frames[i]
        local pos = f.posVector or (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z))
        if pos then
            local dst = (rPos - pos).Magnitude
            if dst < minDst then
                minDst = dst
                bestT = f.t
                bestFrameIdx = i
            end
            
            local stateName = f.stEnum or (f.st and string.match(f.st, "Enum%.HumanoidStateType%.(%w+)"))
            local isGroundFrame = (stateName == nil) or (stateName == "Running") or (stateName == "Landed") or (stateName == "Climbing")
            
            if isGroundFrame and dst < minGroundDst then
                minGroundDst = dst
                bestGroundT = f.t
                bestGroundIdx = i
            end
        end
    end
    
    -- Prioritize ground frames if close enough
    if minGroundDst < minDst + 20 then
        return bestGroundT, minGroundDst, bestGroundIdx
    end
    
    return bestT, minDst, bestFrameIdx
end

function _G.StarSpace.LoadRecording(pathOrName)
    -- print("[StarSpacePlayback] LoadRecording: " .. tostring(pathOrName))
    
    local data = nil
    local isCloud = (type(pathOrName) == "string" and pathOrName:sub(1, 6) == "CLOUD:")
    
    if isCloud then
        -- Handle Cloud Recording
        if _G.StarshipCloud and _G.StarshipCloud.RecordingData then
            data = _G.StarshipCloud.RecordingData
            -- print("[StarSpacePlayback] Using loaded cloud data")
        else
            if UI and UI.Slide then
                UI.Slide("Error", "Cloud data not found!")
            end
            return
        end
    else
        -- Handle Local File
        local filePath = pathOrName
        if not isfile(filePath) then
            local commonPaths = {
                "StarSpace/StarSpace-Recording/" .. pathOrName,
                "StarSpace/StarshipMerger/" .. pathOrName,
                "StarSpace/" .. pathOrName,
                pathOrName
            }
            for _, p in ipairs(commonPaths) do
                if isfile(p) then filePath = p break end
            end
        end
        
        if not isfile(filePath) then
            if UI and UI.Slide then
                UI.Slide("Error", "File not found: " .. pathOrName)
            end
            return
        end

        local success, content = pcall(readfile, filePath)
        if not success or not content then 
            if UI and UI.Slide then UI.Slide("Error", "Failed to read file") end
            return 
        end
        
        local success2, decoded = pcall(function() return HttpService:JSONDecode(content) end)
        if not success2 or not decoded then
            if UI and UI.Slide then UI.Slide("Error", "Failed to decode JSON") end
            return
        end
        data = decoded
    end
    
    -- Skip reloading if same file/cloud ID is already loaded
    if currentPlaybackFile == pathOrName and currentFrameData then
        -- print("[StarSpacePlayback] Already loaded, skipping reload.")
        
        -- Stop existing loop before restarting
        if playbackConnection then playbackConnection:Disconnect() end
        
        -- Just reset state and proceed to Smart Start
        isPaused = false
        
        -- Ensure totalDuration is set
        if #currentFrameData > 0 then
            totalDuration = currentFrameData[#currentFrameData].t or 0
        end
    else
        -- Stop existing playback
        if isPlaying then
            isPlaying = false
            if playbackConnection then playbackConnection:Disconnect() end
        end
        
        local frames = NormalizeFrames(data.Frames or data)
        frames = PreprocessFrames(frames)
        
        if #frames > 0 then
            totalDuration = frames[#frames].t or (#frames / (data.FPS or 60))
        else
            totalDuration = 0
        end
        
        if #frames > 10 and not data.IsSmoothed then
            -- Only smooth if not already smoothed and not excessively large
            if #frames < 30000 then 
                frames = GetSmoothedFrames(frames, 2, true)
                frames = PreprocessFrames(frames)
            end
        end
        
        currentFrameData = frames
        currentPlaybackFile = pathOrName
        currentPlaybackMetadata = data -- Store metadata for later use
    end
    
    local frames = currentFrameData
    if not frames or #frames == 0 then 
        -- print("[StarSpacePlayback] Error: No frames to play!")
        return 
    end
    
    -- Reset state before starting
    isPaused = false
    lastAirState = nil
    wasInAirLastFrame = false
    
    -- Draw path visualization if enabled
    if showPath then
        DrawPlaybackPath(frames)
    end
    
    print("[StarSpacePlayback] Preparing playback for " .. #frames .. " frames")
    
    local char = LocalPlayer.Character
    local r = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChild("Humanoid")
    
    if not r or not h then 
        -- print("[StarSpacePlayback] Error: Character or RootPart not found!")
        return 
    end
    
    -- Set isPlaying to true for Travel Phase
    isPlaying = true
    -- print("[StarSpacePlayback] isPlaying set to true. Starting Smart Start logic...")
    
    -- ========================================
    -- SMART START: Find nearest point on path
    -- Start from player's current position instead of beginning
    -- ========================================
    local bestT, minDst, bestFrameIdx = FindNearestFrame(frames, r.Position)
    
    -- Determine start time based on position
    local skipTravelPhase = false
    
    -- Smart position logic (From StarshipCore)
    if bestT >= (totalDuration - 2.0) then
        -- If nearest point is within the last 2 seconds, restart from 0
        currentPlaybackTime = 0
        lastFrameIndex = 1
        skipTravelPhase = (minDst < 10) -- Skip walk if already at start
        
        if UI and UI.Slide then
            UI.Slide("Smart Start", "Restarting from beginning (near end)")
        end
    elseif bestT < 1.0 then
        -- If nearest point is within first 1 second, start from 0
        currentPlaybackTime = 0
        lastFrameIndex = 1
        skipTravelPhase = (minDst < 10)
        
        if UI and UI.Slide and not skipTravelPhase then
            UI.Slide("Smart Start", "Starting from beginning")
        end
    elseif minDst < 100 then
        -- Player is close to path - skip travel phase and skip initial snap
        currentPlaybackTime = bestT
        lastFrameIndex = bestFrameIdx
        skipTravelPhase = true
        skipSnapFrames = 60 -- Skip snap for 1 second to allow smooth transition
        
        if UI and UI.Slide then
            UI.Slide("Smart Start", string.format("Starting from %.1fs (Smooth Sync)", bestT))
        end
    elseif minDst < 500 then
        -- Player is near the path - walk to nearest point, then start
        currentPlaybackTime = bestT
        lastFrameIndex = bestFrameIdx
        skipTravelPhase = false
        
        if UI and UI.Slide then
            UI.Slide("Smart Start", string.format("Walking to path at %.1fs (%.0f studs)", bestT, minDst))
        end
    else
        -- Player is far from path - start from beginning
        currentPlaybackTime = 0
        lastFrameIndex = 1
        skipTravelPhase = false
    end
    
    -- Initialize playback state
    lastPlaybackTime = currentPlaybackTime - 100 -- Force isTimeJump
    skipSnapFrames = 60
    lastAirState = nil
    wasInAirLastFrame = false
    
    -- ========================================
    -- CROSS-RIG HEIGHT OFFSET SYSTEM (From StarshipCore)
    -- Handles: R6→R15, R15→R6, and same-rig playback
    -- ========================================
    local playbackIsR6 = (char:FindFirstChild("Torso") ~= nil)
    local playbackRigType = playbackIsR6 and "R6" or "R15"
    
    -- Auto-detect RigType from recording data
    local recordedRigType = currentPlaybackMetadata and currentPlaybackMetadata.RigType
    -- print("[StarSpacePlayback] Detected Recorded RigType: " .. tostring(recordedRigType))
    
    if not recordedRigType then
        local firstFrame = frames[1]
        if firstFrame and firstFrame.j then
            -- Check for R6-specific joints
            if firstFrame.j["Left Leg"] or firstFrame.j["Right Leg"] or firstFrame.j["Torso"] then
                recordedRigType = "R6"
            -- Check for R15-specific joints
            elseif firstFrame.j["LeftUpperLeg"] or firstFrame.j["RightUpperLeg"] or firstFrame.j["UpperTorso"] then
                recordedRigType = "R15"
            else
                recordedRigType = "R15" -- Default fallback
            end
        else
            -- Flexible mode: Try to detect from recorded HipHeight
            -- R6 HipHeight is typically 0, R15 is ~2.0
            if firstFrame and firstFrame.hh ~= nil then
                if firstFrame.hh < 0.5 then
                    recordedRigType = "R6"
                else
                    recordedRigType = "R15"
                end
            else
                -- Default to R15 (most common)
                recordedRigType = "R15"
            end
        end
    end
    
    -- Calculate PLAYBACK avatar's root height
    local playbackRootHeight = 0
    if playbackIsR6 then
        local leftLeg = char:FindFirstChild("Left Leg")
        local rightLeg = char:FindFirstChild("Right Leg")
        local torso = char:FindFirstChild("Torso")
        local legLength = (leftLeg and leftLeg.Size.Y) or (rightLeg and rightLeg.Size.Y) or 2
        local torsoHalfHeight = (torso and torso.Size.Y / 2) or 1
        playbackRootHeight = legLength + torsoHalfHeight
    else
        -- R15: HipHeight + RootPart half height
        playbackRootHeight = h.HipHeight + (r.Size.Y / 2)
    end
    
    -- Calculate Cross-Rig Height Offset based on HipHeight difference
    local crossRigHeightOffset = 0
    
    -- Get recorded HipHeight (either from metadata or from first frame)
    local recordedHipHeight = currentPlaybackMetadata and currentPlaybackMetadata.HipHeight
    if not recordedHipHeight then
        local firstFrame = frames[1]
        if firstFrame and firstFrame.hh then
            recordedHipHeight = firstFrame.hh
        else
            -- Estimate based on detected rig type
            recordedHipHeight = (recordedRigType == "R15") and 2.0 or 0
        end
    end
    
    -- Get playback HipHeight
    local playbackHipHeight = h.HipHeight or 0
    
    -- Calculate offset based on HipHeight difference
    crossRigHeightOffset = playbackHipHeight - recordedHipHeight
    
    -- Log Cross-Rig info
    if recordedRigType ~= playbackRigType then
        -- print(string.format("[StarSpacePlayback] Cross-Rig: %s → %s (Offset: %.2f)", recordedRigType, playbackRigType, crossRigHeightOffset))
        if UI and UI.Slide then
            UI.Slide("Cross-Rig Playback", string.format("Recorded: %s → Playing: %s", recordedRigType, playbackRigType))
        end
    end
    
    -- Restart Animate script for proper animation (R6 compatibility)
    -- CARRY PRESERVATION: Skip Animate restart when ForceCarryMode is ON
    local animScript = char:FindFirstChild("Animate")
    if animScript and not _G.StarshipForceCarryMode then
        animScript.Disabled = true
        task.wait(0.05)
        animScript.Disabled = false
        -- R6 may need additional nudge to restart animations
        if playbackIsR6 then
            task.spawn(function()
                task.wait(0.1)
                h:Move(Vector3.zero) -- Trigger idle state
            end)
        end
    end
    
    h.AutoRotate = true
    
    -- Cache for loop
    local cachedPlaybackIsR6 = playbackIsR6
    local cachedCrossRigHeightOffset = crossRigHeightOffset
    
    -- ========================================
    -- TRAVEL PHASE (From StarshipCore)
    -- Walk to target position (Smart Start or beginning)
    -- ========================================
    if not skipTravelPhase then
        -- Get target frame position (from Smart Start calculation)
        local targetFrame = frames[lastFrameIndex] or frames[1]
        local targetPos = targetFrame.posVector
        if not targetPos and targetFrame.pos then
            targetPos = Vector3.new(targetFrame.pos.x, targetFrame.pos.y, targetFrame.pos.z)
        end
        
        if targetPos then
            -- Apply cross-rig height offset
            if cachedCrossRigHeightOffset ~= 0 then
                targetPos = Vector3.new(targetPos.X, targetPos.Y + cachedCrossRigHeightOffset, targetPos.Z)
            end
            
            -- Use 3D distance for travel phase check
            local dist = (r.Position - targetPos).Magnitude
            
            if dist > 5 and dist < 150 then
            -- Walk to start position naturally
            r.Anchored = false
            -- CARRY PRESERVATION: Skip enabling Animate if ForceCarryMode is ON (assume it's already in right state)
            if animScript and not _G.StarshipForceCarryMode then animScript.Disabled = false end
            h.AutoRotate = true
            
            if UI and UI.Slide then
                UI.Slide("Travel Phase", string.format("Walking to start (%.0f studs)...", dist))
            end
            
            -- Use normal walk speed or recorded speed
            local walkSpeed = h.WalkSpeed
            if walkSpeed < 16 then walkSpeed = 16 end
            
            -- Calculate speed from recorded data
            if targetFrame.velVector then
                local recSpeed = Vector3.new(targetFrame.velVector.X, 0, targetFrame.velVector.Z).Magnitude
                if recSpeed > walkSpeed then walkSpeed = recSpeed end
            elseif targetFrame.vel then
                local recSpeed = Vector3.new(targetFrame.vel.x, 0, targetFrame.vel.z).Magnitude
                if recSpeed > walkSpeed then walkSpeed = recSpeed end
            end
            
            h.WalkSpeed = walkSpeed
            h:MoveTo(targetPos)
            
            -- Wait until close enough or timeout
            local moveStart = os.clock()
            local maxWalkTime = math.min(dist / 10, 15) -- Max 15 seconds, ~10 studs/sec
            
            while isPlaying do
                local d = (r.Position - targetPos).Magnitude
                
                -- Close enough
                if d <= 3 then
                    break
                end
                
                -- Timeout - teleport and start
                if os.clock() - moveStart > maxWalkTime then
                    r.CFrame = CFrame.new(targetPos) * r.CFrame.Rotation
                    if UI and UI.Slide then
                        UI.Slide("Travel", "Teleported (timeout)")
                    end
                    break
                end
                
                -- Keep walking
                h:MoveTo(targetPos)
                task.wait(0.1)
            end
            
            -- Stop walking
            h:MoveTo(r.Position)
            task.wait(0.1)
            
        elseif dist <= 5 then
            -- Already very close, just start
            if UI and UI.Slide then
                UI.Slide("Playback", "Starting from current position")
            end
        else
            -- Too far (> 1000 studs), teleport directly
            r.CFrame = CFrame.new(targetPos)
            if UI and UI.Slide then
                UI.Slide("Teleport", "Teleported to path (too far)")
            end
            task.wait(0.5)
        end
        end
    end -- end skipTravelPhase check
    
    -- ==== MAIN PLAYBACK LOOP ====
    -- print("[StarSpacePlayback] Starting Heartbeat loop...")
    isPlaying = true -- Set to true ONLY now
    
    playbackConnection = RunService.Heartbeat:Connect(function(dt)
        if not isPlaying or isPaused then return end
        
        local success, err = pcall(function()
        
        -- Decrement skip snap frames
        if skipSnapFrames > 0 then
            skipSnapFrames = skipSnapFrames - 1
        end
        if not char or not char.Parent then
            char = LocalPlayer.Character
            if char then
                r = char:FindFirstChild("HumanoidRootPart")
                h = char:FindFirstChild("Humanoid")
            end
            return
        end
        
        -- Update Time
        local updateDt = dt
        if isReversing then
            currentPlaybackTime = currentPlaybackTime - (updateDt * playbackSpeed)
            if currentPlaybackTime <= 0 then
                if isLooping then 
                    currentPlaybackTime = totalDuration 
                    lastFrameIndex = #frames 
                else 
                    if _G.StarSpace and _G.StarSpace.StopPlayback then
                        _G.StarSpace.StopPlayback()
                    else
                        isPlaying = false
                        if playbackConnection then playbackConnection:Disconnect() end
                    end
                end
                return
            end
        else
            currentPlaybackTime = currentPlaybackTime + (updateDt * playbackSpeed)
            if currentPlaybackTime >= totalDuration then
                if isLooping then 
                    currentPlaybackTime = 0 
                    lastFrameIndex = 1 
                else 
                    if _G.StarSpace and _G.StarSpace.StopPlayback then
                        _G.StarSpace.StopPlayback()
                    else
                        isPlaying = false
                        if playbackConnection then playbackConnection:Disconnect() end
                    end
                    if isRespawnOnEnd then h.Health = 0 end 
                end
                return
            end
        end
        
        -- Detect Time Jump (Slider Seeking)
        local expectedDelta = updateDt * playbackSpeed
        local actualDelta = math.abs(currentPlaybackTime - lastPlaybackTime)
        local isTimeJump = actualDelta > (expectedDelta * 3 + 0.1)
        lastPlaybackTime = currentPlaybackTime
        
        -- Find Frames
        local frameIdx = FindFrameIndex(frames, currentPlaybackTime, lastFrameIndex)
        lastFrameIndex = frameIdx
        local fA, fB = frames[frameIdx], frames[frameIdx + 1]

        if fA and fB then
            local deltaT = fB.t - fA.t
            local alpha = 0
            if deltaT > 0.0001 then alpha = (currentPlaybackTime - fA.t) / deltaT end
            
            -- TELEPORT DETECTION for merged recordings
            -- If time gap is large (>0.3s), check if position also changed significantly
            local isTeleportFrame = false
            if deltaT > 0.3 then
                local posA = fA.posVector or (fA.pos and Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z))
                local posB = fB.posVector or (fB.pos and Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z))
                if posA and posB then
                    local distance = (posB - posA).Magnitude
                    if distance > 30 then -- 30 studs = checkpoint/teleport
                        isTeleportFrame = true
                    end
                end
            end

            local cachedStateName = fA.stEnum or (fA.st and string.match(fA.st, "Enum%.HumanoidStateType%.(%w+)"))
            local isCurrentlyClimbing = (cachedStateName == "Climbing")
            local isCurrentlySwimming = (cachedStateName == "Swimming")
            
            local smoothPos, smoothVel, smoothLook
            
            -- For teleport frames, skip interpolation and use fB position directly when alpha > 0.5
            if isTeleportFrame then
                if alpha > 0.5 then
                    -- Use fB's exact position (teleport destination)
                    smoothPos = fB.posVector or (fB.pos and Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z))
                    smoothVel = fB.velVector or (fB.vel and Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z))
                    smoothLook = fB.charLookVector or (fB.charLook and Vector3.new(fB.charLook.x, fB.charLook.y, fB.charLook.z))
                else
                    -- Use fA's exact position (before teleport)
                    smoothPos = fA.posVector or (fA.pos and Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z))
                    smoothVel = fA.velVector or (fA.vel and Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z))
                    smoothLook = fA.charLookVector or (fA.charLook and Vector3.new(fA.charLook.x, fA.charLook.y, fA.charLook.z))
                end
            else
                -- Normal smooth interpolation
                smoothPos, smoothVel, smoothLook = SmoothInterpolateFrames(frames, frameIdx, alpha)
            end

            -- ==== CROSS-RIG HEIGHT OFFSET CORRECTION ====
            if cachedCrossRigHeightOffset ~= 0 and smoothPos then
                smoothPos = Vector3.new(smoothPos.X, smoothPos.Y + cachedCrossRigHeightOffset, smoothPos.Z)
            end

            -- God Mode
            if isGodMode then h.Health = h.MaxHealth end

            -- ==== STATE HANDLING (Matching StarshipCore.lua exactly) ====
            if cachedStateName then
                local stateEnum = Enum.HumanoidStateType[cachedStateName]
                if stateEnum then
                    local currentState = h:GetState()
                    local isAirState = (stateEnum == Enum.HumanoidStateType.Jumping or stateEnum == Enum.HumanoidStateType.Freefall)
                    
                    if isAirState then
                        -- PRIORITY: Use RECORDED STATE directly, not velocity
                        -- If recording says "Jumping", use Jumping. If "Freefall", use Freefall.
                        local isJumpState = (stateEnum == Enum.HumanoidStateType.Jumping)
                        local targetState = isJumpState and "jump" or "fall"
                        
                        -- FALLBACK: Use velocity only if state seems wrong
                        -- (velY > 15 but state says freefall = probably should be jumping)
                        local velY = fA.velVector and fA.velVector.Y or (fA.vel and fA.vel.y or 0)
                        if velY > 15 and not isJumpState then
                            targetState = "jump" -- Override to jump if velocity is strongly upward
                        end
                        
                        -- Change state if different from last
                        if targetState ~= lastAirState then
                            lastAirState = targetState
                            if targetState == "jump" then
                                -- Trigger jump animation
                                if currentState ~= Enum.HumanoidStateType.Jumping then
                                    h:ChangeState(Enum.HumanoidStateType.Jumping)
                                end
                                -- R6 needs h.Jump = true for proper animation
                                if cachedPlaybackIsR6 then
                                    h.Jump = true
                                end
                            else
                                -- Trigger freefall animation
                                if currentState ~= Enum.HumanoidStateType.Freefall then
                                    h:ChangeState(Enum.HumanoidStateType.Freefall)
                                end
                            end
                        end
                    elseif stateEnum == Enum.HumanoidStateType.Landed then
                        lastAirState = nil
                        if currentState ~= Enum.HumanoidStateType.Landed then
                            h:ChangeState(Enum.HumanoidStateType.Landed)
                        end
                    elseif stateEnum == Enum.HumanoidStateType.Running then
                        lastAirState = nil
                        -- Running: Prevent unwanted freefall on small bumps
                        if currentState == Enum.HumanoidStateType.Freefall then
                            -- Check if we should be running instead
                            local velY = fA.velVector and fA.velVector.Y or (fA.vel and fA.vel.y or 0)
                            if math.abs(velY) < 3 then
                                h:ChangeState(Enum.HumanoidStateType.Running)
                            end
                        end
                    elseif stateEnum == Enum.HumanoidStateType.Climbing and currentState ~= stateEnum then
                        h:ChangeState(stateEnum)
                        if fA.velVector or fA.vel then
                            local climbVel = fA.velVector or Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
                            r.AssemblyLinearVelocity = climbVel * playbackSpeed
                        end
                    elseif stateEnum == Enum.HumanoidStateType.Swimming and currentState ~= stateEnum then
                        h:ChangeState(stateEnum)
                        if fA.hh then h.HipHeight = fA.hh end
                    end
                end
            end
            
            -- Trigger jump flag if recorded
            if fA.jmp and not isReversing then h.Jump = true end

            -- Determine Air State (AFTER state is applied)
            local isInAir = (cachedStateName == "Jumping" or cachedStateName == "Freefall")
            local justLanded = wasInAirLastFrame and not isInAir
            
            if wasInAirLastFrame and not justLanded then
                local isFreefall = (cachedStateName == "Freefall")
                local realFloorMaterial = h.FloorMaterial
                local isActuallyOnGround = realFloorMaterial ~= Enum.Material.Air
                local velY = fA.velVector and fA.velVector.Y or (fA.vel and fA.vel.y or 0)
                local isActuallyFalling = velY < 5
                
                if isFreefall and isActuallyOnGround and isActuallyFalling then
                    justLanded = true
                    isInAir = false
                end
            end
            wasInAirLastFrame = isInAir

            -- ==== Climbing/Swimming ====
            if isCurrentlyClimbing or isCurrentlySwimming then
                local vel = (fA.velVector and fB.velVector) and fA.velVector:Lerp(fB.velVector, alpha) or Vector3.zero
                vel = vel * playbackSpeed
                if isReversing then vel = -vel end

                if fA.mdVector or fA.md then
                    local moveDir = fA.mdVector or Vector3.new(fA.md.x, fA.md.y, fA.md.z)
                    if isReversing then moveDir = -moveDir end
                    h:Move(moveDir)
                    h:ChangeState(Enum.HumanoidStateType.Climbing)
                elseif vel.Magnitude > 0.1 then
                    local worldMoveDir = vel.Unit
                    local charCF = r.CFrame
                    local localMoveDir = charCF:VectorToObjectSpace(worldMoveDir)
                    local moveScale = vel.Magnitude / 16 * playbackSpeed * 25.0
                    h:Move(Vector3.new(localMoveDir.X, localMoveDir.Y, localMoveDir.Z) * moveScale)
                else
                    h:Move(Vector3.zero)
                end
                r.AssemblyLinearVelocity = vel

                local targetPos = (fA.posVector and fB.posVector) and fA.posVector:Lerp(fB.posVector, alpha) or r.Position
                local currentPos = r.Position
                local smoothedPos = currentPos:Lerp(targetPos, 0.5)
                r.CFrame = CFrame.new(smoothedPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
                h:ChangeState(Enum.HumanoidStateType.Climbing)

            -- ==== In Air ====
            elseif isInAir and smoothPos then
                local targetVel = smoothVel or (fA.velVector and fB.velVector and fA.velVector:Lerp(fB.velVector, alpha)) or Vector3.zero
                local currentPos = r.Position
                local posDiff = smoothPos - currentPos
                local correctionStrength = 5
                local correctionVel = posDiff * correctionStrength
                local finalVel = targetVel + correctionVel
                r.AssemblyLinearVelocity = finalVel
                
                if posDiff.Magnitude > 2 and skipSnapFrames <= 0 and not isTimeJump then
                    local snapPos = currentPos:Lerp(smoothPos, 0.2)
                    r.CFrame = CFrame.new(snapPos) * r.CFrame.Rotation
                end
                
                -- Apply Spin
                if isSpin then
                    r.CFrame = r.CFrame * CFrame.Angles(0, dt * 10, 0)
                end

            -- ==== Just Landed ====
            elseif justLanded and smoothPos then
                local currentPos = r.Position
                local newPos = currentPos:Lerp(smoothPos, 0.5) -- Smoother landing
                
                -- Calculate target rotation with moonwalk support
                local targetRot = fA.rot or 0
                if isMoonwalk and not isReversing then
                    targetRot = targetRot + 180
                end
                
                -- Use lerp for smoother rotation transition during landing
                local targetCF = CFrame.new(newPos) * CFrame.Angles(0, math.rad(targetRot), 0)
                r.CFrame = r.CFrame:Lerp(targetCF, 0.4) -- Smooth transition
                
                -- Dampen velocity on landing to prevent bounce
                local dampedVel = smoothVel or Vector3.zero
                dampedVel = Vector3.new(dampedVel.X * 0.5, math.min(dampedVel.Y, 0), dampedVel.Z * 0.5)
                r.AssemblyLinearVelocity = dampedVel
                
                if fA.mdVector or fA.md then
                    local moveDir = fA.mdVector or Vector3.new(fA.md.x, fA.md.y, fA.md.z)
                    h:Move(moveDir, false)
                else h:Move(Vector3.zero) end

            -- ==== Ground Movement ====
            else
                if isPositionBasedPlayback and smoothPos then
                    local currentPos = r.Position
                    local posDiff = smoothPos - currentPos
                    local distance = posDiff.Magnitude
                    
                    local correctionStrength = math.clamp(distance * 6, 0, 50)
                    local correctionVel = distance > 0.01 and (posDiff.Unit * correctionStrength) or Vector3.zero
                    local targetVel = smoothVel or Vector3.zero
                    local finalVel = targetVel + correctionVel
                    
                    r.AssemblyLinearVelocity = r.AssemblyLinearVelocity:Lerp(finalVel, 0.6)
                    
                    if distance > 8 and skipSnapFrames <= 0 and not isTimeJump then
                        local snapPos = currentPos:Lerp(smoothPos, 0.5)
                        
                        -- Support moonwalk during snapping
                        local targetRot = fA.rot or 0
                        if isMoonwalk and not isReversing then
                            targetRot = targetRot + 180
                        end
                        
                        local targetCF = CFrame.new(snapPos) * CFrame.Angles(0, math.rad(targetRot), 0)
                        r.CFrame = r.CFrame:Lerp(targetCF, 0.3) -- Smooth snap instead of instant
                    end
                    
                    -- Trigger Walk Animation
                    if fA.mdVector or fA.md then
                        local moveDir = fA.mdVector or Vector3.new(fA.md.x, fA.md.y, fA.md.z)
                        if moveDir.Magnitude > 0.01 then h:Move(moveDir, false) else h:Move(Vector3.zero) end
                    elseif finalVel.Magnitude > 0.5 then
                        local flatVel = Vector3.new(finalVel.X, 0, finalVel.Z)
                        if flatVel.Magnitude > 0.1 then h:Move(flatVel.Unit, false) end
                    else h:Move(Vector3.zero) end
                else
                    -- Velocity-based fallback
                    local vel = smoothVel or (fA.velVector and fB.velVector and fA.velVector:Lerp(fB.velVector, alpha)) or Vector3.zero
                    r.AssemblyLinearVelocity = r.AssemblyLinearVelocity:Lerp(vel * playbackSpeed, 0.85)
                    
                    if smoothPos then
                        local posDiff = (smoothPos - r.Position)
                        r.AssemblyLinearVelocity = r.AssemblyLinearVelocity + posDiff * 0.2
                    end
                    
                    if fA.md then
                        local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
                        if moveDir.Magnitude > 0.01 then h:Move(moveDir, false) else h:Move(Vector3.zero) end
                    end
                end
            end
            
            -- ==== Rotation via AlignOrientation (Smooth) ====
            local isUserMoving = false
            local now = tick()
            if now - lastKeyCheck > KEY_CHECK_INTERVAL then
                cachedKeys = UserInputService:GetKeysPressed()
                lastKeyCheck = now
            end
            for _, k in pairs(cachedKeys) do
                if k.KeyCode == Enum.KeyCode.W or k.KeyCode == Enum.KeyCode.A or k.KeyCode == Enum.KeyCode.S or k.KeyCode == Enum.KeyCode.D then
                    isUserMoving = true
                    break
                end
            end
            
            if isUserMoving then
                h.AutoRotate = true
            elseif isCurrentlyClimbing or isCurrentlySwimming then
                h.AutoRotate = false
            elseif isSpin and isInAir then
                -- Let the Spin logic handle rotation in air
                h.AutoRotate = false
            else
                h.AutoRotate = false
                
                local targetRot = fA.rot or 0
                if fB and fB.rot then
                    -- Interpolate rotation correctly (handling 360 wrap)
                    local rotA = fA.rot or 0
                    local rotB = fB.rot or 0
                    local diff = (rotB - rotA + 180) % 360 - 180
                    targetRot = rotA + diff * alpha
                end
                
                if isMoonwalk and not isReversing then
                    targetRot = targetRot + 180
                end
                
                -- SHIFTLOCK DETECTION
                -- If velocity direction is significantly different from rotation direction, assume strafing/shiftlock
                local isStrafing = false
                if smoothVel and smoothVel.Magnitude > 2 then
                    local moveDir = Vector3.new(smoothVel.X, 0, smoothVel.Z).Unit
                    local lookDir = (CFrame.Angles(0, math.rad(targetRot), 0) * Vector3.new(0, 0, -1)).Unit
                    local dot = moveDir:Dot(lookDir)
                    if dot < 0.8 then -- Angle > ~37 degrees
                        isStrafing = true
                    end
                end
                
                -- Apply Rotation
                local currentCF = r.CFrame
                local targetCF = CFrame.new(currentCF.Position) * CFrame.Angles(0, math.rad(targetRot), 0)
                
                -- If strafing (Shiftlock), force exact rotation match
                -- If normal walking, allow slight smoothing
                local lerpFactor = isStrafing and 0.8 or 0.3
                
                r.CFrame = currentCF:Lerp(targetCF, lerpFactor)
            end
            
            -- (State handling already done at start of frame iteration)
            
            -- ==== Drift Correction ====
            if not isCurrentlyClimbing and not isCurrentlySwimming and smoothPos and skipSnapFrames <= 0 and not isTimeJump then
                local dist = (r.Position - smoothPos).Magnitude
                if dist > 10 then
                    r.CFrame = CFrame.new(r.Position:Lerp(smoothPos, 0.4)) * r.CFrame.Rotation
                elseif dist > 3 then
                    local dir = (smoothPos - r.Position).Unit
                    r.AssemblyLinearVelocity = r.AssemblyLinearVelocity + dir * (dist * 1.5)
                elseif dist > 0.5 then
                    local dir = (smoothPos - r.Position).Unit
                    r.AssemblyLinearVelocity = r.AssemblyLinearVelocity + dir * (dist * 0.8)
                end
            end
            
            -- ==== TOOL HANDLING ====
            -- Equip/Unequip tools based on recorded data
            UpdateToolEquip(char, fA.tool, fA.toolTip, fA.toolColor, fA.toolConfig)
        end
    end)
        
        if not success then
            -- print("[StarSpacePlayback] LOOP ERROR: " .. tostring(err))
            isPlaying = false
            if playbackConnection then playbackConnection:Disconnect() end
        end
    end)
    
    if UI and UI.Slide then
        UI.Slide("Playback", "Playing: " .. pathOrName)
    end
    -- print("[StarSpacePlayback] Playback started successfully.")
end

function _G.StarSpace.StopPlaybackLegacy(silent)
    -- This is a secondary/simplified version, redirect to main StopPlayback
    -- Keeping for backward compatibility but now silent-aware
    
    -- Early return if nothing is playing - no notification needed
    if not isPlaying and not playbackConnection then
        return
    end
    
    isPlaying = false
    if playbackConnection then playbackConnection:Disconnect() end
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if hum then 
        hum:Move(Vector3.zero) 
        hum.AutoRotate = true 
        hum.PlatformStand = false
    end
    
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = false
        
        -- Remove any playback constraints (AlignOrientation, etc.)
        local att = root:FindFirstChild("PlaybackAtt")
        if att then att:Destroy() end
        local ao = root:FindFirstChild("PlaybackAO")
        if ao then ao:Destroy() end
    end
    
    -- Only show notification if not silent (check both parameter and flag)
    local isSilent = silent or (_G.StarSpace and _G.StarSpace._silentStop)
    if not isSilent and UI and UI.Slide then
        UI.Slide("Playback", "Stopped")
    end
end

function _G.StarSpace.TogglePlayback()
    if isPlaying then
        isPaused = not isPaused
        
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if isPaused then
            -- Paused: Give full control back to user
            if hum then 
                hum:Move(Vector3.zero)
                hum.AutoRotate = true -- Enable user rotation
                hum:ChangeState(Enum.HumanoidStateType.Running) -- Reset to running state
            end
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                -- Remove any playback constraints
                local att = root:FindFirstChild("PlaybackAtt")
                if att then att:Destroy() end
                local ao = root:FindFirstChild("PlaybackAO")
                if ao then ao:Destroy() end
            end
            
            if UI and UI.Slide then
                UI.Slide("Playback", "Paused - You can move freely")
            end
        else
            -- Resumed: Check if player moved away from path
            if root and currentFrameData and #currentFrameData > 0 then
                local rPos = root.Position
                
                -- SMART RESUME: Find the nearest point on the path from current position
                local bestT, minDst, bestFrameIdx = FindNearestFrame(currentFrameData, rPos)
                
                -- ALWAYS sync time to the nearest point when resuming
                currentPlaybackTime = bestT
                lastFrameIndex = bestFrameIdx
                
                -- FORCE isTimeJump to be true on the next frame to prevent snapping
                lastPlaybackTime = currentPlaybackTime - 100 
                skipSnapFrames = 60 -- Allow 1s of smooth transition
                
                -- Find target frame position
                local targetFrame = currentFrameData[bestFrameIdx]
                local targetPos = targetFrame and (targetFrame.posVector or (targetFrame.pos and Vector3.new(targetFrame.pos.x, targetFrame.pos.y, targetFrame.pos.z)))
                
                if targetPos then
                    local dist = minDst
                    
                    -- SMART RESUME LOGIC (Matching Starship Core Commit)
                    if dist > 10 then
                        -- CASE 1: Too far (> 300 studs) -> Teleport
                        if dist > 300 then
                            if UI and UI.Slide then
                                UI.Slide("Smart Resume", string.format("Teleporting to path (%.0f studs)...", dist))
                            end
                            root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
                            task.wait(0.1)
                            isPaused = false
                            return
                        end

                        -- CASE 2: Medium distance (10-300 studs) -> Walk back naturally
                        if UI and UI.Slide then
                            UI.Slide("Resuming", string.format("Walking back to path (%.0f studs)...", dist))
                        end
                        
                        isPaused = true -- Keep playback paused while walking
                        root.Anchored = false
                        hum.AutoRotate = true
                        
                        local walkSpeed = hum.WalkSpeed
                        if walkSpeed < 16 then walkSpeed = 16 end
                        hum.WalkSpeed = walkSpeed
                        
                        task.spawn(function()
                            local moveStart = os.clock()
                            local maxWalkTime = math.min(dist / 10, 15) -- Max 15s timeout
                            
                            while isPlaying and isPaused do
                                local d = (root.Position - targetPos).Magnitude
                                if d <= 4 then break end -- Close enough
                                if os.clock() - moveStart > maxWalkTime then break end
                                
                                hum:MoveTo(targetPos)
                                task.wait(0.1)
                            end
                            
                            -- Stop walking and resume playback
                            hum:MoveTo(root.Position)
                            isPaused = false
                            
                            if UI and UI.Slide then
                                UI.Slide("Playback", "Resumed")
                            end
                        end)
                        
                        return
                    end
                end
            end
            
            -- Player is close to path or already synced - just resume
            isPaused = false
            if UI and UI.Slide then
                UI.Slide("Playback", "Resumed")
            end
        end
    end
end

function _G.StarSpace.PausePlayback()
    if isPlaying and not isPaused then
        isPaused = true
        
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if hum then 
            hum:Move(Vector3.zero)
            hum.AutoRotate = true
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            local att = root:FindFirstChild("PlaybackAtt")
            if att then att:Destroy() end
            local ao = root:FindFirstChild("PlaybackAO")
            if ao then ao:Destroy() end
        end
        
        if UI and UI.Slide then
            UI.Slide("Playback", "Paused")
        end
    end
end

function _G.StarSpace.ResumePlayback()
    if isPlaying and isPaused then
        -- Use the existing TogglePlayback logic for smart resume
        _G.StarSpace.TogglePlayback()
    end
end
