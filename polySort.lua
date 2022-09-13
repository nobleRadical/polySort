local input_chest = peripheral.wrap(settings.get("input_chest"))
local output_chest = peripheral.wrap(settings.get("output_chest"))
local inventories = {}
local commands = {"sort", "request", "check", "list", "exit", "help"}
if settings.get("inventories") then 
    for _, name in settings.get("inventories") do --list of names -> list of wraps.
        table.insert(inventories, peripheral.wrap(name))
    end
else
    inventories = { peripheral.find("inventory",  
        function(name, wrap) --this function excludes the input and output chests from the table
            if name == peripheral.getName(input_chest) or name == peripheral.getName(output_chest) or name == "back" or name == "front" or name == "left" or name == "right" or name == "top" or name == "bottom" then
                return false    
            else
                return true
            end
        end
        ) }
end

local function contains(...)
    local ret = {}
    for _,k in ipairs({...}) do ret[k] = true end
    return ret
 end

local function hasSpace(chest)
    if table.getn(chest.list()) >= chest.size() then
        return false
    else
        return true
    end
end

local function findFirstSlotOfItem(chest, itemName)
    for slot, item in pairs(chest.list()) do
        if item.name == itemName then
            return slot
        end
    end
    return nil
end

local function verbose()
    print("input chest: " .. peripheral.getName(input_chest))
    print("output chest: " .. peripheral.getName(output_chest))
    print("storage chests: ")
    for _, v in pairs(inventories) do
        print(peripheral.getName(v))
    end
    print("Available Commands: " .. table.concat(commands, ","))
end

local function sort()
    for slot, item in pairs(input_chest.list()) do --for every item in the input chest
        local polySorted = false
        local pushSorted = false
        local result = 0
        for _, chest in pairs(inventories) do-- check every chest in our inventories
            
            targetSlot = findFirstSlotOfItem(chest, item.name)
            
            if targetSlot then --if the chest has that item already, push to that chest
                numTransferred = input_chest.pushItems(peripheral.getName(chest), slot)
                if numTransferred > 0 then --if the items actually got sorted. If the chest is full and they didn't get pushed, then we continue.
                    polySorted = true
                    print("poly-sorted " .. item.name .. " to chest " .. peripheral.getName(chest))
                    break
                end
            end
        end
                
        if polySorted then --we already sorted this item. "Continue" statement would be good here.
            --we're good.
        else
            for _, chest in pairs(inventories) do--looping over all the chests again
                if hasSpace(chest) then
                    input_chest.pushItems(peripheral.getName(chest), slot)
                    pushSorted = true
                    print("push-sorted " .. item.name .. " to chest " .. peripheral.getName(chest))
                    break
                end
            end
        end
    end
end

local function request(itemName, limit)
    local itemsTransferred = 0
    for _, chest in pairs(inventories) do
        for slot, item in pairs(chest.list()) do
            local itemDetail = chest.getItemDetail(slot) 
            if itemDetail.name == itemName or itemDetail.displayName == itemName then
                local s = 0
                if limit == math.huge then
                    s = chest.pushItems(peripheral.getName(output_chest), slot)
                else
                    s = chest.pushItems(peripheral.getName(output_chest), slot, limit-itemsTransferred)
                end
                    itemsTransferred = itemsTransferred + s
            end
            if itemsTransferred >= limit then break end
        end
        if itemsTransferred >= limit then break end
    end
    return itemsTransferred
end

local function check(itemName)
    local itemsFound = 0
    for _, chest in pairs(inventories) do
        for slot, _ in pairs(chest.list()) do
            local itemDetail = chest.getItemDetail(slot) 
            if itemDetail.name == itemName or itemDetail.displayName == itemName then
                itemsFound = itemsFound + itemDetail.count
            end
        end
    end
    return itemsFound
end

local function list(tag)
    local itemTable = {}
    for _, chest in pairs(inventories) do
        for slot, _ in pairs(chest.list()) do
            local itemDetail = chest.getItemDetail(slot) 
            if itemDetail.tags[tag] or (not tag) then -- if the item tag matches the filter tag or if the filter doesn't exist
                if not itemTable[itemDetail.name] then itemTable[itemDetail.name] = 0 end -- initialize the key if doesn't exist 
                itemTable[itemDetail.name] = itemTable[itemDetail.name] + itemDetail.count -- add item to table
            end
        end
    end
    local printString = "Name\tCount\n"
    for name, count in pairs(itemTable) do
        printString = printString .. name .. "\t" .. tostring(count) .. "\n"
    end
    return printString
end

local function cli()
    local commandHistory = {}
    local itemNameMemory = ""
    local itemCountMemory = 0
    while true do
        term.blit(">", "3", "f") -- blue prompt
        local command = read(nil, commandHistory)
        local commandArgs = {}
        for substring in command:gmatch("%S+") do
        table.insert(commandArgs, substring)
        end
        command = string.lower(commandArgs[1])
        table.insert(commandHistory, command)
        if contains("sort", "s")[command] then
            print("Sorting...")
            local status = pcall(sort)
            if status then
                print("Done.")
            else
                printError(res)
            end
        elseif contains("request", "r")[command] then
            write("Item name: ")
            local itemName = read()
            local limit = tonumber(commandArgs[2])
            limit = limit or math.huge
            print("Requesting...")
            local code, res = pcall(request, itemName, limit)
            if code then
                print("Items requested: " .. tostring(res))
            else
                printError(res)
            end
        elseif contains("requestr", "rr")[command] then
            if itemNameMemory == "" then print("No memory.") else
            local limit = tonumber(commandArgs[2])
            limit = limit or math.huge
            print("Requesting...")
            local code, res = pcall(request, itemNameMemory, limit)
            if code then
                print("Items requested: " .. tostring(res))
            else
                printError(res)
            end
            end
        elseif contains("check", "c")[command] then
            write("Item name: ")
            local checkedItemName = read()
            local code, itemsFound = pcall(check, checkedItemName)
            if code then
                print("Items found: " .. tostring(itemsFound))
                if itemsFound > 0 then itemNameMemory = checkedItemName end
            else
                printError(itemsFound)
            end
        elseif contains("list", "l")[command] then
            local tag = commandArgs[2]
            print("Listing...")
            local code, resultString = pcall(list, tag)
            write(resultString)
        elseif contains("exit", "0")[command] then
            print("exiting...")
            break
        elseif contains("help", "h")[command] then
            print("Available Commands: " .. table.concat(commands, ","))

print([[Help: Prints this text.
    Aliases: h
Sort: Sorts the items in the input chest into the storage inventories, using polymorphic sorting (like items with like.)    
    Aliases: s
request <number>: requests <number> items of a specified name (internal or display name.) if <number> is absent, as many as possible are pulled.
    Aliases: r <number>
check: prints the number of items of a specified name (internal or display name.) Saves item name to memory.
    Aliases: c
list <tag>: List all of the items in the storage system, or the ones that match the specified tag.
    Aliases: l <tag>
requestr <number>: requests <number> items of the memorized item name.
    Aliases: rr <number>
exit: exits the prompt.
    Aliases: 0
            ]])
        else
            print("invalid command. Type help for help.")
        end
    end
end

local function main()
if arg[1] ~= "ssh" then
verbose()
end
cli()
end

if debug.getinfo(2).what == "C" then
    main()
else
    return {sort=sort, request=request, check=check}
end