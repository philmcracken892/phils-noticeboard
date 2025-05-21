local RSGCore = exports['rsg-core']:GetCoreObject()

local function formatDateTime(datetime)
    if type(datetime) == "number" then
        datetime = os.date("%Y-%m-%d %H:%M:%S", datetime)
    end

    local date, time = datetime:match("(%d+%-%d+%-%d+) (%d+:%d+:%d+)")
    if not date or not time then
        return datetime 
    end

    local year, month, day = date:match("(%d+)%-(%d+)%-(%d+)")
    month, day, year = tonumber(month), tonumber(day), tonumber(year)

    local hour, minute = time:match("(%d+):(%d+):%d+")
    hour, minute = tonumber(hour), tonumber(minute)

    local period = hour >= 12 and "PM" or "AM"
    hour = hour % 12
    if hour == 0 then hour = 12 end

    return string.format("%02d/%02d/%04d %02d:%02d %s", month, day, year, hour, minute, period)
end

RegisterCommand("noticeboard", function()
    TriggerServerEvent("rsg:noticeBoard:openMenu")
end, false)

RegisterNetEvent("rsg:noticeBoard:openMenu")
AddEventHandler("rsg:noticeBoard:openMenu", function(notices)
    local options = {
        {
            title = 'Post New Notice',
            description = 'Create a new notice for the board',
            onSelect = function()
                TriggerEvent('rsg:noticeBoard:createNotice')
            end
        },
        {
            title = 'View Notices',
            description = 'Browse all notices on the board',
            onSelect = function()
                TriggerEvent('rsg:noticeBoard:viewNotices', notices)
            end
        }
    }

    lib.registerContext({
        id = 'notice_main_menu',
        title = 'Notice Board',
        options = options
    })

    lib.showContext('notice_main_menu')
end)

RegisterNetEvent("rsg:noticeBoard:createNotice")
AddEventHandler("rsg:noticeBoard:createNotice", function()
    local input = lib.inputDialog('Post Notice', {
        {
            type = 'input',
            label = 'Title',
            required = true,
            max = 50
        },
        {
            type = 'textarea',
            label = 'Description',
            required = true,
            max = 500
        }
    })

    if input then
        TriggerServerEvent("rsg:noticeBoard:handleMenuSelection", {
            action = "create",
            title = input[1],
            description = input[2]
        })
    end
end)

RegisterNetEvent("rsg:noticeBoard:viewNotices")
AddEventHandler("rsg:noticeBoard:viewNotices", function(notices)
    local options = {}
    local hasNotices = false

    for _, notice in ipairs(notices) do
        local formattedDateTime = formatDateTime(notice.created_at)
        local description = string.format(
            "%s\nPosted by: %s\nPosted on: %s",
            notice.description,
            notice.authorName,
            formattedDateTime
        )

        local option = {
            title = notice.title,
            description = description
        }

        if notice.isCreator then
            hasNotices = true
            option.onSelect = function()
                TriggerEvent('rsg:noticeBoard:handleNoticeAction', notice)
            end
        end

        table.insert(options, option)
    end

    lib.registerContext({
        id = 'notice_listings',
        title = 'Notice Board',
        options = options
    })

    lib.showContext('notice_listings')
end)

RegisterNetEvent("rsg:noticeBoard:handleNoticeAction")
AddEventHandler("rsg:noticeBoard:handleNoticeAction", function(notice)
    local options = {
        {
            title = 'Edit Notice',
            description = 'Modify the title or description of this notice',
            onSelect = function()
                TriggerEvent('rsg:noticeBoard:editNotice', notice)
            end
        },
        {
            title = 'Delete Notice',
            description = 'Permanently delete this notice from the board',
            onSelect = function()
                TriggerEvent('rsg:noticeBoard:removeNotice', notice)
            end
        },
        {
            title = 'Delete All Notices',
            description = 'Permanently delete all your notices from the board',
            onSelect = function()
                TriggerEvent('rsg:noticeBoard:removeAllNotices')
            end
        }
    }

    lib.registerContext({
        id = 'notice_actions',
        title = 'Notice Actions',
        menu = 'notice_listings',
        options = options
    })

    lib.showContext('notice_actions')
end)

RegisterNetEvent("rsg:noticeBoard:editNotice")
AddEventHandler("rsg:noticeBoard:editNotice", function(notice)
    local input = lib.inputDialog('Edit Notice', {
        {
            type = 'input',
            label = 'Title',
            required = true,
            max = 50,
            default = notice.title
        },
        {
            type = 'textarea',
            label = 'Description',
            required = true,
            max = 500,
            default = notice.description
        }
    })

    if input then
        TriggerServerEvent("rsg:noticeBoard:handleMenuSelection", {
            action = "edit",
            id = notice.id,
            title = input[1],
            description = input[2]
        })
    end
end)

RegisterNetEvent("rsg:noticeBoard:removeNotice")
AddEventHandler("rsg:noticeBoard:removeNotice", function(notice)
    local alert = lib.alertDialog({
        header = 'Delete Notice',
        content = 'Are you sure you want to permanently delete this notice?',
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        TriggerServerEvent("rsg:noticeBoard:handleNoticeAction", {
            action = "remove",
            id = notice.id
        })
    end
end)

RegisterNetEvent("rsg:noticeBoard:removeAllNotices")
AddEventHandler("rsg:noticeBoard:removeAllNotices", function()
    local alert = lib.alertDialog({
        header = 'Delete All Notices',
        content = 'Are you sure you want to permanently delete all your notices?',
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        TriggerServerEvent("rsg:noticeBoard:handleNoticeAction", {
            action = "removeAll"
        })
    end
end)
