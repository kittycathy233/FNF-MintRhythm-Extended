-- PLACE THIS IN yourmod/scripts/!!
-- ONLY FOR EXTRA KEYS

local needsExtraKeys = false
function onStartCountdown()
    if getPropertyFromClass('states.MainMenuState', 'extraKeysVersion') == nil then
        makeLuaSprite('black', nil, 0,0)
        makeGraphic('black', 1280, 720, '000000')
        addLuaSprite('black')
        setObjectCamera('black', 'other')

        local ekScript = 'Press ENTER to download it now.'

        makeLuaText('text', 'Hey! It looks like you are not using \nPsych Engine with Extra Keys.\nThis mod requires it to be played.\n\n' .. ekScript, 0, 100, 100)
        setTextSize('text', 18)
        addLuaText('text')
        setObjectCamera('text', 'other')

        needsExtraKeys = true
        return Function_Stop
    end
end

function onUpdatePost()
    if needsExtraKeys then
        local ekScript = 'Press ENTER to download it now.'
        if buildTarget == 'android' or buildTarget == 'unknown' then
            ekScript = 'Tap the screen to download it now.\n\n(If you can\'t open the browser, go to \nhttps://www.gamebanana.com/mods/333373/ \nand download the appropiate version.)'
        end
        if getPropertyFromClass('backend.Controls', 'instance.controllerMode') then
            ekScript = 'Press A to download it now.'
        end
        setTextString('text', 'Hey! It looks like you are not using \nPsych Engine with Extra Keys.\nThis mod requires it to be played.\n\n' .. ekScript)

        if getPropertyFromClass('backend.Controls', 'instance.controllerMode') then --ps4 controller check
            runHaxeCode([[
                import flixel.input.gamepad.FlxGamepad;
                import flixel.input.gamepad.FlxGamepadModel;
                var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
                if (gamepad.detectedModel == FlxGamepadModel.PS4) {
                    game.modchartTexts['text'].text = 'Hey! It looks like you are not using \nPsych Engine with Extra Keys.\nThis mod requires it to be played.\n\nPress X to download it now.';    
                }
            ]])
        end

        if keyboardJustPressed('ENTER') or anyGamepadJustPressed('A') then
            runHaxeCode([[
                import backend.CoolUtil;
                CoolUtil.browserLoad("https://www.gamebanana.com/mods/333373/");
            ]])
        end
        if (buildTarget == 'android' or buildTarget == 'unknown') and mouseClicked() then --mobile
            runHaxeCode([[
                import backend.CoolUtil;
                CoolUtil.browserLoad("https://www.gamebanana.com/mods/333373/");
            ]])
        end
    end
end
