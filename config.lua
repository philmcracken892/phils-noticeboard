Config = {}
Config.DatabaseName = "noticeboard"
Config.MaxNoticesPerPlayer = 3
Config.NoticeExpiryDays = 7 --- 0 IS DISABLED
Config.WebhookURL = "webhook here"
Config.noticeboardLocations = {
    { coords = vector3(-767.25, -1260.67, 43.53), radius = 1.5 }, -- blackwater
    { coords = vector3(2514.56, -1321.13, 48.50), radius = 1.5 }, -- st denis
    { coords = vector3(1353.46, -1304.15, 76.86), radius = 1.5 }, -- rhodes
    { coords = vector3(-271.91, 804.73, 119.36), radius = 1.5 }, -- valentine
    { coords = vector3(-1801.96, -358.48, 163.82), radius = 1.5 }, -- strawberry
    
    -- Add more locations as needed
}
