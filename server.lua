local RSGCore = exports['rsg-core']:GetCoreObject()

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
    
    local imageExtensions = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}
    
    if url:find("cdn.discordapp.com", 1, true) or url:find("media.discordapp.net", 1, true) then
        return true
    end
    
    for _, domain in ipairs(Config.AllowedImageDomains) do
        if url:find(domain, 1, true) then
            for _, ext in ipairs(imageExtensions) do
                if url:lower():find(ext, -#ext, true) then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Function to clean up expired notices
local function cleanupExpiredNotices()
    if Config.NoticeExpiryDays <= 0 then
        return -- Expiry disabled if set to 0 or negative
    end
    
    local expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() - (Config.NoticeExpiryDays * 24 * 60 * 60))
    local deleteExpiredQuery = 'DELETE FROM ' .. Config.DatabaseName .. ' WHERE created_at < ?'
    
    exports.oxmysql:execute(deleteExpiredQuery, { expiryDate }, function(result, err)
        if err then
            print("[NoticeBoard] Error cleaning up expired notices: " .. tostring(err))
        else
            local deletedCount = (result and result.affectedRows) or 0
            if deletedCount > 0 then
                print("[NoticeBoard] Cleaned up " .. deletedCount .. " expired notices older than " .. Config.NoticeExpiryDays .. " days")
            end
        end
    end)
end

-- Run cleanup on resource start
CreateThread(function()
    Wait(5000) -- Wait 5 seconds after resource start
    cleanupExpiredNotices()
end)

-- Run cleanup every hour
CreateThread(function()
    while true do
        Wait(3600000) -- Wait 1 hour (3600000 milliseconds)
        cleanupExpiredNotices()
    end
end)

local function SendToDiscord(name, message, url)
    if not Config.WebhookURL or Config.WebhookURL == "YOUR_DISCORD_WEBHOOK_URL_HERE" then
        return
    end
    
    local connect = {
        {
            ["color"] = 15158332,
            ["title"] = "**".. name .."**",
            ["description"] = message,
            ["footer"] = {
                ["text"] = "Date : " .. os.date("%Y-%m-%d %X"),
            },
        }
    }
    
    if url and isAllowedImageUrl(url) then
        connect[1]["image"] = {
            ["url"] = url
        }
    end
    
    PerformHttpRequest(
        Config.WebhookURL,
        function(err, text, headers)
            if err ~= 200 then
                -- Error handling
            else
                -- Success
            end
        end,
        'POST',
        json.encode({
            username = "Notice Board",
            embeds = connect,
            avatar_url = "https://media.discordapp.net/attachments/1163182151391527053/1317888980876005417/image-removebg-preview_4.png"
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

RegisterNetEvent("rsg:noticeBoard:openMenu")
AddEventHandler("rsg:noticeBoard:openMenu", function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then 
        TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Player not found', type = 'error' })
        return 
    end
    local playerCitizenId = Player.PlayerData.citizenid
    
    -- Clean up expired notices before fetching
    cleanupExpiredNotices()
    
    -- Modified query to only fetch non-expired notices
    local selectQuery
    if Config.NoticeExpiryDays > 0 then
        local expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() - (Config.NoticeExpiryDays * 24 * 60 * 60))
        selectQuery = [[
            SELECT 
                n.id, n.title, n.description, n.url, n.citizenid,
                DATE_FORMAT(n.created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
                (SELECT charinfo FROM players WHERE citizenid = n.citizenid) AS author_info
            FROM ]] .. Config.DatabaseName .. [[ n
            WHERE n.created_at >= ?
            ORDER BY n.created_at DESC
        ]]
        
        exports.oxmysql:execute(selectQuery, { expiryDate }, function(results, err)
            if err then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to fetch notices: ' .. tostring(err), type = 'error' })
                return
            end
            
            processNoticeResults(src, results, playerCitizenId)
        end)
    else
        -- No expiry, fetch all notices
        selectQuery = [[
            SELECT 
                n.id, n.title, n.description, n.url, n.citizenid,
                DATE_FORMAT(n.created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
                (SELECT charinfo FROM players WHERE citizenid = n.citizenid) AS author_info
            FROM ]] .. Config.DatabaseName .. [[ n
            ORDER BY n.created_at DESC
        ]]
        
        exports.oxmysql:execute(selectQuery, {}, function(results, err)
            if err then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to fetch notices: ' .. tostring(err), type = 'error' })
                return
            end
            
            processNoticeResults(src, results, playerCitizenId)
        end)
    end
end)

-- Helper function to process notice results
function processNoticeResults(src, results, playerCitizenId)
    local notices = {}
    
    if #results == 0 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Noticeboard', description = 'No notices available. Create a new one!', type = 'inform' })
    end

    for i, notice in ipairs(results or {}) do
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
end

-- Add a command for admins to manually clean up expired notices
RegisterCommand("cleanupnotices", function(source, args, rawCommand)
    local src = source
    if src == 0 then -- Console command
        cleanupExpiredNotices()
        print("[NoticeBoard] Manual cleanup triggered from console")
    else
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player and RSGCore.Functions.HasPermission(src, "admin") then
            cleanupExpiredNotices()
            TriggerClientEvent('ox_lib:notify', src, { title = 'Notice Board', description = 'Expired notices cleanup triggered', type = 'success' })
        else
            TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'You do not have permission to use this command', type = 'error' })
        end
    end
end, false)

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
        }, function(result, err)
            if err then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to check notice count', type = 'error' })
                return
            end

            local noticeCount = (result and result[1] and result[1].count) or 0
            if noticeCount >= Config.MaxNoticesPerPlayer then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = ('You have reached the maximum number of notices (%d).'):format(Config.MaxNoticesPerPlayer), type = 'error' })
                return
            end

            local insertQuery = 'INSERT INTO ' .. Config.DatabaseName .. ' (citizenid, title, description, url, created_at) VALUES (?, ?, ?, ?, ?)'
           
            exports.oxmysql:insert(insertQuery, {
                Player.PlayerData.citizenid,
                data.title,
                data.description,
                cleanUrl,
                os.date('%Y-%m-%d %H:%M:%S')
            }, function(result2, err)
                if err then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to post notice: ' .. tostring(err), type = 'error' })
                    return
                end

                if wasSuccessful(result2) then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Success', description = 'Notice posted', type = 'success' })
                    
                    local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                    local discordMessage = string.format(
                        "**New Notice Posted!**\n\n" ..
                        "**Player:** %s\n" ..
                        "**Title:** %s\n" ..
                        "**Description:** %s",
                        playerName,
                        data.title,
                        data.description
                    )
                    SendToDiscord("Notice Board - New Post", discordMessage, cleanUrl)
                else
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to post notice', type = 'error' })
                end
                TriggerClientEvent("rsg:noticeBoard:refresh", src)
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

            local updateQuery = 'UPDATE ' .. Config.DatabaseName .. ' SET title = ?, description = ?, url = ? WHERE id = ?'
           
            exports.oxmysql:execute(updateQuery, {
                data.title, data.description, cleanUrl, data.id
            }, function(result2, err)
                if err then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to update notice: ' .. tostring(err), type = 'error' })
                    return
                end

                if wasSuccessful(result2) then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Success', description = 'Notice updated', type = 'success' })
                    
                    local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                    local discordMessage = string.format(
                        "**Notice Updated!**\n\n" ..
                        "**Player:** %s\n" ..
                        "**Title:** %s\n" ..
                        "**Description:** %s",
                        playerName,
                        data.title,
                        data.description
                    )
                    SendToDiscord("Notice Board - Notice Updated", discordMessage, cleanUrl)
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
        local selectQuery = 'SELECT citizenid, title, description, url FROM ' .. Config.DatabaseName .. ' WHERE id = ?'
        
        exports.oxmysql:single(selectQuery, { selection.id }, function(notice)
            if not notice then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Notice not found', type = 'error' })
                return
            end
            
            if notice.citizenid ~= Player.PlayerData.citizenid then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'You can only delete your own notices', type = 'error' })
                return
            end

            local deleteQuery = 'DELETE FROM ' .. Config.DatabaseName .. ' WHERE id = ?'
            
            exports.oxmysql:execute(deleteQuery, { selection.id }, function(result2, err)
                if err then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to delete notice: ' .. tostring(err), type = 'error' })
                    return
                end

                if wasSuccessful(result2) then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Success', description = 'Notice deleted', type = 'success' })
                    
                    local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                    local discordMessage = string.format(
                        "**Notice Deleted!**\n\n" ..
                        "**Player:** %s\n" ..
                        "**Deleted Title:** %s\n" ..
                        "**Deleted Description:** %s",
                        playerName,
                        notice.title or "Unknown",
                        notice.description or "Unknown"
                    )
                    SendToDiscord("Notice Board - Notice Deleted", discordMessage, notice.url)
                else
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to delete notice', type = 'error' })
                end
                TriggerClientEvent("rsg:noticeBoard:refresh", src)
            end)
        end)

    elseif selection.action == "removeAll" then
        local countQuery = 'SELECT COUNT(*) as count FROM ' .. Config.DatabaseName .. ' WHERE citizenid = ?'
        
        exports.oxmysql:single(countQuery, { Player.PlayerData.citizenid }, function(countResult)
            local noticeCount = (countResult and countResult.count) or 0
            
            local deleteQuery = 'DELETE FROM ' .. Config.DatabaseName .. ' WHERE citizenid = ?'
            
            exports.oxmysql:execute(deleteQuery, { Player.PlayerData.citizenid }, function(result2, err)
                if err then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to delete all notices: ' .. tostring(err), type = 'error' })
                    return
                end

                if wasSuccessful(result2) then
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Success', description = 'All notices deleted', type = 'success' })
                    
                    if noticeCount > 0 then
                        local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                        local discordMessage = string.format(
                            "**All Notices Deleted!**\n\n" ..
                            "**Player:** %s\n" ..
                            "**Deleted Count:** %d notices",
                            playerName,
                            noticeCount
                        )
                        SendToDiscord("Notice Board - All Notices Deleted", discordMessage, nil)
                    end
                else
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to delete all', type = 'error' })
                end
                TriggerClientEvent("rsg:noticeBoard:refresh", src)
            end)
        end)
    end
end)
