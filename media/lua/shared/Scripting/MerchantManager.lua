-- Copyright (c) 2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/ScriptManagerNeo"
require "Scripting/Objects/Command"
require "Communications/QSystem"
require "Scripting/SaveManager"

MerchantManager = ScriptManagerNeo:derive("MerchantManager")
MerchantManager.instance = nil;
MerchantManager.settings = {
    sellback = false;               -- if true, you'll be able to offer any item that merchant sells
    sellback_m = 0.5,               -- sets worth multiplier for sellback items
    sellback_ruleset = false,       -- sets ruleset that will be used for all sellback items
    buyback = true,                 -- if true, you'll be able buy items you sold
    buyback_m = 1.25,               -- sets worth multiplier for buyback items 
    reputation = true,              -- if true, having remainder from deals will be increasing player's reputation
    reputation_stat = "rep",        -- defines the name of reputation stat
    reputation_m = 0.01,            -- sets reputation increase multiplier for successful deals (1% of "remainder - cost * 0.75")
    discount_m = 0.80,              -- maximum discount (20%)
};

MerchantManager.calculateDiscount = function (reputation) -- returns discount based on reputation
    if reputation then
        local discount_m = 1 - (math.floor(reputation) / 5) * 0.01; -- 1% per 5 reputation
        return discount_m > MerchantManager.settings.discount_m and discount_m or MerchantManager.settings.discount_m;
    else
        return 1;
    end
end

MerchantManager.calculateReputation = function (remainder, cost) -- returns reputation increase based on remainder that goes to merchant
    return remainder - (cost * 0.75);
end

local commands = {}

-- offer item,amount|value|unique|flag
local command_1 = Command:derive("offer")
function command_1:execute(sender)
    self:debug();
    local status, value;
    local item = self.args[1]:ssplit(',');
    item[1] = getScriptManager():FindItem(item[1]);
    if item[1] then
        if item[2] then
            status, item[2] = pcall(tonumber, item[2]);
            if not (status and item[2] and math.floor(item[2]) == item[2]) then
                return "Amount is not an integer";
            end
        else
            item[2] = 1;
        end
        status, value = pcall(tonumber, self.args[2]);
        if not (status and value and math.floor(value) == value) then
            return "Value is not an integer";
        end
        sender.stock[#sender.stock+1] = { name = tostring(item[1]:getDisplayName()), type = item[1]:getFullName(), amount = item[2], pack_size = item[1]:getCount(), texture = QItemFactory.getTextureFromItem(item[1]), w_texture = QItemFactory.getWorldSpriteFromItem(item[1]), default = item[2], value = value, unique = self.args[3] == "true", flag = self.args[4] ~= nil and tostring(self.args[4]) };
    else
        return string.format("Item '%s' doesn't exist", tostring(self.args[1]));
    end
end
commands[1] = command_1:new(command_1.Type, 2, 4);

-- demand item|value|ruleset
-- demand ruleset|value
local command_2 = Command:derive("demand")
function command_2:execute(sender)
    self:debug();
    local item, ruleset;
    if #(self.args[1]:ssplit('.')) == 1 then
        ruleset = self.args[1];
    else
        item, ruleset = self.args[1], self.args[3];
    end

    if item and not getScriptManager():FindItem(self.args[1]) then
        return string.format("Item '%s' doesn't exist", tostring(self.args[1]));
    end
    if ruleset and not ItemFetcher.has_ruleset(ruleset) then
        return string.format("Ruleset '%s' doesn't exist", tostring(ruleset));
    end

    local status, value  = pcall(tonumber, self.args[2]);
    if status and value and math.floor(value) == value then
        value = value < 0 and 0 or value;
    else
        return "Value is not an integer";
    end

    sender.demands[#sender.demands+1] = { item = item, value = value, ruleset = ruleset };
end
commands[2] = command_2:new(command_2.Type, 2, 3);


function MerchantManager:indexOf(character)
    for i=1, MerchantManager.instance.items_size do
        if MerchantManager.instance.items[i].id == character then
            return i;
        end
    end
end

function MerchantManager:restock(character)
    for i=1, self.items_size do
        if not character or self.items[i].id == character then
            for j=1, #self.items[i].stock do
                if not self.items[i].stock[j].unique and self.items[i].stock[j].amount < self.items[i].stock[j].default then
                    self.items[i].stock[j].amount = self.items[i].stock[j].default;
                end
            end
        end
    end
    SaveManager.onMerchantDataChange();
	SaveManager.save();
end

local _script = Script:derive("Script");
function _script:execute(sender, command)
    for i=1, #commands do
        if commands[i]:validate_command(command) then
            local result = commands[i]:execute(sender);
            if type(result) == "string" then
                result = string.format("[QSystem] (Error) %s at line %i. File=%s, Mod=%s, Command=#%s", result, self.index, tostring(self.file), tostring(self.mod), commands[i].command);
            end
            self.index = self.index + 1;
            return result;
        end
    end

    return string.format("[QSystem] (Error) Unknown command '%s' at line - %i", tostring(command), self.index);
end

function MerchantManager:create_script(file, mod)
	return _script:new(file, mod);
end

function MerchantManager:new()
    local o = ScriptManagerNeo:new("characters");
    setmetatable(o, self);
    self.__index = self;
    return o;
end

function MerchantManager.reset()
    if MerchantManager.instance then
        MerchantManager.instance.items_size = 0;
        MerchantManager.instance.items = {};
    end
end

function MerchantManager.load()
    if MerchantManager.instance then
        MerchantManager.instance.items = {};
        for i=1, CharacterManager.instance.items_size do
            local file = CharacterManager.instance.items[i].file;
            local mod = CharacterManager.instance.items[i].mod;
            local language = CharacterManager.instance.items[i].language;
            if file:ends_with(".txt") then
                local index = string.lastIndexOf(file, ".txt");
                file = string.sub(file, 1, index).."_inv.txt";
            end
            local script = MerchantManager.instance:load_script(file, mod, true, language, true);
            if script and not isServer() then
                local entry = {};
                entry.id = tostring(CharacterManager.instance.items[i].name);
                entry.index = i;
                entry.stock = {};
                entry.demands = {};
                entry.stat = MerchantManager.settings.reputation and MerchantManager.settings.reputation_stat or false;
                MerchantManager.instance.items_size = MerchantManager.instance.items_size + 1; MerchantManager.instance.items[MerchantManager.instance.items_size] = entry;
                while script do
                    local result = script:play(MerchantManager.instance.items[MerchantManager.instance.items_size]);
                    if result then
                        if type(result) == "string" then
                            print(result);
                        else
                            break;
                        end
                    end
                end
                if MerchantManager.settings.sellback then
                    if not MerchantManager.settings.sellback_ruleset or ItemFetcher.validate(MerchantManager.settings.sellback_ruleset) then
                        for j=1, #MerchantManager.instance.items[MerchantManager.instance.items_size].stock do
                            local item = MerchantManager.instance.items[MerchantManager.instance.items_size].stock[j];
                            MerchantManager.instance.items[MerchantManager.instance.items_size].demands[#MerchantManager.instance.items[MerchantManager.instance.items_size].demands+1] = { item = item.type, value = math.floor(item.value * MerchantManager.settings.sellback_m), ruleset = MerchantManager.settings.sellback_ruleset }
                        end
                    else
                        print("[QSystem] (Error) MerchantManager: Ruleset specified for sellback items doesn't exist");
                        QuestLogger.error = true;
                    end
                end
            end
        end
    end
end

function MerchantManager.init()
    if not MerchantManager.instance then MerchantManager.instance = MerchantManager:new() end
    MerchantManager.load();
    if not isServer() then
        local m = getPlayer():getModData();
        if m.buyback then
            for i=1, #m.buyback do
                if m.buyback[i].stock then
                    for j=1, #m.buyback[i].stock do
                        local item = getScriptManager():FindItem(m.buyback[i].stock[j].type);
                        m.buyback[i].stock[j].name = item:getDisplayName();
                        m.buyback[i].stock[j].texture = QItemFactory.getTextureFromItem(item);
                    end
                end
            end
        end
    end
end

function MerchantManager.preinit()
    MerchantManager.instance = MerchantManager:new();
    for entry_id=1, #QImport.scripts do
        print(string.format("[QSystem] MerchantManager: Loading data for plugin 'ssr-plugin-e3' from mod '%s'", tostring(QImport.scripts[entry_id].mod)));
        for i=1, #QImport.scripts[entry_id].char_data do
            local file = QImport.scripts[entry_id].char_data[i];
            if file:ends_with(".txt") then
                local index = string.lastIndexOf(file, ".txt");
                file = string.sub(file, 1, index).."_inv.txt";
            end
            MerchantManager.instance:load_script(file, QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language, true)
        end
    end
end

Events.OnQSystemInit.Add(MerchantManager.init);
Events.OnQSystemRestart.Add(MerchantManager.load);
Events.OnQSystemReset.Add(MerchantManager.reset);

if not isServer() then
    Events.OnQSystemPreInit.Add(MerchantManager.preinit);
end


local serpent = require("serpent");
local dataType = #SaveManager.dataType+1;
SaveManager.dataType[dataType] = "merchants";
SaveManager.flags[dataType] = false;

SaveManager.onMerchantDataChange = function (forced)
    if (QSystem.initialised and SaveManager.enabled) or forced then
        SaveManager.flags[dataType] = true;
    end
end

local SaveManager_load = SaveManager.load;
SaveManager.load = function(progress)
    SaveManager_load(progress);
    if progress[dataType] then
        for a=1, #progress[dataType] do
            local index = MerchantManager.instance:indexOf(progress[dataType][a].id);
            if index then
                for b=1, #MerchantManager.instance.items[index].stock do
                    for c=1, #progress[dataType][a].stock do
                        if MerchantManager.instance.items[index].stock[b].type == progress[dataType][a].stock[c][1] then
                            MerchantManager.instance.items[index].stock[b].amount = progress[dataType][a].stock[c][2];
                            table.remove(progress[dataType][a].stock, c);
                            break;
                        end
                    end
                end
            end
        end
    end
end

local SaveManager_data = SaveManager.data;
SaveManager.data = function(debug)
    local data = SaveManager_data(debug);
    if SaveManager.flags[dataType] then
        local progress = {};
        for i=1, MerchantManager.instance.items_size do
            if MerchantManager.instance.items[i].stock[1] then
                local entry = {};
                entry.id = MerchantManager.instance.items[i].id;
                entry.stock = {}
                for j=1, #MerchantManager.instance.items[i].stock do
                    entry.stock[j] = { MerchantManager.instance.items[i].stock[j].type, MerchantManager.instance.items[i].stock[j].amount };
                end
                progress[i] = entry;
            end
        end
        data[dataType] = serpent.dump(progress);
        SaveManager.flags[dataType] = false;
    else
        data[dataType] = false;
    end

    return data;
end