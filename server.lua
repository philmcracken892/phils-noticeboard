local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Config = Config or { DatabaseName = "notices", MaxNoticesPerPlayer = 3 }

if not Config then
    print("[phils-noticeboard] WARNING: Config not loaded, using fallback values")
end

local function wasSuccessful(result)
    return result and (type(result) == "table" and result.affectedRows and result.affectedRows > 0) or (type(result) == "number" and result > 0)
end

RegisterNetEvent("rsg:noticeBoard:openMenu")
AddEventHandler("rsg:noticeBoard:openMenu", function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute([[
        SELECT
            n.id, n.title, n.description, n.citizenid,
            DATE_FORMAT(n.created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
            (SELECT charinfo FROM players WHERE citizenid = n.citizenid) AS author_info
        FROM ]] .. Config.DatabaseName .. [[ n
        ORDER BY n.created_at DESC
    ]], {}, function(results)
        local notices = {}
        local playerCitizenId = Player.PlayerData.citizenid

        for _, notice in ipairs(results) do
            local authorName = locale('sv_lang_1')
            if notice.author_info then
                local authorInfo = json.decode(notice.author_info)
                authorName = authorInfo.firstname .. " " .. authorInfo.lastname
            end

            table.insert(notices, {
                id = notice.id,
                title = notice.title,
                description = notice.description,
                authorName = authorName,
                created_at = notice.created_at,
                isCreator = notice.citizenid == playerCitizenId
            })
        end

        TriggerClientEvent("rsg:noticeBoard:openMenu", src, notices)
    end)
end)

RegisterNetEvent("rsg:noticeBoard:handleMenuSelection")
AddEventHandler("rsg:noticeBoard:handleMenuSelection", function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_2'),
            description = locale('sv_lang_3'),
            type = 'error'
        })
        return
    end

    if data.action == "create" then
        if not data.title or data.title == "" or not data.description or data.description == "" then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_lang_2'),
                description = locale('sv_lang_4'),
                type = 'error'
            })
            return
        end

        exports.oxmysql:execute('SELECT COUNT(*) as count FROM ' .. Config.DatabaseName .. ' WHERE citizenid = ?', {
            Player.PlayerData.citizenid
        }, function(result)
            local noticeCount = result[1].count or 0
            if noticeCount >= Config.MaxNoticesPerPlayer then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('sv_lang_2'),
                    description = locale('sv_lang_5') .. Config.MaxNoticesPerPlayer .. ').',
                    type = 'error'
                })
                return
            end

            exports.oxmysql:insert('INSERT INTO ' .. Config.DatabaseName .. ' (citizenid, title, description, created_at) VALUES (?, ?, ?, ?)', {
                Player.PlayerData.citizenid,
                data.title,
                data.description,
                os.date('%Y-%m-%d %H:%M:%S')
            }, function(result)
                if wasSuccessful(result) then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = locale('sv_lang_6'),
                        description = locale('sv_lang_7'),
                        type = 'success'
                    })
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = locale('sv_lang_2'),
                        description = locale('sv_lang_8'),
                        type = 'error'
                    })
                end
            end)
        end)
    elseif data.action == "edit" then
        if not data.title or data.title == "" or not data.description or data.description == "" then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_lang_2'),
                description = locale('sv_lang_4'),
                type = 'error'
            })
            return
        end

        exports.oxmysql:single('SELECT citizenid FROM ' .. Config.DatabaseName .. ' WHERE id = ?', {data.id}, function(notice)
            if not notice then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('sv_lang_2'),
                    description = locale('sv_lang_9'),
                    type = 'error'
                })
                return
            end

            if notice.citizenid ~= Player.PlayerData.citizenid then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('sv_lang_2'),
                    description = locale('sv_lang_10'),
                    type = 'error'
                })
                return
            end

            exports.oxmysql:execute('UPDATE ' .. Config.DatabaseName .. ' SET title = ?, description = ? WHERE id = ?', {
                data.title,
                data.description,
                data.id
            }, function(result)
                if wasSuccessful(result) then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = locale('sv_lang_6'),
                        description = locale('sv_lang_11'),
                        type = 'success'
                    })
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = locale('sv_lang_2'),
                        description = locale('sv_lang_12'),
                        type = 'error'
                    })
                end
            end)
        end)
    end
end)

RegisterNetEvent("rsg:noticeBoard:handleNoticeAction")
AddEventHandler("rsg:noticeBoard:handleNoticeAction", function(selection)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_2'),
            description = locale('sv_lang_3'),
            type = 'error'
        })
        return
    end

    if selection.action == "remove" then
        exports.oxmysql:single('SELECT citizenid FROM ' .. Config.DatabaseName .. ' WHERE id = ?', {selection.id}, function(notice)
            if not notice then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('sv_lang_2'),
                    description = locale('sv_lang_9'),
                    type = 'error'
                })
                return
            end

            if notice.citizenid ~= Player.PlayerData.citizenid then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('sv_lang_2'),
                    description = locale('sv_lang_13'),
                    type = 'error'
                })
                return
            end

            exports.oxmysql:execute('DELETE FROM ' .. Config.DatabaseName .. ' WHERE id = ?', {
                selection.id
            }, function(result)
                if wasSuccessful(result) then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = locale('sv_lang_6'),
                        description = locale('sv_lang_14'),
                        type = 'success'
                    })
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = locale('sv_lang_2'),
                        description = locale('sv_lang_15'),
                        type = 'error'
                    })
                end
            end)
        end)
    elseif selection.action == "removeAll" then
        exports.oxmysql:execute('SELECT COUNT(*) as count FROM ' .. Config.DatabaseName .. ' WHERE citizenid = ?', {
            Player.PlayerData.citizenid
        }, function(result)
            local noticeCount = result[1].count or 0
            if noticeCount == 0 then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('sv_lang_2'),
                    description = locale('sv_lang_16'),
                    type = 'error'
                })
                return
            end

            exports.oxmysql:execute('DELETE FROM ' .. Config.DatabaseName .. ' WHERE citizenid = ?', {
                Player.PlayerData.citizenid
            }, function(result)
                if wasSuccessful(result) then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = locale('sv_lang_6'),
                        description = locale('sv_lang_17'),
                        type = 'success'
                    })
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = locale('sv_lang_2'),
                        description = locale('sv_lang_18'),
                        type = 'error'
                    })
                end
            end)
        end)
    end
end)
