local function fmt_vec3(x, y, z)
    return ('vector3(%.3f, %.3f, %.3f)'):format(x, y, z)
end

RegisterCommand('coords', function()
    local coords = GetEntityCoords(PlayerPedId())
    SendNUIMessage({
        type = 'clipboard',
        data = fmt_vec3(coords.x, coords.y, coords.z)
    })
end)

local selecting = false
local hoverEntity = 0

local function vec3(x, y, z)
    return vector3(x + 0.0, y + 0.0, z + 0.0)
end

local function normalize(v)
    local mag = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if mag > 0.0 then
        return vec3(v.x / mag, v.y / mag, v.z / mag)
    end
    return vec3(0.0, 0.0, 0.0)
end

local function rotationToForward(rot)
    local radX = rot.x * math.pi / 180.0
    local radZ = rot.z * math.pi / 180.0
    local cosX = math.cos(radX)
    local sinX = math.sin(radX)
    local cosZ = math.cos(radZ)
    local sinZ = math.sin(radZ)
    return normalize(vec3(-sinZ * cosX, cosZ * cosX, sinX))
end

local function cross(a, b)
    return vec3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end

local function rayFromScreen(mx, my)
    local camPos = GetFinalRenderedCamCoord()
    local camRot = GetFinalRenderedCamRot(0)
    local forward = rotationToForward(camRot)

    local resX, resY = GetActiveScreenResolution()
    local nx = (mx / resX - 0.5) * 2.0
    local ny = (my / resY - 0.5) * 2.0

    local worldUp = vec3(0.0, 0.0, 1.0)
    local right = cross(forward, worldUp)
    local rightMag = math.sqrt(right.x * right.x + right.y * right.y + right.z * right.z)
    if rightMag < 0.001 then
        worldUp = vec3(0.0, 1.0, 0.0)
        right = cross(forward, worldUp)
    end
    right = normalize(right)
    local up = normalize(cross(right, forward))

    local fov = GetFinalRenderedCamFov()
    local scale = math.tan((fov * 0.5) * math.pi / 180.0)

    local dir = normalize(vec3(
        forward.x + right.x * nx * scale + up.x * ny * scale,
        forward.y + right.y * nx * scale + up.y * ny * scale,
        forward.z + right.z * nx * scale + up.z * ny * scale
    ))

    local start = camPos
    local finish = vec3(camPos.x + dir.x * 1000.0, camPos.y + dir.y * 1000.0, camPos.z + dir.z * 1000.0)
    return start, finish
end

local function raycastFromCursor(mx, my)
    local start, finish = rayFromScreen(mx, my)
    local handle = StartShapeTestRay(start.x, start.y, start.z, finish.x, finish.y, finish.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(handle)
    return hit == 1, entityHit, endCoords
end

local function entityLabel(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return '' end
    local et = GetEntityType(entity)
    if et == 0 then return '' end
    local model = GetEntityModel(entity)
    
    local modelName = GetEntityArchetypeName(entity)
    if modelName and modelName ~= '' then
        return modelName
    end
    
    if et == 2 then
        local dn = GetDisplayNameFromVehicleModel(model)
        if dn and dn ~= '' then
            local label = GetLabelText(dn)
            if label and label ~= '' and label ~= 'NULL' then return label end
            return dn
        end
        return ('Vehicle_0x%08X'):format(model)
    elseif et == 1 then
        return ('Ped_0x%08X'):format(model)
    elseif et == 3 then
        return ('0x%08X'):format(model)
    end
    return ('Entity_0x%08X'):format(model)
end

local function drawCenteredText(text)
    local posX = 0.5
    local posY = 0.92
    local scale = 0.45
    local font = 4
    
    SetTextFont(font)
    SetTextProportional(1)
    SetTextScale(0.0, scale)
    
    BeginTextCommandWidth('STRING')
    AddTextComponentSubstringPlayerName(text)
    local textWidth = EndTextCommandGetWidth(true)
    
    local textHeight = GetTextScaleHeight(scale, font)
    
    local paddingX = 0.010
    local paddingY = 0.009
    local boxWidth = textWidth + (paddingX * 2)
    local boxHeight = textHeight + (paddingY * 2)
    
    DrawRect(posX, posY, boxWidth + 0.004, boxHeight + 0.004, 0, 123, 255, 255)
    DrawRect(posX, posY, boxWidth + 0.002, boxHeight + 0.002, 0, 0, 0, 255)
    DrawRect(posX, posY, boxWidth, boxHeight, 0, 0, 0, 200)
    
    SetTextFont(font)
    SetTextProportional(1)
    SetTextScale(0.0, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(2, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(posX, posY - 0.015)
end

local function setOutline(entity, enabled)
    if entity ~= 0 and DoesEntityExist(entity) then
        SetEntityDrawOutline(entity, enabled)
        if enabled then SetEntityDrawOutlineColor(0, 123, 255, 255) end
    end
end

CreateThread(function()
    while true do
        if selecting then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 91, true)

            local resX, resY = GetActiveScreenResolution()
            local mx, my = resX * 0.5, resY * 0.5
            local hit, entity, endCoords = raycastFromCursor(mx, my)

            if hit and entity ~= 0 and DoesEntityExist(entity) then
                if hoverEntity ~= entity then
                    if hoverEntity ~= 0 and DoesEntityExist(hoverEntity) then
                        setOutline(hoverEntity, false)
                    end
                    hoverEntity = entity
                end
                setOutline(entity, true)

                local name = entityLabel(entity)
                if name ~= '' then
                    drawCenteredText(name)
                end

                local coords = GetEntityCoords(entity)
                DrawMarker(2, coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.25, 0.25, 0.25, 0, 123, 255, 140, false, false, 2, false, nil, nil, false)

                if IsDisabledControlJustPressed(0, 24) then
                    SendNUIMessage({ type = 'clipboard', data = fmt_vec3(coords.x, coords.y, coords.z) })
                    if hoverEntity ~= 0 and DoesEntityExist(hoverEntity) then
                        setOutline(hoverEntity, false)
                    end
                    hoverEntity = 0
                end
            else
                if hoverEntity ~= 0 then
                    if DoesEntityExist(hoverEntity) then
                        setOutline(hoverEntity, false)
                    end
                    hoverEntity = 0
                end
            end

            if IsControlJustPressed(0, 73) then
                selecting = false
                if hoverEntity ~= 0 and DoesEntityExist(hoverEntity) then
                    setOutline(hoverEntity, false)
                end
                hoverEntity = 0
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterCommand('camcoords', function()
    if selecting then
        selecting = false
        if hoverEntity ~= 0 and DoesEntityExist(hoverEntity) then
            setOutline(hoverEntity, false)
        end
        hoverEntity = 0
        return
    end
    selecting = true
    hoverEntity = 0
end)