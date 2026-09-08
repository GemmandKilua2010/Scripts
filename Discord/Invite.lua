local HttpService = game:GetService("HttpService")

local DiscordRPC = {}
local RPC_URL = "http://127.0.0.1:6463/rpc?v=1"

function DiscordRPC:OpenInvite(Invite)
    assert(type(Invite) == "string", "ERRO: Invite precisa ser uma string")

    local Code = Invite:match("discord%.gg/([%w%-_]+)") or Invite
    local Body = {
        args = {
            code = Code
        },
        cmd = "INVITE_BROWSER",
        nonce = tostring(math.random(100000, 999999999))
    }

    local Success, Response = pcall(function()
        return request({
            Url = RPC_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["origin"] = "https://discord.com"
            },
            Body = HttpService:JSONEncode(Body)
        })
    end)

    if not Success then
        warn("Discord RPC:", Response)
        return false, Response
    end

    setclipboard("https://discord.gg/" .. Code)
    return true, Response
end
return DiscordRPC
