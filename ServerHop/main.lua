local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local ServerHop = {}

local CONFIG = {
    FileName = "server-hop-temp.json",
    MaxPages = 5,

    Age = {
        PointsPerMinute = 1,
        MaxPoints = 120
    },

    Players = {
        PointsPerEmptySlot = 0.5,
        MaxPoints = 50
    },

    Bonuses = {
        EmptyServer = 25,
        VeryLowPlayers = 15
    },

    VeryLowPlayerLimit = 3
}

local PlaceId = game.PlaceId
local LocalPlayer = Players.LocalPlayer
local CurrentJobId = game.JobId

local Visited = {}

local function loadVisited()
    local success, result = pcall(function()
        if not isfile(CONFIG.FileName) then
            return {}
        end

        return HttpService:JSONDecode(
            readfile(CONFIG.FileName)
        )
    end)

    if success and type(result) == "table" then
        Visited = result
    else
        Visited = {}
    end

    Visited[CurrentJobId] = true
end

local function saveVisited()
    pcall(function()
        writefile(
            CONFIG.FileName,
            HttpService:JSONEncode(Visited)
        )
    end)
end

local function getServers(cursor)
    local url =
        "https://games.roblox.com/v1/games/"
        .. PlaceId
        .. "/servers/Public?sortOrder=Asc&limit=100"

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

local function getServerAge(server)
    if server.created then
        local created = tonumber(server.created)

        if created then
            return math.max(
                0,
                os.time() - created
            )
        end
    end

    return 0
end

local function calculateScore(server)
    local playing = tonumber(server.playing) or 0
    local maxPlayers = tonumber(server.maxPlayers) or 0

    if maxPlayers <= 0 then
        return -math.huge
    end

    local freeSlots = math.max(
        0,
        maxPlayers - playing
    )

    local score = 0

    score += math.min(
        freeSlots * CONFIG.Players.PointsPerEmptySlot,
        CONFIG.Players.MaxPoints
    )

    if playing == 0 then
        score += CONFIG.Bonuses.EmptyServer
    elseif playing <= CONFIG.VeryLowPlayerLimit then
        score += CONFIG.Bonuses.VeryLowPlayers
    end

    local ageSeconds = getServerAge(server)
    local ageMinutes = ageSeconds / 60

    score += math.min(
        ageMinutes * CONFIG.Age.PointsPerMinute,
        CONFIG.Age.MaxPoints
    )

    return score
end

local function findBestServer()
    local bestServer = nil
    local bestScore = -math.huge

    local cursor = nil

    for page = 1, CONFIG.MaxPages do
        local data = getServers(cursor)

        if not data then
            break
        end

        for _, server in ipairs(data.data or {}) do
            local id = server.id

            local playing = tonumber(server.playing) or 0
            local maxPlayers = tonumber(server.maxPlayers) or 0

            local valid =
                id
                and id ~= CurrentJobId
                and not Visited[id]
                and maxPlayers > playing

            if valid then
                local score = calculateScore(server)

                if score > bestScore then
                    bestScore = score

                    bestServer = {
                        Id = id,
                        Playing = playing,
                        MaxPlayers = maxPlayers,
                        Score = score,
                        Age = getServerAge(server)
                    }
                end
            end
        end

        cursor = data.nextPageCursor

        if not cursor then
            break
        end
    end

    return bestServer
end

function ServerHop:GetBestServer()
    loadVisited()

    local server = findBestServer()

    return server
end

function ServerHop:Teleport()
    if not LocalPlayer then
        return false, "LocalPlayer não encontrado."
    end

    loadVisited()

    local server = findBestServer()

    if not server then
        return false, "Nenhum servidor disponível."
    end

    Visited[server.Id] = true
    saveVisited()

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

return ServerHop
