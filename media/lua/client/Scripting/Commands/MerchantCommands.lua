-- Copyright (c) 2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/Commands/CommandList_a"

local type_dialogue = "DialoguePanel";

-- trade character
local trade = Command:derive("trade")
function trade:execute(sender)
    self:debug();
    local function onConfirm()
        sender.input.enable = true;
        sender:showNext();
    end
    local function onCancel()
        QuestLogger.print("[QSystem*] #trade: Skipping block due trade being canceled")
        sender.script.skip = sender.script.layer+1;
        onConfirm();
    end
    if MerchantPanel.create(self.args[1], onConfirm, onCancel) then
        sender:setVisible(false);
        return -2;
    else
        return string.format("Character '%s' doesn't exist", tostring(self.args[1]));
    end
end

CommandList_a[#CommandList_a+1] = trade:new(trade.Type, 1, nil, type_dialogue);

-- in_stock character|item1,item2,...|value
local in_stock = Command:derive("in_stock")
function in_stock:execute(sender)
    self:debug();
    local index = MerchantManager.instance:indexOf(self.args[1]);
    if index then
        local items = self.args[2]:ssplit(',');
        local value = self.args[3] == "true"
        for i=1, #items do
            if getScriptManager():FindItem(items[i]) then
                local available = false;
                for j=1, #MerchantManager.instance.items[index].stock do
                    if MerchantManager.instance.items[index].stock[j].type == items[i] then
                        available = MerchantManager.instance.items[index].stock[j].amount > 0;
                        break;
                    end
                end
                if available ~= value then
                    QuestLogger.print(string.format("[QSystem*] #in_stock: Skipping block due to item '%s' being %s stock.", items[i], value and "out of" or "in"));
                    sender.script.skip = sender.script.layer+1;
                    return;
                end
            else
                return string.format("Item '%s' doesn't exist", tostring(self.args[1]));
            end
        end
    else
        return string.format("Character '%s' doesn't exist", tostring(self.args[1]));
    end
end

CommandList_a[#CommandList_a+1] = in_stock:new(in_stock.Type, 3, nil, type_dialogue);

-- restock
-- restock character
local restock = Command:derive("restock")
function restock:execute(sender)
    self:debug();
    if self.args[1] and not MerchantManager.instance:indexOf(self.args[1]) then
        return string.format("Character '%s' doesn't exist", tostring(self.args[1]));
    end
    MerchantManager.instance:restock(self.args[1]);
end

CommandList_a[#CommandList_a+1] = restock:new(restock.Type, 0, 1, type_dialogue);

-- buyback_clear
-- buyback_clear character
local buyback_clear = Command:derive("buyback_clear")
function buyback_clear:execute(sender)
    self:debug();
    local m = getPlayer():getModData();
    if m.buyback then
        if self.args[1] then
            for i=#m.buyback, 1, -1 do
                if m.buyback[i].id == self.args[1] then
                    table.remove(m.buyback, i);
                end
            end
        else
            m.buyback = {};
        end
    end
end

CommandList_a[#CommandList_a+1] = buyback_clear:new(buyback_clear.Type, 0, 1, type_dialogue);