-- Second Daedalus Hammer config page. Mirrors AspectConfigMenu but writes AspectSettings[aspect].Hammer2.
-- Options come from RunStartControl.GetSecondHammerOptions (sentinel + hammers compatible with the pinned first hammer).

function RunStartControl.CreateHammer2ConfigMenu( screen )
    if RunStartControl.config.Enabled then
        local nrows = 4
        local idx = 0

        for i = 1, TableLength(RunStartControl.WeaponAspectData) do
            local weaponData = RunStartControl.WeaponAspectData[i]
            for j = 1, TableLength(weaponData.Aspects) do
                local aspectID = weaponData.Aspects[j]
                local gridX = math.ceil((idx+1) / nrows)
                local gridY = idx % nrows + 1
                CreateHammer2Picker( screen, weaponData.Name, aspectID, gridX, gridY)
                idx = idx + 1
            end
        end
    end
end

function CreateHammer2Picker( screen, weapon, aspect, gridX, gridY)
    local xpos = RunStartControl.MenuXPositions[gridX]
    local ypos = RunStartControl.MenuYPositions[gridY]

    screen.Components["Hammer2PickerLeft"..aspect] = CreateScreenComponent({ Name = "ButtonCodexDown", X = xpos - 120, Y = ypos, Scale = 1.0, Group = "Combat_Menu"})
    SetAngle({ Id = screen.Components["Hammer2PickerLeft"..aspect].Id, Angle = -90})
    SetScale({ Id = screen.Components["Hammer2PickerLeft"..aspect].Id, Fraction = 0.55})
    screen.Components["Hammer2PickerLeft"..aspect].OnPressedFunctionName = "Hammer2PickerLeft"
    screen.Components["Hammer2PickerLeft"..aspect].args = {
        Aspect = aspect
    }

    screen.Components["Hammer2PickerRight"..aspect] = CreateScreenComponent({ Name = "ButtonCodexDown", X = xpos + 120, Y = ypos, Scale = 1.0, Group = "Combat_Menu"})
    SetAngle({ Id = screen.Components["Hammer2PickerRight"..aspect].Id, Angle = 90})
    SetScale({ Id = screen.Components["Hammer2PickerRight"..aspect].Id, Fraction = 0.55})
    screen.Components["Hammer2PickerRight"..aspect].OnPressedFunctionName = "Hammer2PickerRight"
    screen.Components["Hammer2PickerRight"..aspect].args = {
        Aspect = aspect
    }

    screen.Components["Hammer2Picker"..aspect] = CreateScreenComponent({ Name = "BlankObstacle", Scale = 0.5, Group = "Combat_Menu", X = xpos, Y = ypos})

    -- text box (current second-hammer choice; nil -> vanilla sentinel)
    CreateTextBox({ Id = screen.Components["Hammer2Picker"..aspect].Id,
      Text = GameState.RunStartControl.AspectSettings[aspect].Hammer2 or RunStartControl.VanillaSentinel,
      OffsetX = 0,
      OffsetY = 0,
      FontSize = 17,
      Color = Color.White,
      Font = "AlegreyaSansSCRegular",
      ShadowBlur = 0,
      ShadowColor = {0,0,0,1},
      ShadowOffset={0, 2},
      Justification = "Center",
      DataProperties = {
        OpacityWithOwner = true,
      },
    })
    --Icon Display
    screen.Components["Aspect2Icon"..aspect] = CreateScreenComponent({ Name = "BlankObstacle", Scale = 0.8, Group = "Combat_Menu", X = xpos, Y = ypos - 90 })
    local aspectIcon = TraitData[aspect].Icon .. "_Large"
    SetAnimation({ DestinationId = screen.Components["Aspect2Icon"..aspect].Id, Name = aspectIcon})

end


function Hammer2PickerMove( screen, button, offset )
    local aspect = button.args.Aspect

    local options = RunStartControl.GetSecondHammerOptions( aspect )

    local current = GameState.RunStartControl.AspectSettings[aspect].Hammer2 or RunStartControl.VanillaSentinel
    local weapon = GameState.RunStartControl.AspectSettings[aspect].Weapon

    local index = nil
    for i, option in ipairs(options) do
        if option == current then
            index = i
            break
        end
    end
    -- current choice may have been filtered out (e.g. first hammer changed) -> start from the sentinel
    if index == nil then
        index = 1
    end
    index = index + offset

    if index <= 0 then
        index = TableLength(options) + index
    elseif index > TableLength(options) then
        index = index - TableLength(options)
    end

    local newHammer = options[index]

    RunStartControl.SetAspectSettings(weapon, aspect, nil, nil, nil, nil, nil, newHammer)

    ModifyTextBox({ Id = screen.Components["Hammer2Picker"..aspect].Id, Text = GameState.RunStartControl.AspectSettings[aspect].Hammer2})
end

function Hammer2PickerLeft(screen, button)
    Hammer2PickerMove(screen, button, -1)
end

function Hammer2PickerRight(screen, button)
    Hammer2PickerMove(screen, button, 1)
end

ModUtil.LoadOnce(function()
    if RunStartControl.config.Menu == "configmenu" then
        ModConfigMenu.RegisterMenuOverride({ModName = "第二把锤子设置"}, RunStartControl.CreateHammer2ConfigMenu)
    end
  end)
