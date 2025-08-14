local RSGCore = exports['rsg-core']:GetCoreObject()

local Config = {
    DatabaseName = "notices",
    MaxNoticesPerPlayer = 30,
    NoticeTitleMaxLength = 50,
    NoticeDescMaxLength = 500,
    NoticeUrlMaxLength = 255,
    AllowedImageDomains = { 
        "cdn.discordapp.com",
        "media.discordapp.net",
        "i.imgur.com",
        "i.redd.it"
    }
}

local function wasSuccessful(result)
    return result and ((type(result) == "table" and result.affectedRows and result.affectedRows > 0) or
                      (type(result) == "number" and result > 0))
end


local function sanitizeUrl(url)
    if not url or url == "" then return nil end
    
    
    url = url:gsub("^%s+", ""):gsub("%s+$", "")
    
    
    if #url > Config.NoticeUrlMaxLength then 
        return nil 
    end
    
    
    if not url:match("^https?://[%w-_%.%?%.:/%+=&]+$") then
        return nil
    end
    
    return url
end


local function isAllowedImageUrl(url)
    if not url then return false end
    
    for _, domain in ipairs(Config.AllowedImageDomains) do
        if url:find(domain, 1, true) then
            return true
        end
    end
    
    return false
end


RegisterNetEvent("rsg:noticeBoard:openMenu")
AddEventHandler("rsg:noticeBoard:openMenu", function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute([[
        SELECT 
            n.id, n.title, n.description, n.url, n.citizenid,
            DATE_FORMAT(n.created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
            (SELECT charinfo FROM players WHERE citizenid = n.citizenid) AS author_info
        FROM ]] .. Config.DatabaseName .. [[ n
        ORDER BY n.created_at DESC
    ]], {}, function(results)
        local notices = {}
        local playerCitizenId = Player.PlayerData.citizenid

        for _, notice in ipairs(results or {}) do
            local authorName = "Unknown"
            if notice.author_info then
                local info = json.decode(notice.author_info)
                if info then authorName = (info.firstname or "?") .. " " .. (info.lastname or "") end
            end
            
           
            local isImage = isAllowedImageUrl(notice.url)
            
            notices[#notices+1] = {
                id = notice.id,
                title = notice.title,
                description = notice.description,
                url = notice.url,
                isImage = isImage, 
                authorName = authorName,
                created_at = notice.created_at,
                isCreator = notice.citizenid == playerCitizenId
            }
        end

        TriggerClientEvent("rsg:noticeBoard:openMenu", src, notices)
    end)
end)

RegisterNetEvent("rsg:noticeBoard:handleMenuSelection")
AddEventHandler("rsg:noticeBoard:handleMenuSelection", function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Player not found', type = 'error' })
        return
    end

    local action = data and data.action
    if action == "create" then
        if not data.title or data.title == "" or not data.description or data.description == "" then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Title and description are required', type = 'error' })
            return
        end

        local cleanUrl = sanitizeUrl(data.url)

        exports.oxmysql:execute('SELECT COUNT(*) as count FROM ' .. Config.DatabaseName .. ' WHERE citizenid = ?', {
            Player.PlayerData.citizenid
        }, function(result)
            local noticeCount = (result and result[1] and result[1].count) or 0
            if noticeCount >= Config.MaxNoticesPerPlayer then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = ('You have reached the maximum number of notices (%d).'):format(Config.MaxNoticesPerPlayer), type = 'error' })
                return
            end

            exports.oxmysql:insert('INSERT INTO ' .. Config.DatabaseName .. ' (citizenid, title, description, url, created_at) VALUES (?, ?, ?, ?, ?)', {
                Player.PlayerData.citizenid,
                data.title,
                data.description,
                cleanUrl,
                os.date('%Y-%m-%d %H:%M:%S')
            }, function(result2)
                if wasSuccessful(result2) then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Success', description = 'Notice posted', type = 'success' })
                else
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to post notice', type = 'error' })
                end
                TriggerClientEvent("rsg:noticeBoard:refresh", src) -- ask client to re-open menu
            end)
        end)

    elseif action == "edit" then
        if not data.title or data.title == "" or not data.description or data.description == "" then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Title and description are required', type = 'error' })
            return
        end

        local cleanUrl = sanitizeUrl(data.url)

        exports.oxmysql:single('SELECT citizenid FROM ' .. Config.DatabaseName .. ' WHERE id = ?', { data.id }, function(notice)
            if not notice then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Notice not found', type = 'error' })
                return
            end
            if notice.citizenid ~= Player.PlayerData.citizenid then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'You can only edit your own notices', type = 'error' })
                return
            end

            exports.oxmysql:execute('UPDATE ' .. Config.DatabaseName .. ' SET title = ?, description = ?, url = ? WHERE id = ?', {
                data.title, data.description, cleanUrl, data.id
            }, function(result2)
                if wasSuccessful(result2) then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Success', description = 'Notice updated', type = 'success' })
                else
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to update notice', type = 'error' })
                end
                TriggerClientEvent("rsg:noticeBoard:refresh", src)
            end)
        end)
    end
end)

RegisterNetEvent("rsg:noticeBoard:handleNoticeAction")
AddEventHandler("rsg:noticeBoard:handleNoticeAction", function(selection)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Player not found', type = 'error' })
        return
    end

    if selection.action == "remove" then
        exports.oxmysql:single('SELECT citizenid FROM ' .. Config.DatabaseName .. ' WHERE id = ?', { selection.id }, function(notice)
            if not notice then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Notice not found', type = 'error' })
                return
            end
            if notice.citizenid ~= Player.PlayerData.citizenid then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'You can only delete your own notices', type = 'error' })
                return
            end

            exports.oxmysql:execute('DELETE FROM ' .. Config.DatabaseName .. ' WHERE id = ?', { selection.id }, function(result2)
                if wasSuccessful(result2) then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Success', description = 'Notice deleted', type = 'success' })
                else
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to delete notice', type = 'error' })
                end
                TriggerClientEvent("rsg:noticeBoard:refresh", src)
            end)
        end)

    elseif selection.action == "removeAll" then
        exports.oxmysql:execute('DELETE FROM ' .. Config.DatabaseName .. ' WHERE citizenid = ?', { Player.PlayerData.citizenid }, function(result2)
            if wasSuccessful(result2) then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Success', description = 'All notices deleted', type = 'success' })
            else
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to delete all', type = 'error' })
            end
            TriggerClientEvent("rsg:noticeBoard:refresh", src)
        end)
    end
end)
