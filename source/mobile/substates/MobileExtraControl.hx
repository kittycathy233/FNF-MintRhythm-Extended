/*
 * Extra Controls key binding UI, ported & adapted for KathyEngine.
 * Lets the player pick which specific key each extra (touch) button simulates.
 */

package mobile.substates;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.ClientPrefs;
import mobile.backend.TouchUtil;

// 单个键的布局描述：n=物理键名（大写，供脚本检测），d=按钮上显示文本，w=占据的基础列宽（单位）
typedef CKey = { n:String, d:String, w:Float };
// 一行键的布局描述：y=纵向行号，right=是否位于右侧功能区，center=是否在右侧区内居中，keys=该行键列表
typedef KRow = { y:Int, right:Bool, center:Bool, keys:Array<CKey> };

class MobileExtraControl extends MusicBeatSubstate
{
	// 父级设置菜单，销毁时需恢复其为当前活动实例，否则父界面的触控导航会失效
	var parentMenu:MusicBeatSubstate;

	public function new(?parentMenu:MusicBeatSubstate = null)
	{
		super();
		this.parentMenu = parentMenu;
		// 让父菜单停止更新
		persistentUpdate = false;
	}

	// 87 键物理键盘布局（TKL：主键区 + 功能键行 + 右侧导航/方向键）。
	// 每行键按「宽修饰键」自然错位，接近真实键盘外观。右区各行与对应主行同高。
	static final LAYOUT:Array<KRow> = [
		// 功能行：Esc + F1~F12
		{ y: 0, right: false, center: false, keys: [
			{ n: 'ESCAPE', d: 'Esc', w: 1 }, { n: 'F1', d: 'F1', w: 1 }, { n: 'F2', d: 'F2', w: 1 },
			{ n: 'F3', d: 'F3', w: 1 }, { n: 'F4', d: 'F4', w: 1 }, { n: 'F5', d: 'F5', w: 1 },
			{ n: 'F6', d: 'F6', w: 1 }, { n: 'F7', d: 'F7', w: 1 }, { n: 'F8', d: 'F8', w: 1 },
			{ n: 'F9', d: 'F9', w: 1 }, { n: 'F10', d: 'F10', w: 1 }, { n: 'F11', d: 'F11', w: 1 },
			{ n: 'F12', d: 'F12', w: 1 }
		]},
		// 数字行：` + 0~9 + - = + 退格
		{ y: 1, right: false, center: false, keys: [
			{ n: 'GRAVE', d: '`', w: 1 }, { n: 'ONE', d: '1', w: 1 }, { n: 'TWO', d: '2', w: 1 },
			{ n: 'THREE', d: '3', w: 1 }, { n: 'FOUR', d: '4', w: 1 }, { n: 'FIVE', d: '5', w: 1 },
			{ n: 'SIX', d: '6', w: 1 }, { n: 'SEVEN', d: '7', w: 1 }, { n: 'EIGHT', d: '8', w: 1 },
			{ n: 'NINE', d: '9', w: 1 }, { n: 'ZERO', d: '0', w: 1 }, { n: 'MINUS', d: '-', w: 1 },
			{ n: 'EQUALS', d: '=', w: 1 }, { n: 'BACKSPACE', d: 'Back', w: 2 }
		]},
		// QWERTY 行：Tab + Q~P + [ ] \ + 斜杠
		{ y: 2, right: false, center: false, keys: [
			{ n: 'TAB', d: 'Tab', w: 1.5 }, { n: 'Q', d: 'Q', w: 1 }, { n: 'W', d: 'W', w: 1 },
			{ n: 'E', d: 'E', w: 1 }, { n: 'R', d: 'R', w: 1 }, { n: 'T', d: 'T', w: 1 },
			{ n: 'Y', d: 'Y', w: 1 }, { n: 'U', d: 'U', w: 1 }, { n: 'I', d: 'I', w: 1 },
			{ n: 'O', d: 'O', w: 1 }, { n: 'P', d: 'P', w: 1 }, { n: 'LBRACKET', d: '[', w: 1 },
			{ n: 'RBRACKET', d: ']', w: 1 }, { n: 'BACKSLASH', d: '\\', w: 1.5 }
		]},
		// 主键行：Caps + A~L + ; ' + 回车
		{ y: 3, right: false, center: false, keys: [
			{ n: 'CAPS_LOCK', d: 'Caps', w: 1.75 }, { n: 'A', d: 'A', w: 1 }, { n: 'S', d: 'S', w: 1 },
			{ n: 'D', d: 'D', w: 1 }, { n: 'F', d: 'F', w: 1 }, { n: 'G', d: 'G', w: 1 },
			{ n: 'H', d: 'H', w: 1 }, { n: 'J', d: 'J', w: 1 }, { n: 'K', d: 'K', w: 1 },
			{ n: 'L', d: 'L', w: 1 }, { n: 'SEMICOLON', d: ';', w: 1 }, { n: 'QUOTE', d: "'", w: 1 },
			{ n: 'ENTER', d: 'Enter', w: 2.25 }
		]},
		// Shift 行：Shift + Z~M + , . / + 右Shift
		{ y: 4, right: false, center: false, keys: [
			{ n: 'SHIFT', d: 'Shift', w: 2.25 }, { n: 'Z', d: 'Z', w: 1 }, { n: 'X', d: 'X', w: 1 },
			{ n: 'C', d: 'C', w: 1 }, { n: 'V', d: 'V', w: 1 }, { n: 'B', d: 'B', w: 1 },
			{ n: 'N', d: 'N', w: 1 }, { n: 'M', d: 'M', w: 1 }, { n: 'COMMA', d: ',', w: 1 },
			{ n: 'PERIOD', d: '.', w: 1 }, { n: 'SLASH', d: '/', w: 1 }, { n: 'SHIFT', d: 'Shift', w: 2.75 }
		]},
		// 底部行：Ctrl + Win + Alt + 空格 + Alt + Win + Menu + Ctrl（总宽须 =15 单位，避免与右侧方向键重叠）
		{ y: 5, right: false, center: false, keys: [
			{ n: 'CONTROL', d: 'Ctrl', w: 1.25 }, { n: 'WIN', d: 'Win', w: 1.25 }, { n: 'ALT', d: 'Alt', w: 1.25 },
			{ n: 'SPACE', d: 'Space', w: 6.25 }, { n: 'ALT', d: 'Alt', w: 1.25 }, { n: 'WIN', d: 'Win', w: 1.25 },
			{ n: 'MENU', d: 'Menu', w: 1.25 }, { n: 'CONTROL', d: 'Ctrl', w: 1.25 }
		]},
		// 右侧功能键列（PrtSc / ScrLk / Pause）
		{ y: 0, right: true, center: false, keys: [
			{ n: 'PRINTSCREEN', d: 'PrtSc', w: 1 }, { n: 'SCROLLLOCK', d: 'ScLk', w: 1 }, { n: 'PAUSE', d: 'Pause', w: 1 }
		]},
		// 右侧编辑键列（Ins / Home / PgUp）
		{ y: 1, right: true, center: false, keys: [
			{ n: 'INSERT', d: 'Ins', w: 1 }, { n: 'HOME', d: 'Home', w: 1 }, { n: 'PAGEUP', d: 'PgUp', w: 1 }
		]},
		// 右侧编辑键列（Del / End / PgDn）
		{ y: 2, right: true, center: false, keys: [
			{ n: 'DELETE', d: 'Del', w: 1 }, { n: 'END', d: 'End', w: 1 }, { n: 'PAGEDOWN', d: 'PgDn', w: 1 }
		]},
		// 方向键（右下方）
		{ y: 4, right: true, center: true, keys: [
			{ n: 'UP', d: 'Up', w: 1 }
		]},
		{ y: 5, right: true, center: false, keys: [
			{ n: 'LEFT', d: 'Left', w: 1 }, { n: 'DOWN', d: 'Down', w: 1 }, { n: 'RIGHT', d: 'Right', w: 1 }
		]}
	];
	var ui:FlxCamera;

	var slotBgs:Array<FlxSprite> = [];
	var slotLabels:Array<FlxText> = [];
	var keyBgs:Array<FlxSprite> = [];
	var keyLabels:Array<FlxText> = [];
	var allKeyNames:Array<String> = []; // 平铺后的物理键名，与 keyBgs 一一对应
	var allKeyDisps:Array<String> = []; // 平铺后的显示文本，与 keyBgs 一一对应


	var curSlot:Int = -1; // 当前选中的槽位（-1 表示未选中任何槽位）
	var extraEnabled:Int = 0; // 当前启用的额外键数量

	// 底部按钮的按压状态（按下反馈、松手才触发）
	var exitPressed:Bool = false;
	var resetPressed:Bool = false;

	override function create()
	{
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		// Std.parseInt 返回 Null<Int>，先转成普通 Int 再夹取到 0~4
		var raw:Null<Int> = Std.parseInt(ClientPrefs.data.extraButtons);
		extraEnabled = (raw == null) ? 0 : raw;
		if (extraEnabled < 0) extraEnabled = 0;
		if (extraEnabled > 4) extraEnabled = 4;

		// 半透明提亮背景（白，替代原先的黑色暗化）
		var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
		bg.scrollFactor.set();
		bg.alpha = 0.45;
		add(bg);

		// 标题
		var title:FlxText = new FlxText(0, 24, FlxG.width, Language.get('extra_key_bindings'));
		title.setFormat(Paths.font(Language.get('uitab_font')), 38, FlxColor.BLACK, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.WHITE);
		title.borderSize = 2;
		add(title);

		// 4 个绑定槽位
		var slotW:Float = (FlxG.width - 60) / 4;
		var slotH:Float = 64;
		var slotY:Float = 84;
		var slotGap:Float = 12;
		var totalW:Float = slotW * 4 + slotGap * 3;
		var startX:Float = (FlxG.width - totalW) / 2;
		for (i in 0...4)
		{
			var x:Float = startX + i * (slotW + slotGap);
			var bgBt:FlxSprite = new FlxSprite(x, slotY).makeGraphic(Std.int(slotW), Std.int(slotH), FlxColor.WHITE);
			bgBt.alpha = i < extraEnabled ? 0.95 : 0.35;
			add(bgBt);

			var keyName:String = Reflect.field(ClientPrefs.data, 'extraKeyReturn' + (i + 1));
			var label:FlxText = new FlxText(x, slotY, slotW);
			label.text = Language.get('extra_bind_slot') + ' ' + (i + 1) + '\n' + keyName;
			label.setFormat(Paths.font(Language.get('uitab_font')), i < extraEnabled ? 20 : 16, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 2;
			label.y += (slotH - label.height) / 2;
			add(label);

			slotBgs.push(bgBt);
			slotLabels.push(label);
		}

		// 提示语
		var hint:FlxText = new FlxText(0, slotY + slotH + 10, FlxG.width, Language.get('extra_bind_hint'));
		hint.setFormat(Paths.font(Language.get('uitab_font')), 16, 0xFF333333, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.WHITE);
		hint.borderSize = 1;
		add(hint);

		// 87 键键位（按物理键盘布局绘制）
		var gridGap:Float = 8;
		// 主键区最宽约 18 个单位 + 右侧功能列 3 个单位，留出边距后反算单列宽
		var unit:Float = (FlxG.width - 36 - 19 * gridGap) / 19.2;
		if (unit > 66) unit = 66;
		var keyH:Float = Math.min(46, unit * 0.86);
		var rightX:Float = 15 * unit + 16 * gridGap; // 主键区右边界（右侧功能区从此开始）
		// 整体居中：主键区 15 单位 + 右侧功能区 3 单位（含间隔）≈ 18 单位 + 18 间隔，据此算出左偏移
		var gridX:Float = (FlxG.width - (18 * unit + 18 * gridGap)) / 2;
		if (gridX < 0) gridX = 0;
		var gridY:Float = slotY + slotH + 40;
		var maxY:Int = 0;
		for (row in LAYOUT)
		{
			if (row.y > maxY) maxY = row.y;
			var x:Float = row.right ? gridX + rightX : gridX;
			if (row.right && row.center) x = gridX + rightX + (3 - row.keys[0].w) * 0.5 * unit; // 右侧区单键居中
			var y:Float = gridY + row.y * (keyH + gridGap);
			for (k in row.keys)
			{
				var w:Float = k.w * unit;
				var bgBt:FlxSprite = new FlxSprite(x, y).makeGraphic(Math.round(w), Std.int(keyH), 0xFF222222);
				bgBt.alpha = 0.7;
				add(bgBt);

				var label:FlxText = new FlxText(x, y, w, k.d);
				label.setFormat(Paths.font(Language.get('uitab_font')), 16, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				label.borderSize = 2;
				label.y += (keyH - label.height) / 2;
				add(label);

				keyBgs.push(bgBt);
				keyLabels.push(label);
				allKeyNames.push(k.n);
				allKeyDisps.push(k.d);
				x += w + gridGap;
			}
		}
		var gridBottom:Float = gridY + (maxY + 1) * (keyH + gridGap);

		// 退出按钮
		exitBt = new FlxSprite(FlxG.width - 210, gridBottom + 20).makeGraphic(190, 44, 0xFF0066FF);
		exitBt.alpha = 0.85;
		add(exitBt);
		var exitText:FlxText = new FlxText(exitBt.x, exitBt.y, exitBt.width, Language.get('key_bind_exit'));
		exitText.setFormat(Paths.font(Language.get('uitab_font')), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		exitText.borderSize = 2;
		exitText.y += (44 - exitText.height) / 2;
		add(exitText);

		// 重置按钮
		resetBt = new FlxSprite(20, gridBottom + 20).makeGraphic(150, 44, 0xFFA60000);
		resetBt.alpha = 0.85;
		add(resetBt);
		var resetText:FlxText = new FlxText(resetBt.x, resetBt.y, resetBt.width, Language.get('key_bind_reset'));
		resetText.setFormat(Paths.font(Language.get('uitab_font')), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		resetText.borderSize = 2;
		resetText.y += (44 - resetText.height) / 2;
		add(resetText);

		// 当前选中槽位高亮
		updateSlotHighlight();

		// 临时隐藏父菜单的虚拟键，避免与本界面叠加干扰；退出时由 destroy() 恢复
		if (parentMenu != null)
		{
			if (parentMenu.touchPad != null)
			{
				parentMenu.touchPad.visible = parentMenu.touchPad.active = false;
			}
			if (parentMenu.mobileControls != null && parentMenu.mobileControls.instance != null)
			{
				parentMenu.mobileControls.instance.visible = false;
			}
		}

		FlxG.mouse.visible = true;
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// 选中槽位
		for (i in 0...slotBgs.length)
		{
			if (i >= extraEnabled) break;
			if (justTapped(slotBgs[i]))
			{
				curSlot = i;
				updateSlotHighlight();
				FlxG.sound.play(Paths.sound('scrollMenu'));
				break;
			}
		}

		// 点击键位赋值给当前槽位
			for (i in 0...keyBgs.length)
			{
				if (justTapped(keyBgs[i]))
				{
					if (curSlot >= 0 && curSlot < extraEnabled)
						{
							Reflect.setProperty(ClientPrefs.data, 'extraKeyReturn' + (curSlot + 1), allKeyNames[i]);
							ClientPrefs.saveSettings();
							slotLabels[curSlot].text = Language.get('extra_bind_slot') + ' ' + (curSlot + 1) + '\n' + allKeyNames[i];
							FlxG.sound.play(Paths.sound('confirmMenu'));
							curSlot = -1; // 绑定完成即取消选中，回到偏黑，需重新点选才能再次修改
							updateSlotHighlight();
						}
					break;
				}
			}

			// —— 底部按钮：按下给反馈、松手才触发（避免误触、有按压手感）——
			exitPressed = handleButtonPress(exitBt, exitPressed, () ->
			{
				ClientPrefs.saveSettings();
				// 激活实例（controls.isInSubstate / MusicBeatSubstate.instance）的恢复由本类 destroy() 处理
				close();
			});
			exitBt.alpha = exitPressed ? 0.5 : 0.85;

			if (controls.BACK)
			{
				ClientPrefs.saveSettings();
				close();
			}

			resetPressed = handleButtonPress(resetBt, resetPressed, () ->
			{
				for (i in 0...4)
				{
					Reflect.setProperty(ClientPrefs.data, 'extraKeyReturn' + (i + 1), Reflect.field(ClientPrefs.defaultData, 'extraKeyReturn' + (i + 1)));
					slotLabels[i].text = Language.get('extra_bind_slot') + ' ' + (i + 1) + '\n' + Reflect.field(ClientPrefs.data, 'extraKeyReturn' + (i + 1));
				}
				ClientPrefs.saveSettings();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			});
			resetBt.alpha = resetPressed ? 0.5 : 0.85;
		}

	override function destroy()
	{
		super.destroy(); // MusicBeatSubstate.destroy 会把 controls.isInSubstate 置 false（顶层子状态关闭的语义）

		// 本子状态嵌套于 MobileOptionsSubState 之上，关闭后父菜单仍是活动层。
		// 若不清除残留，Controls 会把 requestedInstance 指向 OptionsState（其 touchPad 为空），
		// 导致父菜单的移动端触控导航失效，界面出现“卡死”。这里把父菜单恢复为当前活动实例。
		if (parentMenu != null)
		{
			// 恢复父菜单的虚拟键，让返回后有可见、可用的导航按键
			if (parentMenu.touchPad != null)
			{
				parentMenu.touchPad.visible = parentMenu.touchPad.active = true;
			}
			if (parentMenu.mobileControls != null && parentMenu.mobileControls.instance != null)
			{
				parentMenu.mobileControls.instance.visible = true;
			}
			controls.isInSubstate = true;
			MusicBeatSubstate.instance = parentMenu;
		}
	}

	var exitBt:FlxSprite;
	var resetBt:FlxSprite;

	function updateSlotHighlight():Void
	{
		for (i in 0...slotBgs.length)
		{
			var selected:Bool = (i == curSlot && i < extraEnabled);
			// 未选中偏黑底，白字+黑描边；选中改为浅底+彩色描边，
			// 避免“黑字+黑描边”把笔画糊成一坨黑看不清
			slotBgs[i].color = selected ? 0xFFFFFFFF : 0xFF222222;
			slotLabels[i].color = selected ? FlxColor.BLACK : FlxColor.WHITE;
			slotLabels[i].borderColor = selected ? 0xFF00D5FF : FlxColor.BLACK; // 彩色描边标识选中态
		}
	}

	function justTapped(object:FlxSprite):Bool
	{
		if (FlxG.mouse.overlaps(object))
			return FlxG.mouse.justPressed;
		if (TouchUtil.justPressed)
			return TouchUtil.overlaps(object);
		return false;
	}

	// 底部按钮：按下返回 true（配合外部置暗产生按压反馈），松手且仍停在按钮上才触发 onRelease。
	// 若手指拖离按钮（未松手），不触发并返回 false。
	function handleButtonPress(btn:FlxSprite, wasPressed:Bool, onRelease:Void->Void):Bool
	{
		if (pointerJustReleasedOver(btn) && wasPressed)
		{
			onRelease();
			return false;
		}
		return pointerPressedOver(btn);
	}

	// 是否有指针正按在按钮上（鼠标或任意触摸）
	function pointerPressedOver(btn:FlxSprite):Bool
	{
		if (FlxG.mouse.pressed && FlxG.mouse.overlaps(btn))
			return true;
		for (t in FlxG.touches.list)
			if (t.pressed && t.overlaps(btn))
				return true;
		return false;
	}

	// 是否有指针在本帧松手且落在按钮上
	function pointerJustReleasedOver(btn:FlxSprite):Bool
	{
		if (FlxG.mouse.justReleased && FlxG.mouse.overlaps(btn))
			return true;
		for (t in FlxG.touches.list)
			if (t.justReleased && t.overlaps(btn))
				return true;
		return false;
	}
}