package options;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepadManager;

import objects.CheckboxThingie;
import objects.AttachedText;
import options.Option;
import backend.InputFormatter;

import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import backend.CoolUtil;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var descBox:FlxSprite;
	private var descText:FlxText;

	private var _optionsBuildIndex:Int = 0;
	private var _optionsBuilt:Bool = false;
	private var _buildPerFrame:Int = 1;
	private var _loadingText:FlxText = null;
	private var _grid:FlxBackdrop;

	public var title:String;
	public var rpcTitle:String;

	public var bg:FlxSprite;
	public var bg1:FlxSprite;
	public var bg2:FlxSprite;
	public function new()
	{
		controls.isInSubstate = true;

		super();

		if(title == null) title = 'Options';
		if(rpcTitle == null) rpcTitle = 'Options Menu';
		
		#if DISCORD_ALLOWED
		DiscordClient.changePresence(rpcTitle, null);
		#end

		bg2 = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg2.screenCenter();
		bg2.antialiasing = ClientPrefs.data.antialiasing;
		bg2.alpha = 0;
		add(bg2);
		FlxTween.tween(bg2, {alpha: 0.6}, 0.5, {ease: FlxEase.quadOut});

		// 添加背景方块移动效果（加载完成后才显示）
		_grid = new FlxBackdrop(CoolUtil.getCachedGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		_grid.velocity.set(40, 40);
		_grid.visible = false;
		add(_grid);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		var titleText:Alphabet = new Alphabet(75, 45, title, true);
		titleText.setScale(0.6);
		titleText.alpha = 0.4;
		add(titleText);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		// 加载提示文字
		_loadingText = new FlxText(20, 0, 0, 'Loading...\nPlease wait...', 24);
		_loadingText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		_loadingText.scrollFactor.set();
		_loadingText.borderSize = 2;
		_loadingText.antialiasing = ClientPrefs.data.antialiasing;
		_loadingText.y = 100;
		_loadingText.x = FlxG.width - _loadingText.width - 100;
		add(_loadingText);

		// Initialize keybind manager
		keybindManager = new KeybindManager();

		addTouchPad('LEFT_FULL', 'A_B_C');
		addTouchPadCamera();

		// 分帧构建选项，避免单帧创建大量 Alphabet sprite 导致卡顿
		_optionsBuildIndex = 0;
		_optionsBuilt = false;
		if (optionsArray == null) optionsArray = [];
	}

	private function buildNextOptions():Void
	{
		var count:Int = 0;
		while (_optionsBuildIndex < optionsArray.length && count < _buildPerFrame)
		{
			var i:Int = _optionsBuildIndex;
			var optionText:Alphabet = new Alphabet(220, 260, optionsArray[i].name, false);
			optionText.isMenuItem = true;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(optionsArray[i].type == BOOL)
			{
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, Std.string(optionsArray[i].getValue()) == 'true');
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				if (optionsArray[i].disabled) checkbox.alpha = 0.3;
				checkboxGroup.add(checkbox);
			}
			else if (optionsArray[i].type != BUTTON)
			{
				optionText.x -= 80;
				optionText.startPosition.x -= 80;
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), optionText.width + 60);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				if (optionsArray[i].disabled) valueText.alpha = 0.3;
				grpTexts.add(valueText);
				optionsArray[i].child = valueText;
			}
			else
			{
				optionText.x -= 80;
				optionText.startPosition.x -= 80;
			}
			if (optionsArray[i].type != BUTTON) {
				updateTextFrom(optionsArray[i]);
			}

			_optionsBuildIndex++;
			count++;
		}

		if (_optionsBuildIndex >= optionsArray.length)
		{
			_optionsBuilt = true;
			changeSelection();
			reloadCheckboxes();
			onOptionsBuilt();
		}
	}

	public function onOptionsBuilt():Void
	{
		if (_grid != null)
		{
			_grid.visible = true;
			_grid.alpha = 0;
			FlxTween.tween(_grid, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		}

		if (_loadingText != null)
		{
			_loadingText.text = LanguageBasic.getPhrase('done', 'Done');
			FlxTween.tween(_loadingText, {alpha: 0, y: _loadingText.y + 20}, 0.5, {ease: FlxEase.quadIn, onComplete: function(tween:FlxTween) {
				if (_loadingText != null)
				{
					remove(_loadingText);
					_loadingText.destroy();
					_loadingText = null;
				}
			}});
		}
	}

	public function addOption(option:Option) {
		if(optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
		return option;
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;

	var keybindManager:KeybindManager;
	var lastMouseClickTime:Float = 0;
	var lastMouseClickIndex:Int = -1;
	override function update(elapsed:Float)
	{
		if (!_optionsBuilt)
		{
			buildNextOptions();
			super.update(elapsed);
			return;
		}

		super.update(elapsed);

#if !mobile
		// 鼠标滚轮切换选项
		if (FlxG.mouse.wheel != 0) {
			changeSelection(FlxG.mouse.wheel > 0 ? -1 : 1);
		}

		// 检测鼠标左右键
		if (FlxG.mouse.justPressed) {
			var now = FlxG.game.ticks / 1000.0;
			if (lastMouseClickIndex == curSelected && (now - lastMouseClickTime) < OptionsConfig.DOUBLE_CLICK_THRESHOLD) {
				// 双击，什么都不做（交由右键或其它逻辑处理）
			} else {
				// 单击，BOOL类型切换
				if (curOption != null && curOption.type == BOOL && !curOption.disabled) {
					// 检查鼠标是否点击在复选框区域内
					var checkbox:CheckboxThingie = null;
					for (cb in checkboxGroup) {
						if (cb.ID == curSelected) {
							checkbox = cb;
							break;
						}
					}
					
					// 只有在复选框内点击才切换状态
					if (checkbox != null && 
						FlxG.mouse.x >= checkbox.x && 
						FlxG.mouse.x <= checkbox.x + checkbox.width &&
						FlxG.mouse.y >= checkbox.y && 
						FlxG.mouse.y <= checkbox.y + checkbox.height) {
						FlxG.sound.play(Paths.sound('scrollMenu'));
						curOption.setValue((curOption.getValue() == true) ? false : true);
						curOption.change();
						reloadCheckboxes();
					}
				}
			}
			lastMouseClickTime = now;
			lastMouseClickIndex = curSelected;
		}
		if (FlxG.mouse.justPressedRight) {
			// 鼠标右键退出
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
#end

		// Handle keybinding
		if (keybindManager != null && keybindManager.isBinding) {
			if (keybindManager.update(elapsed)) {
				reloadCheckboxes();
			}
			return;
		}

		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		if (controls.BACK) {
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept <= 0)
		{
			if(curOption.disabled)
			{
				// 禁用的选项不允许修改
			}
			else
			{
				switch(curOption.type)
				{
					case BOOL:
						if(controls.ACCEPT)
						{
							FlxG.sound.play(Paths.sound('scrollMenu'));
							curOption.setValue((curOption.getValue() == true) ? false : true);
							curOption.change();
							reloadCheckboxes();
						}

					case KEYBIND:
						if(controls.ACCEPT)
						{
							keybindManager.startBinding(curOption, function() {
								reloadCheckboxes();
							});
							if (keybindManager.getOverlay() != null) add(keybindManager.getOverlay());
							if (keybindManager.getTitle() != null) add(keybindManager.getTitle());
							if (keybindManager.getInstructions() != null) add(keybindManager.getInstructions());
						}

					case BUTTON:
						if(controls.ACCEPT)
						{
							FlxG.sound.play(Paths.sound('scrollMenu'));
							curOption.change();
						}

					default:
						if(controls.UI_LEFT || controls.UI_RIGHT)
						{
							var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
							if(holdTime > OptionsConfig.INPUT_COOLDOWN || pressed)
							{
								if(pressed)
								{
									var add:Dynamic = null;
									if(curOption.type != STRING)
										add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;

									switch(curOption.type)
									{
										case INT, FLOAT, PERCENT:
											holdValue = curOption.getValue() + add;
											if(holdValue < curOption.minValue) holdValue = curOption.minValue;
											else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

											if(curOption.type == INT)
											{
												holdValue = Math.round(holdValue);
												curOption.setValue(holdValue);
											}
											else
											{
												holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
												curOption.setValue(holdValue);
											}

										case STRING:
											var num:Int = curOption.curOption;
											if(controls.UI_LEFT_P) --num;
											else num++;

											if(num < 0)
												num = curOption.options.length - 1;
											else if(num >= curOption.options.length)
												num = 0;

											curOption.curOption = num;
											curOption.setValue(curOption.options[num]);

										default:
									}
									updateTextFrom(curOption);
									curOption.change();
									FlxG.sound.play(Paths.sound('scrollMenu'));
								}
								else if(curOption.type != STRING)
								{
									holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
									if(holdValue < curOption.minValue) holdValue = curOption.minValue;
									else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

									switch(curOption.type)
									{
										case INT:
											curOption.setValue(Math.round(holdValue));

										case PERCENT:
											curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));

										default:
									}
									updateTextFrom(curOption);
									curOption.change();
								}
							}

							if(curOption.type != STRING)
								holdTime += elapsed;
						}
						else if(controls.UI_LEFT_R || controls.UI_RIGHT_R)
						{
							if(holdTime > OptionsConfig.INPUT_COOLDOWN) FlxG.sound.play(Paths.sound('scrollMenu'));
							holdTime = 0;
						}
				}
			}

			if(controls.RESET || touchPad.buttonC.justPressed)
			{
				var leOption:Option = optionsArray[curSelected];
				if(!leOption.disabled)
				{
					if(leOption.type != KEYBIND)
					{
						leOption.setValue(leOption.defaultValue);
						if(leOption.type != BOOL)
						{
							if(leOption.type == STRING) leOption.curOption = leOption.options.indexOf(leOption.getValue());
							updateTextFrom(leOption);
						}
					}
					else
					{
						leOption.setValue(!Controls.instance.controllerMode ? leOption.defaultKeys.keyboard : leOption.defaultKeys.gamepad);
						if (keybindManager != null) {
							keybindManager.updateBindDisplay(null, leOption, grpTexts);
						}
					}
					leOption.change();
					FlxG.sound.play(Paths.sound('cancelMenu'));
					reloadCheckboxes();
				}
			}
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
	}

	function updateTextFrom(option:Option) {
		if(option.type == KEYBIND)
		{
			if (keybindManager != null) {
				keybindManager.updateBindDisplay(null, option, grpTexts);
			}
			return;
		}

		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == PERCENT) val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}
	
	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, optionsArray.length - 1);

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter(Y);
		descText.y += 270;

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0) item.alpha = 1;
			// 禁用选项淡化（即便选中状态也会变淡）
			if (optionsArray[num].disabled)
			{
				if (item.targetY == 0) item.alpha = 0.55;
				else item.alpha = 0.3;
			}
		}
		for (text in grpTexts)
		{
			text.alpha = 0.6;
			if(text.ID == curSelected) text.alpha = 1;
			if (optionsArray[text.ID].disabled)
			{
				if (text.ID == curSelected) text.alpha = 0.55;
				else text.alpha = 0.3;
			}
		}
		for (checkbox in checkboxGroup)
		{
			if (optionsArray[checkbox.ID].disabled)
				checkbox.alpha = 0.3;
			else
				checkbox.alpha = 1;
		}

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		curOption = optionsArray[curSelected]; //shorter lol
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function reloadCheckboxes()
		for (checkbox in checkboxGroup)
			checkbox.daValue = Std.string(optionsArray[checkbox.ID].getValue()) == 'true'; //Do not take off the Std.string() from this, it will break a thing in Mod Settings Menu
	
	function refreshAllTexts() {
		// 刷新标题
		//titleText.text = title;

		// 刷新选项文本
		for (i in 0...grpOptions.length) {
			var opt = grpOptions.members[i];
			opt.text = optionsArray[i].name;
		}

		// 刷新描述
		descText.text = optionsArray[curSelected].description;
	}

	override function destroy()
	{
		if (keybindManager != null)
		{
			keybindManager.destroy();
			keybindManager = null;
		}
		if (_loadingText != null)
			FlxTween.cancelTweensOf(_loadingText);
		super.destroy();
	}

	override function closeSubState()
	{
		super.closeSubState();
		controls.isInSubstate = false;
		removeTouchPad();
		addTouchPad('LEFT_FULL', 'A_B_C');
	}
}