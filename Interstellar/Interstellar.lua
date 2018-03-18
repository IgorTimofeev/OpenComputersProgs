local comp = require('component')
local sru = require("serialization")
local buffer = require("doubleBuffering")
local GUI = require("GUI")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local shell = require("shell")
local ship = comp.warpdriveShipController
--Переменные, массивы, прочая хрень

local version = "1.3"
local configPath = "/Interstellar/config.cfg"
radartable = {}
buffer.setResolution(80,25)

local config = {
    loggingEnabled = false,
    requestURL = "",
    requestStructure = "",
}

local colors = {
    background = 0xFFFFFF,
    panel = 0x000000,
    window = 0xb3b3b3,
    textColor = 0x000000,
    textColor2 = 0xFFFFFF,
    button = 0x000082,
    buttonPressed = 0x00004d,
    buttonYes = 0x009900,
    buttonNo = 0x990000,
    buttonNoPressed = 0x4d0000,
}


-----
local mainContainer = GUI.fullScreenContainer()
mainContainer:addChild(GUI.panel(1, 1, mainContainer.width, mainContainer.height, colors.background))
local navContainer = mainContainer:addChild(GUI.container(18,3,62,21))
local infoContainer = mainContainer:addChild(GUI.container(1,2,16,23))
-----
local function writeConfig()
    local confSerialized = sru.serialize(config)
    local file = io.open(configPath,"w")
    file:write(confSerialized)
    file:close()
end

local function loadConfig()
    if not fs.exists(configPath) then
        fs.makeDirectory(fs.path(configPath))
        writeConfig()
    end
    local file = io.open(configPath,"r")
    config = sru.unserialize(file:read("*a"))
    file:close()
end

local function request(data)
    if not config.loggingEnabled then return end
    if not comp.isAvailable("internet") then return end
    require("internet").request(config.requestURL,config.requestStructure.." "..data)
end

local function wget(url, path)
	fs.makeDirectory(fs.path(path))
	shell.execute("wget " .. url .. " " .. path .. " -fq")
end

local function unserializeFile(path)
	local file = io.open(path, "r")
	local data = sru.unserialize(file:read("*a"))
	file:close()
	return data
end

local function CoreScreenFix() 
    comp.gpu.bind(comp.screen.address,true) 
    buffer.setResolution(80,25)
end

local function drawNav()
    infoContainer:deleteChildren()
    infoContainer:addChild(GUI.panel(1,1,infoContainer.width,infoContainer.height,colors.button,0.1))
    local sx,sy,sz,planet = ship.position()
    local pos
    infoContainer:addChild(GUI.label(1,2,15,1,colors.textColor2,'Координаты:')):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    infoContainer:addChild(GUI.label(1,3,15,1,colors.textColor2,'X: '..sx)):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    infoContainer:addChild(GUI.label(1,4,15,1,colors.textColor2,'Y: '..sy)):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    infoContainer:addChild(GUI.label(1,5,15,1,colors.textColor2,'Z: '..sz)):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    infoContainer:addChild(GUI.label(1,7,15,1,colors.textColor2,'Пространство:')):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    if ship.isInSpace() == true or planet == 'Asteroids' then
        pos = 'Космос'
    elseif ship.isInHyperspace() == true then
        pos = 'Гипер'
    else
        pos = 'Планета '..planet..''
    end
    infoContainer:addChild(GUI.label(1,8,15,2,colors.textColor2,pos)):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
end

local function drawLoggingSettings()
    navContainer:deleteChildren()
    navContainer:addChild(GUI.panel(1, 1, navContainer.width, navContainer.height, colors.window))
    navContainer:addChild(GUI.label(1, 1, 61, 1, colors.button, "Настройки логов")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    navContainer:addChild(GUI.text(2,3,colors.button,"Логгирование с помощью POST-запроса"))
    navContainer:addChild(GUI.switchAndLabel(2, 5, 31, 8, colors.button, 0x1D1D1D, 0xEEEEEE, colors.textColor, "Включить логирование:", config.loggingEnabled)).switch.onStateChanged = function()
        config.loggingEnabled = true
        writeConfig()
    end
    navContainer:addChild(GUI.label(2, 7, 16, 1, colors.textColor, "Адрес для запросов"))
    navContainer:addChild(GUI.input(2, 8, 30, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, config.requestURL, "URL")).onInputFinished = function(navContainer, input, eventData, text)
        config.requestURL = text
        writeConfig()
    end 
    navContainer:addChild(GUI.label(2, 10, 16, 1, colors.textColor, "Структура запроса (текст в начале)"))
    navContainer:addChild(GUI.input(2, 11, 30, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, config.requestStructure, "text:any()")).onInputFinished = function(navContainer, input, eventData, text)
        config.requestStructure = text
        writeConfig()
    end
end

local function drawShipSettings()
    local back,left,down = ship.dim_negative()
    local front,right,up = ship.dim_positive()
    navContainer:deleteChildren()
    navContainer:addChild(GUI.panel(1, 1, navContainer.width, navContainer.height, colors.window))
    navContainer:addChild(GUI.label(1, 1, 61, 1, colors.button, "Настройки корабля")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    navContainer:addChild(GUI.label(2, 3, 16, 1, colors.textColor, "Имя корабля"))
    navContainer:addChild(GUI.input(2, 4, 30, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, ship.shipName(), "Имя корабля")).onInputFinished = function(navContainer, input, eventData, text)
        ship.shipName(text)
    end    
    navContainer:addChild(GUI.label(2, 6, 16, 1, colors.button, "Размеры корабля:"))
    navContainer:addChild(GUI.label(2, 8, 16, 1, colors.textColor, "Блоки спереди"))
    navContainer:addChild(GUI.input(2, 9, 13, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, front, "Кол-во блоков")).onInputFinished = function(navContainer, input, eventData, text)
        front = tonumber(text)
        if not front then input.text = "" input.placeholderText = "0" front = 0 return end
    end
    navContainer:addChild(GUI.label(2, 11, 16, 1, colors.textColor, "Блоки сзади"))
    navContainer:addChild(GUI.input(2, 12, 13, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, back, "Кол-во блоков")).onInputFinished = function(navContainer, input, eventData, text)
        back = tonumber(text)
        if not back then input.text = "" input.placeholderText = "0" back = 0 return end
    end  
    navContainer:addChild(GUI.label(2, 14, 16, 1, colors.textColor, "Блоки сверху"))
    navContainer:addChild(GUI.input(2, 15, 13, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, up, "Кол-во блоков")).onInputFinished = function(navContainer, input, eventData, text)
        up = tonumber(text)
        if not up then input.text = "" input.placeholderText = "0" up = 0 return end
    end  
    navContainer:addChild(GUI.label(20, 8, 16, 1, colors.textColor, "Блоки снизу"))
    navContainer:addChild(GUI.input(20, 9, 13, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, down, "Кол-во блоков")).onInputFinished = function(navContainer, input, eventData, text)
        down = tonumber(text)
        if not down then input.text = "" input.placeholderText = "0" down = 0 return end
    end  
    navContainer:addChild(GUI.label(20, 11, 16, 1, colors.textColor, "Блоки слева"))
    navContainer:addChild(GUI.input(20, 12, 13, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, left, "Кол-во блоков")).onInputFinished = function(navContainer, input, eventData, text)
        left = tonumber(text)
        if not left then input.text = "" input.placeholderText = "0" left = 0 return end
    end  
    navContainer:addChild(GUI.label(20, 14, 16, 1, colors.textColor, "Блоки справа"))
    navContainer:addChild(GUI.input(20, 15, 13, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, right, "Кол-во блоков")).onInputFinished = function(navContainer, input, eventData, text)
        right = tonumber(text)
        if not right then input.text = "" input.placeholderText = "0" right = 0 return end
    end
    navContainer:addChild(GUI.button(2,navContainer.height-1,19,1,colors.button,colors.background,colors.buttonPressed,colors.background,'Применить размеры')).onTouch = function()
        if front == 0 or back == 0 or up == 0 or down == 0 or left == 0 or right == 0 then
            GUI.error("Размеры заполнены неправильно!")
            return
        end
        ship.dim_negative(back,left,down)
        ship.dim_positive(front,right,up)
    end
end

local function drawUpdate()
    if not comp.isAvailable("internet") then
        GUI.error("Для работы этой функции необходима интернет-карта!")
        return
    end
    local b = require("internet").request("https://raw.githubusercontent.com/rrrGame/OpenComputersProgs/master/Interstellar/version.txt")
    local newVersion = ""
    for chunk in b do
        newVersion = newVersion..require("text").trim(chunk)
    end
    navContainer:deleteChildren()
    navContainer:addChild(GUI.panel(1, 1, navContainer.width, navContainer.height, colors.window))
    navContainer:addChild(GUI.label(1, 1, 61, 1, colors.button, "Обновления")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    if version == newVersion then
        navContainer:addChild(GUI.text(2,3,colors.buttonNo,"Новых обновлений не найдено."))
        return
    end
    local textBox = navContainer:addChild(GUI.textBox(2, 9, 32, 8, 0xEEEEEE, 0x2D2D2D, {}, 1, 1, 0))
    local c = require("internet").request("https://raw.githubusercontent.com/rrrGame/OpenComputersProgs/master/Interstellar/changelogs/latest.txt")
    local changelog = ""
    for chunk in c do
        changelog = changelog..require("text").trim(chunk)
    end
    for word in changelog:gmatch("[^\n]+") do
        table.insert(textBox.lines,word)
    end
    navContainer:addChild(GUI.text(2,3,colors.textColor,"Найдено новое обновление!"))
    navContainer:addChild(GUI.text(2,5,colors.textColor,"Новая версия: "..newVersion))
    navContainer:addChild(GUI.text(2,6,colors.textColor,"Текущая версия: "..version))
    navContainer:addChild(GUI.text(2,8,colors.button,"Список изменений: "))
    navContainer:addChild(GUI.button(2, 18, 15, 3, colors.button, colors.textColor2, colors.buttonPressed, colors.textColor2, "Обновить ПО")).onTouch = function()
        mainContainer:stopEventHandling()
        buffer.clear(0x0)
        buffer.draw(false)
        comp.gpu.setForeground(0xFFFFFF)
        print("Начинаю процесс обновления..")
        print("\n\nЗагрузка списка файлов..")
        local path = "/Interstellar/filelist.txt"
        wget("https://raw.githubusercontent.com/rrrGame/OpenComputersProgs/master/Interstellar/filelist.txt", path)
        local applist = unserializeFile(path)
        fs.remove(path)
        for i = 1, #applist do
            if fs.exists(applist[i].path) then
                fs.remove(applist[i].path)
                print("Обновляю "..applist[i].path)
                wget(applist[i].url,applist[i].path)
            else 
                print("Качаю "..applist[i].path)
                wget(applist[i].url,applist[i].path)
            end
        end
        comp.gpu.setForeground(0x00FF00)
        print("\n\nОбновление завершено успешно!")
        os.sleep(2)
        shell.execute("/Interstellar.lua")
    end
end

local function drawAbout()
    navContainer:deleteChildren()
    navContainer:addChild(GUI.panel(1, 1, navContainer.width, navContainer.height, colors.window))
    navContainer:addChild(GUI.label(1, 1, mainContainer.width, mainContainer.height, colors.textColor, "Interstellar\nВерсия 0.5\nАвтор: rrr_game"))
end

local function antiFreeze()
    local antiFreezeTimer = require("event").timer(1,CoreScreenFix,math.huge)
    local fade = mainContainer:addChild(GUI.panel(1, 1, mainContainer.width, mainContainer.height, 0x000000,0.1))
    mainContainer:addChild(GUI.framedButton(1, 1, mainContainer.width-1, mainContainer.height-1, 0x1a1a1a, 0xFFFFFF, 0x1a1a1a, 0xFFFFFF, "Выполняется прыжок...\nНажмите на экран по завершению")).onTouch = function(mainContainer,button)
        require("event").cancel(antiFreezeTimer)
        button:delete()
        fade:delete()
        drawNav()
    end
end


local function drawJump()
    ship.command("MANUAL")
    local _,max = ship.getMaxJumpDistance()
    local x,y,z = ship.dim_positive()
    local x2,y2,z2 = ship.dim_negative()
    local mindx = x + x2
    local mindy = z + z2
    local mindz = y + y2
    local rotmax = 270
    local jumpX = 0
    local jumpY = 0
    local jumpZ = 0
    local rot = 0
    local type
    navContainer:deleteChildren()
    navContainer:addChild(GUI.panel(1, 1, navContainer.width, navContainer.height, colors.window))
    navContainer:addChild(GUI.label(1, 1, 61, 1, colors.button, "Прыжок")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    navContainer:addChild(GUI.label(2, 4, 8, 1, 0x555555, "Введенные значения будут ограничены автоматически."))
    navContainer:addChild(GUI.label(2, 6, 16, 1, colors.textColor, "Ось перед-зад ("..mindx.." - "..tostring(max + mindx)..")"))
    navContainer:addChild(GUI.input(2, 7, 30, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "0", "X")).onInputFinished = function(navContainer, input, eventData, text)
        jumpX = tonumber(text)
        if not jumpX then input.text = "" input.placeholderText = "Введите число!" jumpX = 0 return end
        if jumpX >= max + mindx then jumpX = max + mindx input.text = jumpX return end
        if jumpX <= -max + -mindx then jumpX = -max + -mindx input.text = jumpX return end
    end    
    navContainer:addChild(GUI.label(2, 9, 12, 1, colors.textColor, "Ось верх-низ ("..mindy.." - "..tostring(max + mindy)..")"))
    navContainer:addChild(GUI.input(2, 10, 30, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "0", "Y")).onInputFinished = function(navContainer, input, eventData, text)
        jumpY = tonumber(text)
        if not jumpY then input.text = "" input.placeholderText = "Введите число!" jumpY = 0 return end
        if jumpY >= max + mindy then jumpY = max + mindy input.text = jumpY return end
        if jumpY <= -max + -mindy then jumpY = -max + -mindy input.text = jumpY return end
    end    
    navContainer:addChild(GUI.label(2, 12, 14, 1, colors.textColor, "Ось лево-право ("..mindz.." - "..tostring(max + mindz)..")"))
    navContainer:addChild(GUI.input(2, 13, 30, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "0", "Z")).onInputFinished = function(navContainer, input, eventData, text)
        jumpZ = tonumber(text)
        if not jumpZ then input.text = "" input.placeholderText = "Введите число!" jumpZ = 0 return end
        if jumpZ >= max + mindz then jumpZ = max + mindz input.text = jumpZ return end
        if jumpZ <= -max + -mindz then jumpZ = -max + -mindz input.text = jumpZ return end
    end    
    navContainer:addChild(GUI.label(2, 15, 14, 1, colors.textColor, 'Угол вращения по часовой стрелке (шаг 90 градусов)'))
    navContainer:addChild(GUI.input(2, 16, 30, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "0", "R")).onInputFinished = function(navContainer, input, eventData, text)
        rot = tonumber(text)
        if not rot then input.text = "" input.placeholderText = "Введите число!" rot = 0 return end
        if rot >= rotmax then rot = rotmax input.text = rot return end
        if rot <= -rotmax then rot = -rotmax input.text = rot return end
    end
    navContainer:addChild(GUI.button(2, 18, 29, 3, colors.button, colors.textColor2, colors.buttonPressed, colors.textColor2, "Совершить прыжок")).onTouch = function()
        if jumpX == 0 and jumpY == 0 and jumpZ == 0 and rot == 0 then GUI.error("Не введены координаты!") return end
        ship.command("MANUAL")
        ship.rotationSteps(rot)
        ship.movement(jumpX,jumpY,jumpZ)
        ship.enable(true)
        local xp,yp,zp = ship.position()
        request("Ship is jumping on these axis: "..jumpX..", "..jumpY..", "..jumpZ..". New coordinates: "..xp+jumpX..", "..yp+jumpY..", "..zp+jumpZ..".")
        antiFreeze()
    end
    navContainer:addChild(GUI.button(33, 18, 29, 3, colors.button, colors.textColor2, colors.buttonPressed, colors.textColor2, "Совершить гипер-переход")).onTouch = function()
        ship.command("HYPERDRIVE")
        ship.enable(true)
        request("Ship is switching hyper at these coordinates: "..xp..', '..yp..', '..zp..'.')
        antiFreeze()
    end
end

local function drawInfo()
    local size = ship.getShipSize()
    local assembly = ship.isAssemblyValid()
    local energy = ship.energy()
    local name = ship.shipName()
    local back,left,down = ship.dim_negative()
    local front,right,up = ship.dim_positive()
    local ass
    if assembly then ass = "правильная" else ass = "неправильная" end
    navContainer:deleteChildren()
    navContainer:addChild(GUI.panel(1, 1, navContainer.width, navContainer.height, colors.window))
    navContainer:addChild(GUI.button(2,navContainer.height-1,19,1,colors.button,colors.background,colors.buttonPressed,colors.background,'Настроить корабль')).onTouch = function()
        drawShipSettings()
    end
    navContainer:addChild(GUI.label(1, 1, 61, 1, colors.button, "Информация о корабле")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    navContainer:addChild(GUI.label(2, 3, 61, 1, colors.textColor, "Имя корабля: "..name))
    navContainer:addChild(GUI.label(2, 5, 61, 1, colors.textColor, "Масса корабля: "..size.." блоков"))
    navContainer:addChild(GUI.label(2, 7, 61, 1, colors.textColor, "Сборка корабля: "..ass))
    navContainer:addChild(GUI.label(2, 9, 61, 1, colors.textColor, "Накоплено энергии: "..energy.." EU"))
    navContainer:addChild(GUI.label(53, 3, 61, 1, colors.textColor, "Габариты: "))
    navContainer:addChild(GUI.label(53, 5, 61, 1, colors.textColor, "Зад: "..back))
    navContainer:addChild(GUI.label(53, 7, 61, 1, colors.textColor, "Лево: "..left))
    navContainer:addChild(GUI.label(53, 9, 61, 1, colors.textColor, "Низ: "..down))
    navContainer:addChild(GUI.label(53, 11, 61, 1, colors.textColor, "Перед: "..front))
    navContainer:addChild(GUI.label(53, 13, 61, 1, colors.textColor, "Право: "..right))
    navContainer:addChild(GUI.label(53, 15, 61, 1, colors.textColor, "Верх: "..up))
end

local function drawRadar()
    if not comp.isAvailable("warpdriveRadar") then GUI.error("Для работы этой функции необходим подключенный варп-радар!") return end
    navContainer:deleteChildren()
    local max = 9999
    local radius = 1
    navContainer:addChild(GUI.panel(1, 1, navContainer.width, navContainer.height, colors.window))
    navContainer:addChild(GUI.label(1, 1, 61, 1, colors.button, "Варп-радар")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    local textBox = navContainer:addChild(GUI.textBox(2, 9, 60, 12, 0xEEEEEE, 0x2D2D2D, {}, 1, 1, 0))
    if radartable then textBox.lines = radartable end
    navContainer:addChild(GUI.label(2, 3, 9, 1, 0x555555, 'Максимум радиуса: '..max))
    navContainer:addChild(GUI.label(2, 4, 8, 1, 0x555555, "Все значения выше максимума будут выравнены автоматически."))
    navContainer:addChild(GUI.label(2, 6, 16, 1, colors.textColor, 'Радиус поиска '))
    navContainer:addChild(GUI.input(2, 7, 30, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "1", "Радиус")).onInputFinished = function(navContainer, input, eventData, text)
        radius = tonumber(text)
        if not radius then input.text = "" input.placeholderText = "Введите число!" radius = 0 return end
        if radius >= max then radius = max input.text = radius return end
        if radius < 1 then radius = 1 input.text = radius end
    end
    navContainer:addChild(GUI.button(33, 7, 29, 1, colors.button, colors.background, colors.buttonPressed, 0xFFFFFF, "Сканировать")).onTouch = function(navContainer, button, eventData, text)
        if comp.warpdriveRadar.getEnergyRequired(radius) > comp.warpdriveRadar.energy() then GUI.error("Ошибка: недостаточно энергии.\nНакоплено "..comp.warpdriveRadar.energy().." EU\nНеобходимо еще "..comp.warpdriveRadar.getEnergyRequired(radius) - comp.warpdriveRadar.energy().." EU") return end
        comp.warpdriveRadar.radius(radius)
        comp.warpdriveRadar.start()
        os.sleep(0.5)
        button.text = "Сканирование ("..comp.warpdriveRadar.getScanDuration(radius).."s)"
        os.sleep(comp.warpdriveRadar.getScanDuration(radius))
        button.text = "Сканировать"
        textBox.lines = {}
        local delay = 0
        local count
        repeat
            count = comp.warpdriveRadar.getResultsCount()
            os.sleep(0.1)
            delay = delay + 1
        until (count ~= nil and count ~= -1) or delay > 10
        if count ~= nil and count > 0 then
            for i=0,count-1 do
                success, type, name, x, y, z = comp.warpdriveRadar.getResult(i)
                if success then
                    table.insert(textBox.lines,type.." "..name.." ".." @ ("..x.." "..y.." "..z..")")
                end
            end
        else 
            table.insert(textBox.lines, {text = "Ничего не найдено.", color = colors.buttonNo})
        end
        radartable = textBox.lines
    end
end
local function drawCrew()
    ship.command("SUMMON")
    navContainer:deleteChildren()
    local pl = ""
    local str, players = ship.getAttachedPlayers()
    navContainer:addChild(GUI.panel(1, 1, navContainer.width, navContainer.height, colors.window))
    navContainer:addChild(GUI.label(1, 1, 61, 1, colors.button, "Экипаж")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    navContainer:addChild(GUI.label(2, 3, 61, 1, colors.textColor, "Список подключенных игроков:"))
    navContainer:addChild(GUI.label(2, 16, 61, 1, colors.textColor, "Телепорт игроков:"))
    navContainer:addChild(GUI.input(2, 18, 29, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "Ник игрока")).onInputFinished = function(navContainer, input, eventData, text) pl = text end
    navContainer:addChild(GUI.button(2, 20, 29, 1, colors.button, colors.textColor2, colors.buttonPressed, colors.textColor2, "Телепортировать по нику")).onTouch = function()
        for i = 1,#players do
            if pl == players[i] then
                GUI.error("Sum")
                ship.command("SUMMON")
                ship.targetName(pl)
                ship.enable(true)
                return
            end
        end
    end
    navContainer:addChild(GUI.button(33, 20, 29, 1, colors.buttonNo, colors.textColor2, colors.buttonNoPressed, colors.textColor2, "Телепортировать всех")).onTouch = function()
        ship.command("SUMMON")
        ship.targetName("")
        ship.enable(true)
    end   
    local textBox = navContainer:addChild(GUI.textBox(2, 4, 60, 12, 0xEEEEEE, 0x2D2D2D, {}, 1, 1, 0))
    table.insert(textBox.lines, {text = "Нет подключенных игроков.", color = colors.buttonNo})
    if str == "" then return end
    textBox.lines = {}
    for i = 1,#players do
        table.insert(textBox.lines,players[i])
    end 
end
local function drawCloak()
    if not comp.isAvailable("warpdriveCloakingCore") then GUI.error("Для работы этой функции необходим подключенный маскировщик!") return end
    navContainer:deleteChildren()
    cloak = comp.warpdriveCloakingCore
    navContainer:addChild(GUI.panel(1, 1, navContainer.width, navContainer.height, colors.window))
    navContainer:addChild(GUI.label(1, 1, 61, 1, colors.button, "Маскировка")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
    navContainer:addChild(GUI.label(2, 6, 16, 1, colors.textColor, 'Уровень маскировки'))
    --2, 7, 30, 1
    local comboBox = navContainer:addChild(GUI.comboBox(2, 7, 30, 1, 0xEEEEEE, 0x2D2D2D, colors.button, 0x888888))
    comboBox:addItem("Отключить").onTouch = function()
        cloak.enable(false)
    end
    comboBox:addItem("Уровень 1").onTouch = function()
        local valid, msg = cloak.isAssemblyValid()
        if not valid then GUI.error("Ошибка! Неверная сборка маскировщика:\n"..msg) return end
        cloak.enable(false)
        os.sleep(1)
        cloak.tier(1)
        cloak.enable(true)
    end
    comboBox:addItem("Уровень 2").onTouch = function()
        local valid, msg = cloak.isAssemblyValid()
        if not valid then GUI.error("Ошибка! Неверная сборка маскировщика:\n"..msg) return end
        cloak.enable(false)
        os.sleep(1)
        cloak.tier(2)
        cloak.enable(true)
    end
end
local function drawMap()
    navContainer:deleteChildren()
    navContainer:addChild(GUI.label(2, 2, navContainer.width, navContainer.height, colors.textColor, "Тут типа карта должна быть, ага.")):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)
end
-----------------------------------------------------------------------------
loadConfig()
--верхняя панель

local menu = mainContainer:addChild(GUI.menu(1, 1, mainContainer.width, colors.panel, 0x666666, colors.buttonPressed, 0xFFFFFF, 0.7))
menu:addItem("Interstellar", 0x0)
local mSettings = menu:addItem("Настройки")
local mAbout = menu:addItem("О программе")
local mExit = menu:addItem("Выход")
mSettings.onTouch = function(eventData)
    local contextMenu = GUI.contextMenu(mSettings.x, mSettings.y + 1)
    contextMenu.colors.pressed.background = colors.buttonPressed
    contextMenu:addItem("Корабль").onTouch = function()
        drawShipSettings()
    end
    contextMenu:addItem("Логгинг").onTouch = function()
        drawLoggingSettings()
    end
    contextMenu:addSeparator()
    contextMenu:addItem("Обновления").onTouch = function()
        drawUpdate()
    end
    contextMenu:show()
end
mAbout.onTouch = function(eventData)
    os.sleep(0.5)
    drawAbout()
end
mExit.onTouch = function(eventData)
    mainContainer:stopEventHandling()
    os.execute('/bin/sh.lua')
end

--панель с точками



--кнопочки

mainContainer:addChild(GUI.button(18,25,8,1,colors.button,colors.background,colors.buttonPressed,colors.background,'Экипаж')).onTouch = function()
    drawCrew()
end
mainContainer:addChild(GUI.button(27,25,8,1,colors.button,colors.background,colors.buttonPressed,colors.background,'Прыжок')).onTouch = function()
    drawJump()
end
mainContainer:addChild(GUI.button(36,25,6,1,colors.button,colors.background,colors.buttonPressed,colors.background,'Инфо')).onTouch = function()
    drawInfo()
end
mainContainer:addChild(GUI.button(43,25,7,1,colors.button,colors.background,colors.buttonPressed,colors.background,'Радар')).onTouch = function()
    drawRadar()
end
mainContainer:addChild(GUI.button(51,25,12,1,colors.button,colors.background,colors.buttonPressed,colors.background,'Маскировка')).onTouch = function()
    drawCloak()
end
mainContainer:addChild(GUI.button(71,25,7,1,colors.button,colors.background,colors.buttonPressed,colors.background,'Карта')).onTouch = function()
    drawMap()
end
mainContainer:addChild(GUI.button(79,25,2,1,colors.button,colors.background,colors.button,colors.background,''))
mainContainer:addChild(GUI.button(64,25,6,1,colors.button,colors.background,colors.button,colors.background,''))
mainContainer:addChild(GUI.button(1,25,16,1,colors.button,colors.background,colors.button,colors.background,''))
drawMap()
drawNav()
-----------------------------------------------------------------------------
buffer.clear()
mainContainer:draw()
buffer.draw(true)
mainContainer:startEventHandling()
