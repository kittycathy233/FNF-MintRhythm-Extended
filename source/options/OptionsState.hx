package options;

import states.MainMenuState;
import backend.StageData;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.input.mouse.FlxMouse;
import flixel.ui.FlxButton;

class OptionsState extends MusicBeatState
{
	public var options:Array<String> = [
		Language.get("note_colors"),
		Language.get("controls"),
		Language.get("adjust_delay_combo"),
		Language.get("adjust_rating_offset"),
		Language.get("graphics"),
		Language.get("visuals"),
		Language.get("gameplay")
		#if (cpp && windows && !mobile), Language.get("window_manager") #end,
		Language.get("extra_options")
		, Language.get("spam_chart")
		//#if TRANSLATIONS_ALLOWED , Language.get("language") #end
		#if mobile , Language.get("mobile_options") #end
	];
	
	public var optionDescriptions:Array<String> = [
		Language.get("note_colors_desc"),
		Language.get("controls_desc"),
		Language.get("adjust_delay_combo_desc"),
		Language.get("adjust_rating_offset_desc"),
		Language.get("graphics_desc"),
		Language.get("visuals_desc"),
		Language.get("gameplay_desc")
		#if (cpp && windows && !mobile), Language.get("window_manager_desc") #end,
		Language.get("extra_options_desc")
		, Language.get("spam_chart_desc")
		#if mobile , Language.get("mobile_options_desc") #end
	];
	
	private var grpOptions:FlxTypedGroup<FlxText>;
	private static var curSelected:Int = 0;
	private static var lastOptionsSelection:Int = 0; // 记住主设置菜单上次选中的项（仅本次会话）
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;

	var selectorLeft:FlxText;
	var selectorRight:FlxText;
	var descriptionText:FlxText;
	var adminButton:FlxButton;

	private var _inSubState:Bool = false;

	private var itemSpacing:Int = 72; // 减小垂直间距
	private var startY:Float = 0;
	private var gridCols:Int = 2; // 双栏布局列数
	private var gridRows:Int = 0; // 每列行数（运行时计算）

	private var hideSelectors:Bool = false; // 是否隐藏选择器

	private var selectorLeftTargetX:Float = 0;
	private var selectorLeftTargetY:Float = 0;
	private var selectorRightTargetX:Float = 0;
	private var selectorRightTargetY:Float = 0;

	private var allowInput:Bool = true;
	private var descriptionTween:FlxTween;

	private var lastClickTime:Float = 0;
	private var lastClickIndex:Int = -1;

	#if (cpp && windows && !mobile)
	private function onAdminButtonClick():Void {
		// 请求管理员权限
		var success = backend.Native.requestAdminPrivilege();

		// 如果返回 false，说明用户拒绝了 UAC 提示
		// 此时游戏不会退出，继续运行
		if (!success) {
			// 可选：显示提示信息
			FlxG.log.add("UAC prompt was declined by user");
		}
	}
	#end

	function openSelectedSubstate(label:String) {
		_inSubState = true; // 标记进入子状态，阻止主界面UI操作

		if (label != Language.get("adjust_delay_combo") && label != Language.get("adjust_rating_offset") && label != Language.get("extra_options")) {
			removeTouchPad();
			persistentUpdate = false;
		} else if (label == Language.get("extra_options")) {
			persistentUpdate = true;
		}

		var substateMap:Map<String, () -> Void> = [
			Language.get("note_colors") => () -> openSubState(ClientPrefs.data.arrowColorMode == 'HSV' ? new options.NotesColorSubStateLegacy() : new options.NotesColorSubState()),
			Language.get("controls") => () -> openSubState(new options.ControlsSubState()),
			Language.get("graphics") => () -> openSubState(new options.GraphicsSettingsSubState()),
			Language.get("visuals") => () -> openSubState(new options.VisualsSettingsSubState()),
			Language.get("gameplay") => () -> openSubState(new options.GameplaySettingsSubState()),
			Language.get("extra_options") => () -> {
				persistentUpdate = true;
				openSubState(new options.ExtraGameplaySettingSubState());
			},
			Language.get("spam_chart") => () -> openSubState(new options.SpamChartSettingsSubState()),
			Language.get("adjust_delay_combo") => () -> MusicBeatState.switchState(new options.NoteOffsetState()),
			Language.get("adjust_rating_offset") => () -> MusicBeatState.switchState(new options.RatingOffsetState()),
			Language.get("mobile_options") => () -> openSubState(new mobile.options.MobileOptionsSubState())
		];
		
		#if (cpp && windows && !mobile)
		substateMap[Language.get("window_manager")] = () -> {
			persistentUpdate = true;
			MusicBeatState.switchState(new states.WindowManagerState());
		};
		#end

		if (substateMap.exists(label)) {
			substateMap.get(label)();
		}
	}

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFF00BFFF;
		bg.updateHitbox();

		bg.screenCenter();
		add(bg);

		if (controls.mobileC)
		{
			var keyLabel:String = FlxG.onMobile ? 'C' : 'CTRL or C';
			var tipText:FlxText = new FlxText(150, FlxG.height - 24, 0, Language.get('mobile_controls_menu_tip', [keyLabel]), 16);
			tipText.setFormat(Paths.font(Language.get('game_font')), 17, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			tipText.borderSize = 1.25;
			tipText.scrollFactor.set();
			tipText.antialiasing = ClientPrefs.data.antialiasing;
			add(tipText);
		}

		grpOptions = new FlxTypedGroup<FlxText>();
		add(grpOptions);

		itemSpacing = OptionsConfig.ITEM_SPACING;
		// 双栏布局：窄屏（如手机）退化为单栏
		gridCols = (FlxG.width < 900) ? 1 : 2;
		gridRows = Std.int(Math.ceil(options.length / gridCols));
		var totalHeight = itemSpacing * gridRows;
		startY = (FlxG.height - totalHeight) / 2 + itemSpacing / 2;

		var leftColX = OptionsConfig.LEFT_MARGIN;
		var rightColX = (gridCols > 1) ? (Math.floor(FlxG.width * 0.5) + 40) : OptionsConfig.LEFT_MARGIN;

		for (num => option in options)
		{
			var col:Int = Std.int(num / gridRows);
			var row:Int = num % gridRows;
			var itemX = (col == 0) ? leftColX : rightColX;

			var optionText:FlxText = new FlxText(itemX, 0, 0, LanguageBasic.getPhrase('options_$option', option), 48);
			optionText.setFormat(Paths.font(Language.get('game_font')), 48, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			optionText.borderSize = 2;
			optionText.antialiasing = ClientPrefs.data.antialiasing;
			optionText.x = itemX;
			optionText.y = startY + row * itemSpacing;
			grpOptions.add(optionText);
		}

		selectorLeft = new FlxText(0, 0, 0, ">", 48);
		selectorLeft.setFormat(Paths.font(Language.get('game_font')), 48, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		selectorLeft.borderSize = 2;
		selectorLeft.antialiasing = ClientPrefs.data.antialiasing;
		add(selectorLeft);

		selectorRight = new FlxText(0, 0, 0, "<", 48);
		selectorRight.setFormat(Paths.font(Language.get('game_font')), 48, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		selectorRight.borderSize = 2;
		selectorRight.antialiasing = ClientPrefs.data.antialiasing;
		add(selectorRight);

		// 添加描述文本（水平居中、垂直偏下）
		descriptionText = new FlxText(100, FlxG.height - 120, FlxG.width - 200, optionDescriptions[curSelected], 24);
		descriptionText.setFormat(Paths.font(Language.get('game_font')), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descriptionText.borderSize = 1;
		descriptionText.antialiasing = ClientPrefs.data.antialiasing;
		descriptionText.scrollFactor.set();
		add(descriptionText);

		// 添加管理员权限按钮（仅在 Windows 平台且没有管理员权限时显示）
		#if (cpp && windows && !mobile)
		if (!backend.Native.isAdmin()) {
			adminButton = new FlxButton(FlxG.width - 220, 20, Language.get("request_admin_button"), onAdminButtonClick);
			adminButton.setGraphicSize(200, 40);
			adminButton.updateHitbox();
			adminButton.label.setFormat(Paths.font(Language.get('game_font')), 16, FlxColor.WHITE, CENTER);
			adminButton.label.fieldWidth = 200;
			adminButton.label.alignment = CENTER;
			add(adminButton);
		}
		#end

		// 初始化选择器目标位置
		changeSelection();

		// 直接设置选择器初始位置
		selectorLeft.x = selectorLeftTargetX;
		selectorLeft.y = selectorLeftTargetY;
		selectorRight.x = selectorRightTargetX;
		selectorRight.y = selectorRightTargetY;

		ClientPrefs.saveSettings();

		addTouchPad('LEFT_FULL', 'A_B_C');

		super.create();
		FlxG.mouse.visible = true;

		// 记住上次选中的项（仅本次游戏会话内有效，超出范围则回退到中间项）
		curSelected = Std.int(Math.max(0, Math.min(options.length - 1, lastOptionsSelection)));
		changeSelection(0); // 刷新高亮和描述
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
		controls.isInSubstate = false;
		removeTouchPad();
		addTouchPad('LEFT_FULL', 'A_B_C');
		persistentUpdate = true;
		allowInput = true;
		_inSubState = false; // 退出子状态
	}

	var exiting = false;
	override function update(elapsed:Float) {
		super.update(elapsed);

		// 按住 Shift 时快速滚动（每次跳 4 项，与 LanguageSubState 一致）
		var mult:Int = (FlxG.keys.pressed.SHIFT) ? 4 : 1;

		// 在子状态中，淡出选择器，但保持位置更新
		if (_inSubState) {
			// 更新选择器位置到当前选中项
			var selectedOption = grpOptions.members[curSelected];
			if (selectedOption != null)
			{
				selectorLeftTargetX = selectedOption.x - 63;
				selectorLeftTargetY = selectedOption.y;
				selectorRightTargetX = selectedOption.x + selectedOption.width + 15;
				selectorRightTargetY = selectedOption.y;

				// 平滑移动到目标位置
				selectorLeft.x = FlxMath.lerp(selectorLeftTargetX, selectorLeft.x, Math.exp(-elapsed * OptionsConfig.SELECTOR_LERP_SPEED));
				selectorLeft.y = FlxMath.lerp(selectorLeftTargetY, selectorLeft.y, Math.exp(-elapsed * OptionsConfig.SELECTOR_LERP_SPEED));
				selectorRight.x = FlxMath.lerp(selectorRightTargetX, selectorRight.x, Math.exp(-elapsed * OptionsConfig.SELECTOR_LERP_SPEED));
				selectorRight.y = FlxMath.lerp(selectorRightTargetY, selectorRight.y, Math.exp(-elapsed * OptionsConfig.SELECTOR_LERP_SPEED));
			}

			// 淡出选择器
			selectorLeft.alpha = FlxMath.lerp(0, selectorLeft.alpha, Math.exp(-elapsed * 10));
			selectorRight.alpha = FlxMath.lerp(0, selectorRight.alpha, Math.exp(-elapsed * 10));
			return;
		}

		// 根据hideSelectors标志控制选择器显示/隐藏
		var targetAlpha:Float = hideSelectors ? 0 : 1;
		selectorLeft.alpha = FlxMath.lerp(targetAlpha, selectorLeft.alpha, Math.exp(-elapsed * 10));
		selectorRight.alpha = FlxMath.lerp(targetAlpha, selectorRight.alpha, Math.exp(-elapsed * 10));

		// 始终显示鼠标指针
		FlxG.mouse.visible = true;

		// 仅在允许输入时处理按键
		if (allowInput) {
			if (!exiting) {
				if (controls.UI_UP_P) {
					changeSelection(0, -1 * mult);
					hideSelectors = false; // 键盘输入恢复显示
				}
				if (controls.UI_DOWN_P) {
					changeSelection(0, 1 * mult);
					hideSelectors = false; // 键盘输入恢复显示
				}
				if (controls.UI_LEFT_P || (touchPad != null && touchPad.buttonLeft.justPressed)) {
					changeSelection(-1 * mult, 0);
					hideSelectors = false;
				}
				if (controls.UI_RIGHT_P || (touchPad != null && touchPad.buttonRight.justPressed)) {
					changeSelection(1 * mult, 0);
					hideSelectors = false;
				}

				if (touchPad.buttonC.justPressed || FlxG.keys.justPressed.CONTROL && controls.mobileC)
				{
					persistentUpdate = false;
					openSubState(new mobile.substates.MobileControlSelectSubState());
				}

				if (controls.BACK)
				{
					exiting = true;
					FlxG.sound.play(Paths.sound('cancelMenu'));
					if (onPlayState)
					{
						StageData.loadDirectory(PlayState.SONG);
						LoadingState.loadAndSwitchState(new PlayState());
						FlxG.sound.music.volume = 0;
					}
					else MusicBeatState.switchState(new MainMenuState());
				}
				else if (controls.ACCEPT) {
					openSelectedSubstate(options[curSelected]);
					hideSelectors = false; // 键盘输入恢复显示
				}
			}
		}

		// --- 移动端虚拟按键检测 ---
		#if mobile
		// 检查虚拟按键是否被按下（除了C按钮，它有单独的功能）
		if (touchPad != null) {
			var anyButtonPressed = touchPad.buttonUp.pressed || touchPad.buttonDown.pressed ||
			                       touchPad.buttonLeft.pressed || touchPad.buttonRight.pressed ||
			                       touchPad.buttonA.pressed || touchPad.buttonB.pressed;
			if (anyButtonPressed) {
				hideSelectors = true; // 虚拟按键按下时隐藏选择器
			} else if (touchPad.buttonC.justReleased) {
				// C按钮松开时不隐藏选择器（它有单独的功能）
			}
		}
		#end

		// --- 鼠标拖动与点击选项 ---
		var mouse:FlxMouse = FlxG.mouse;
		var mouseOverOption:Int = -1;
		for (i in 0...grpOptions.length) {
			var opt = grpOptions.members[i];
			if (mouse.x >= opt.x && mouse.x <= opt.x + opt.width && mouse.y >= opt.y && mouse.y <= opt.y + opt.height) {
				mouseOverOption = i;
				break;
			}
		}

		// 鼠标单击选项自动更改选中项
		if (mouseOverOption != -1 && mouse.justPressed) {
			if (curSelected != mouseOverOption) {
				var targetCol:Int = Std.int(mouseOverOption / gridRows);
				var targetRow:Int = mouseOverOption % gridRows;
				var curCol:Int = Std.int(curSelected / gridRows);
				var curRow:Int = curSelected % gridRows;
				changeSelection(targetCol - curCol, targetRow - curRow);
			}
			hideSelectors = true; // 点击选项时隐藏选择器
			// 双击检测
			var now = FlxG.game.ticks / 1000.0;
			if (lastClickIndex == mouseOverOption && (now - lastClickTime) < OptionsConfig.DOUBLE_CLICK_THRESHOLD) {
				openSelectedSubstate(options[mouseOverOption]);
		}
		lastClickTime = now;
		lastClickIndex = mouseOverOption;
	}

		// 鼠标右键双击也可进入
		if (mouseOverOption != -1 && mouse.justPressedRight) {
			openSelectedSubstate(options[mouseOverOption]);
		}

		// 选中项动效
		for (i in 0...grpOptions.length)
		{
			var item = grpOptions.members[i];
			if (i == curSelected)
			{
				item.scale.x = FlxMath.lerp(OptionsConfig.SELECTED_SCALE, item.scale.x, Math.exp(-elapsed * OptionsConfig.SCALE_LERP_SPEED));
				item.scale.y = FlxMath.lerp(OptionsConfig.SELECTED_SCALE, item.scale.y, Math.exp(-elapsed * OptionsConfig.SCALE_LERP_SPEED));
			}
			else
			{
				item.scale.x = FlxMath.lerp(OptionsConfig.NORMAL_SCALE, item.scale.x, Math.exp(-elapsed * OptionsConfig.SCALE_LERP_SPEED));
				item.scale.y = FlxMath.lerp(OptionsConfig.NORMAL_SCALE, item.scale.y, Math.exp(-elapsed * OptionsConfig.SCALE_LERP_SPEED));
			}
		}

		// 更新选择器位置，使其跟随当前选中选项
		var selectedOption = grpOptions.members[curSelected];
		if (selectedOption != null)
		{
			selectorLeftTargetX = selectedOption.x - 63;
			selectorLeftTargetY = selectedOption.y;
			selectorRightTargetX = selectedOption.x + selectedOption.width + 15;
			selectorRightTargetY = selectedOption.y;
		}

		// < 和 > 选择器平滑动画
		selectorLeft.x = FlxMath.lerp(selectorLeftTargetX, selectorLeft.x, Math.exp(-elapsed * OptionsConfig.SELECTOR_LERP_SPEED));
		selectorLeft.y = FlxMath.lerp(selectorLeftTargetY, selectorLeft.y, Math.exp(-elapsed * OptionsConfig.SELECTOR_LERP_SPEED));
		selectorRight.x = FlxMath.lerp(selectorRightTargetX, selectorRight.x, Math.exp(-elapsed * OptionsConfig.SELECTOR_LERP_SPEED));
		selectorRight.y = FlxMath.lerp(selectorRightTargetY, selectorRight.y, Math.exp(-elapsed * OptionsConfig.SELECTOR_LERP_SPEED));
	}

	function changeSelection(dx:Int = 0, dy:Int = 0)
	{
		var col:Int = Std.int(curSelected / gridRows);
		var row:Int = curSelected % gridRows;

		// 左右切换列：在列之间环绕（左栏按左键跳到最右栏，右栏按右键跳到最左栏，与上下一致）
		col = Std.int(FlxMath.wrap(col + dx, 0, gridCols - 1));
		// 切列后把 row 钳制到目标列有效行内（最后一列可能不满整列）
		if (dx != 0)
		{
			var rowsInTargetCol:Int = (col < gridCols - 1) ? gridRows : (options.length - (gridCols - 1) * gridRows);
			if (rowsInTargetCol < 1) rowsInTargetCol = 1;
			row = Std.int(FlxMath.bound(row, 0, rowsInTargetCol - 1));
		}

		// 上下：在当前列内环绕（到顶/底可继续绕回）
		if (dy != 0)
		{
			var rowsInCol:Int = (col < gridCols - 1) ? gridRows : (options.length - (gridCols - 1) * gridRows);
			if (rowsInCol < 1) rowsInCol = 1;
			row = FlxMath.wrap(row + dy, 0, rowsInCol - 1);
		}

		var target = col * gridRows + row;
		// 目标位置在最后一列可能不存在（该项不足整列），夹到列表末项
		if (target >= options.length)
		{
			target = options.length - 1;
		}
		curSelected = target;

		// 记住当前选中项，下次进入主设置界面时恢复（仅本次会话，重启游戏后重置）
		if (dx != 0 || dy != 0)
		{
			lastOptionsSelection = curSelected;
		}

		var leftColX = OptionsConfig.LEFT_MARGIN;
		var rightColX = (gridCols > 1) ? (Math.floor(FlxG.width * 0.5) + 40) : OptionsConfig.LEFT_MARGIN;

		for (i in 0...grpOptions.length)
		{
			var icol:Int = Std.int(i / gridRows);
			var irow:Int = i % gridRows;
			var item = grpOptions.members[i];
			item.x = (icol == 0) ? leftColX : rightColX;
			item.y = startY + irow * itemSpacing;
			item.alpha = (i == curSelected) ? 1 : 0.6;
		}

		updateDescriptionText();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	// 更新描述文本
	private function updateDescriptionText():Void
	{
		descriptionText.text = optionDescriptions[curSelected];
		
		// 取消之前的tween
		if (descriptionTween != null) {
			descriptionTween.cancel();
			//descriptionTween.destroy();
		}
		
		// 重置位置并创建新的tween
		descriptionText.y = FlxG.height + OptionsConfig.DESC_Y_START;
		descriptionTween = FlxTween.tween(descriptionText,
			{y: FlxG.height + OptionsConfig.DESC_Y_END},
			OptionsConfig.TWEEN_DURATION,
			{
				ease: FlxEase.quadOut,
				onComplete: function(twn:FlxTween) {
					if (descriptionTween == twn)
						descriptionTween = null;
				}
			}
		);
	}

	public function refreshTexts()
	{
		// 更新选项文本
		for (i in 0...options.length)
		{
			var optionText = grpOptions.members[i];
			optionText.text = LanguageBasic.getPhrase('options_${options[i]}', options[i]);
		}

		// 更新描述文本
		if(curSelected >= 0 && curSelected < optionDescriptions.length) {
			descriptionText.text = optionDescriptions[curSelected];
		}

		// 重新计算选择器位置
		var selectedOption = grpOptions.members[curSelected];
		if (selectedOption != null)
		{
			selectorLeftTargetX = selectedOption.x - 63;
			selectorLeftTargetY = selectedOption.y;
			selectorRightTargetX = selectedOption.x + selectedOption.width + 15;
			selectorRightTargetY = selectedOption.y;
		}
	}

	override function draw()
	{
		// 在子状态打开时，强制选择器为完全透明（防止persistentUpdate=false时选择器可见）
		if (_inSubState && FlxG.state.subState != null)
		{
			// 更新选择器位置到当前选中项
			var selectedOption = grpOptions.members[curSelected];
			if (selectedOption != null)
			{
				selectorLeft.x = selectedOption.x - 63;
				selectorLeft.y = selectedOption.y;
				selectorRight.x = selectedOption.x + selectedOption.width + 15;
				selectorRight.y = selectedOption.y;
			}

			// 强制选择器为完全透明
			selectorLeft.alpha = 0;
			selectorRight.alpha = 0;
		}

		super.draw();
	}

	override function destroy()
	{
		if (descriptionTween != null)
		{
			descriptionTween.cancel();
			descriptionTween.destroy();
		}
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}