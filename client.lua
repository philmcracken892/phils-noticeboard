local RSGCore = exports['rsg-core']:GetCoreObject()


function IsValidImageURL(url)
    if not url or url == "" then
        return false
    end
    
    if not string.match(url, "^https?://") then
        return false
    end
    
    local imageExtensions = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}
    local isDiscordCDN = string.match(url, "cdn%.discordapp%.com") or string.match(url, "media%.discordapp%.net")
    
    if isDiscordCDN then
        return true
    end
    
    for _, ext in ipairs(imageExtensions) do
        if string.match(string.lower(url), ext) then
            return true
        end
    end
    
    return false
end


for _, location in ipairs(Config.noticeboardLocations) do
    exports.ox_target:addSphereZone({
        coords = location.coords,
        radius = location.radius,
        debug = false, 
        drawSprite = true, 
        options = {
            {
                label = 'Open Noticeboard',
                icon = 'fas fa-clipboard', 
                distance = 2.0, 
                onSelect = function()
                    TriggerServerEvent("rsg:noticeBoard:openMenu")
                end
            }
        }
    })
end

RegisterCommand("noticeboard", function()
    TriggerServerEvent("rsg:noticeBoard:openMenu")
end, false)

RegisterNetEvent("rsg:noticeBoard:openMenu")
AddEventHandler("rsg:noticeBoard:openMenu", function(notices)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', notices = notices })
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    cb(true)
end)

RegisterNetEvent("rsg:noticeBoard:refresh")
AddEventHandler("rsg:noticeBoard:refresh", function()
    TriggerServerEvent("rsg:noticeBoard:openMenu")
end)

RegisterNUICallback('createNotice', function(data, cb)
    TriggerServerEvent("rsg:noticeBoard:handleMenuSelection", {
        action = "create",
        title = data.title, description = data.description, url = data.url
    })
    cb(true)
end)

RegisterNUICallback('editNotice', function(data, cb)
    TriggerServerEvent("rsg:noticeBoard:handleMenuSelection", {
        action = "edit",
        id = data.id, title = data.title, description = data.description, url = data.url
    })
    cb(true)
end)

RegisterNUICallback('deleteNotice', function(data, cb)
    TriggerServerEvent("rsg:noticeBoard:handleNoticeAction", { action = "remove", id = data.id })
    cb(true)
end)

RegisterNUICallback('deleteAll', function(_, cb)
    TriggerServerEvent("rsg:noticeBoard:handleNoticeAction", { action = "removeAll" })
    cb(true)
end)
