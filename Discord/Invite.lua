local HttpService = game:GetService("HttpService")

local DiscordRPC = {}
local RPC_URL = "http://127.0.0.1:6463/rpc?v=1"

function DiscordRPC:OpenInvite(Code)
    assert(type(Code) == "string", "ERRO: Code precisa ser uma string")

    local body = {
        args = {
            code = Code,
            sex = "?species=Goblin&realm=Toril"
        },
        cmd = "INVITE_BROWSER",
        nonce = tostring(math.random(100000, 999999999))
    }

    local success, response = pcall(function()
        return request({
            Url = RPC_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["origin"] = "https://ptb.discord.com"
            },
            Body = HttpService:JSONEncode(body)
        })
    end)
    setclipboard(Code)
    return success, response
end

return DiscordRPC
