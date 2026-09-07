local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local ServerHop = {}

local CONFIG = {
    FileName = "server-hop-temp.json",
    MaxPages = 8,
    MaxResults = 100,
    RequestDelay = 0.15,

    Min = {
        EmptySlotWeight = 3,
        PlayerWeight = -4,
        EmptyBonus = 40,
        LowPlayerBonus = 25
    },

    Max = {
        PlayerWeight = 8,
        OccupancyWeight = 5,
        FullnessBonus = 35
    }
}

local PlaceId = game.PlaceId
local LocalPlayer = Players.LocalPlayer
local CurrentJobId = game.JobId

local Visited = {}
local BlockedPlaces = {}

local function loadData()
    local success, data = pcall(function()
        if not isfile(CONFIG.FileName) then
            return {}
        end

        return HttpService:JSONDecode(readfile(CONFIG.FileName))
    end)

    if success and type(data) == "table" then
        Visited = data.Visited or {}
        BlockedPlaces = data.BlockedPlaces or {}
    end

    Visited[CurrentJobId] = true
end

local function saveData()
    pcall(function()
        writefile(
            CONFIG.FileName,
            HttpService:JSONEncode({
                Visited = Visited,
                BlockedPlaces = BlockedPlaces
            })
        )
    end)
end

local function request(cursor)
    local url =
        "https://games.roblox.com/v1/games/"
        .. PlaceId
        .. "/servers/Public?sortOrder=Asc&limit="
        .. CONFIG.MaxResults

    if cursor then
        url ..= "&cursor=" .. HttpService:UrlEncode(cursor)
    end

    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        return nil
    end

    local decodeSuccess, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)

    if not decodeSuccess or type(data) ~= "table" then
        return nil
    end

    return data
end

local function getScore(server, mode)
    local playing = tonumber(server.playing) or 0
    local maxPlayers = tonumber(server.maxPlayers) or 0

    if maxPlayers <= 0 then
        return -math.huge
    end

    local freeSlots = maxPlayers - playing
    local occupancy = playing / maxPlayers

    local score = 0

    if mode == "Min" then
        score += freeSlots * CONFIG.Min.EmptySlotWeight
        score += playing * CONFIG.Min.PlayerWeight

        if playing == 0 then
            score += CONFIG.Min.EmptyBonus
        elseif playing <= 3 then
            score += CONFIG.Min.LowPlayerBonus
        end
    elseif mode == "Max" then
        score += playing * CONFIG.Max.PlayerWeight
        score += occupancy * 100 * CONFIG.Max.OccupancyWeight

        if playing == maxPlayers then
            score += CONFIG.Max.FullnessBonus
        end
    end

    return score
end

local function collectServers()
    local servers = {}
    local cursor = nil

    for page = 1, CONFIG.MaxPages do
        local data = request(cursor)

        if not data then
            break
        end

        for _, server in ipairs(data.data or {}) do
            local id = server.id
            local playing = tonumber(server.playing) or 0
            local maxPlayers = tonumber(server.maxPlayers) or 0

            if id
                and id ~= CurrentJobId
                and not Visited[id]
                and not BlockedPlaces[PlaceId]
                and maxPlayers > playing then

                servers[#servers + 1] = {
                    Id = id,
                    Playing = playing,
                    MaxPlayers = maxPlayers,
                    FreeSlots = maxPlayers - playing
                }
            end
        end

        cursor = data.nextPageCursor

        if not cursor then
            break
        end

        task.wait(CONFIG.RequestDelay)
    end

    return servers
end

function ServerHop:GetList(mode)
    loadData()

    mode = tostring(mode or "Min")

    if mode ~= "Min" and mode ~= "Max" then
        return {}
    end

    local servers = collectServers()

    for _, server in ipairs(servers) do
        server.Score = getScore(server, mode)
    end

    table.sort(servers, function(a, b)
        return a.Score > b.Score
    end)

    return servers
end

function ServerHop:Teleport(mode)
    mode = tostring(mode or "Min")

    local list = self:GetList(mode)

    if #list == 0 then
        return false, "Nenhum servidor disponível."
    end

    local server = list[1]

    Visited[server.Id] = true
    saveData()

    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            PlaceId,
            server.Id,
            LocalPlayer
        )
    end)

    if not success then
        return false, err
    end

    return true, server
end

function ServerHop:Delete(placeId)
    placeId = tonumber(placeId)

    if not placeId then
        return false, "PlaceId inválido."
    end

    BlockedPlaces[placeId] = true
    saveData()

    return true
end

function ServerHop:ClearDelete(placeId)
    placeId = tonumber(placeId)

    if not placeId then
        return false
    end

    BlockedPlaces[placeId] = nil
    saveData()

    return true
end

function ServerHop:ClearVisited()
    Visited = {
        [CurrentJobId] = true
    }

    saveData()

    return true
end

function ServerHop:GetVisited()
    loadData()

    local result = {}

    for jobId in pairs(Visited) do
        result[#result + 1] = jobId
    end

    return result
end

return ServerHop
