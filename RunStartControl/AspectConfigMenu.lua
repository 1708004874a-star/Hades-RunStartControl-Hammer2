function RunStartControl.CreateAspectConfigMenu( screen )
    if RunStartControl.config.Enabled then
        local nrows = 4
        local idx = 0

        for i = 1, TableLength(RunStartControl.WeaponAspectData) do
            local weaponData = RunStartControl.WeaponAspectData[i]
            for j = 1, TableLength(weaponData.Aspects) do
                local aspectID = weaponData.Aspects[j]
                local gridX = math.ceil((idx+1) / nrows)
                local gridY = idx % nrows + 1
                CreateHammerPicker( screen, weaponData.Name, aspectID, gridX, gridY)
                idx = idx + 1
            end
        end
    end
end

RunStartControl.MenuXPositions = {
    200, 504, 808, 1112, 1416, 1720
}
RunStartControl.MenuYPositions = {
    400, 580, 760, 940
}

function CreateHammerPicker( screen, weapon, aspect, gridX, gridY)
    local xpos = RunStartControl.MenuXPositions[gridX]
    local ypos = RunStartControl.MenuYPositions[gridY]

    screen.Components["HammerPickerLeft"..aspect] = CreateScreenComponent({ Name = "ButtonCodexDown", X = xpos - 120, Y = ypos, Scale = 1.0, Group = "Combat_Menu"})
    SetAngle({ Id = screen.Components["HammerPickerLeft"..aspect].Id, Angle = -90})
    SetScale({ Id = screen.Components["HammerPickerLeft"..aspect].Id, Fraction = 0.55})
    screen.Components["HammerPickerLeft"..aspect].OnPressedFunctionName = "HammerPickerLeft"
    screen.Components["HammerPickerLeft"..aspect].args = {
        Aspect = aspect
    }

    screen.Components["HammerPickerRight"..aspect] = CreateScreenComponent({ Name = "ButtonCodexDown", X = xpos + 120, Y = ypos, Scale = 1.0, Group = "Combat_Menu"})
    SetAngle({ Id = screen.Components["HammerPickerRight"..aspect].Id, Angle = 90})
    SetScale({ Id = screen.Components["HammerPickerRight"..aspect].Id, Fraction = 0.55})
    screen.Components["HammerPickerRight"..aspect].OnPressedFunctionName = "HammerPickerRight"
    screen.Components["HammerPickerRight"..aspect].args = {
        Aspect = aspect
    }

    screen.Components["HammerPicker"..aspect] = CreateScreenComponent({ Name = "BlankObstacle", Scale = 0.5, Group = "Combat_Menu", X = xpos, Y = ypos})

    -- text boks
    CreateTextBox({ Id = screen.Components["HammerPicker"..aspect].Id,
      Text = GameState.RunStartControl.AspectSettings[aspect].Hammer,
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
    screen.Components["AspectIcon"..aspect] = CreateScreenComponent({ Name = "BlankObstacle", Scale = 0.8, Group = "Combat_Menu", X = xpos, Y = ypos - 90 })
    local aspectIcon = TraitData[aspect].Icon .. "_Large"
    SetAnimation({ DestinationId = screen.Components["AspectIcon"..aspect].Id, Name = aspectIcon})
    
end


function HammerPickerMove( screen, button, offset )
    local aspect = button.args.Aspect
    
    local hammers = RunStartControl.HammerOptions[aspect]

    local currentHammer = GameState.RunStartControl.AspectSettings[aspect].Hammer
    local weapon = GameState.RunStartControl.AspectSettings[aspect].Weapon

    local hammerIndex = nil
    for i, hammer in ipairs(hammers) do
        if hammer == currentHammer then
            hammerIndex = i
            break
        end
    end
    hammerIndex = hammerIndex + offset

    if hammerIndex <= 0 then
        hammerIndex = TableLength(RunStartControl.HammerOptions[aspect]) + hammerIndex
    elseif hammerIndex > TableLength(RunStartControl.HammerOptions[aspect]) then
        hammerIndex = hammerIndex - TableLength(RunStartControl.HammerOptions[aspect])
    end

    local newHammer = RunStartControl.HammerOptions[aspect][hammerIndex]

    RunStartControl.SetAspectSettings(weapon, aspect, newHammer, nil, nil, nil, nil)

    ModifyTextBox({ Id = screen.Components["HammerPicker"..aspect].Id, Text = GameState.RunStartControl.AspectSettings[aspect].Hammer})
end

function HammerPickerLeft(screen, button)
    HammerPickerMove(screen, button, -1)
end

function HammerPickerRight(screen, button)
    HammerPickerMove(screen, button, 1)
end

ModUtil.LoadOnce(function()
    if RunStartControl.config.Menu == "configmenu" then
        ModConfigMenu.RegisterMenuOverride({ModName = "Aspect Hammer Settings"}, RunStartControl.CreateAspectConfigMenu)
    end
  end)