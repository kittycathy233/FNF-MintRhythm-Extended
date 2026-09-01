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

	// 可选的物理键位名（大写），与脚本检测用小写名对应
	static final KEYS:Array<String> = [
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
		'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
		'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
		'ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE',
		'SPACE', 'BACKSPACE', 'ENTER', 'SHIFT', 'TAB', 'ESCAPE'
	];
	static final DISPLAY:Array<String> = [
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
		'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
		'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
		'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
		'SPACE', 'BACKSPACE', 'ENTER', 'SHIFT', 'TAB', 'ESCAPE'
	];

	var ui:FlxCamera;

	var slotBgs:Array<FlxSprite> = [];
	var slotLabels:Array<FlxText> = [];
	var keyBgs:Array<FlxSprite> = [];
	var keyLabels:Array<FlxText> = [];


	var curSlot:Int = 0;
	var extraEnabled:Int = 0; // 当前启用的额外键数量

	override function create()
	{
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		// Std.parseInt 返回 Null<Int>，先转成普通 Int 再夹取到 0~4
		var raw:Null<Int> = Std.parseInt(ClientPrefs.data.extraButtons);
		extraEnabled = (raw == null) ? 0 : raw;
		if (extraEnabled < 0) extraEnabled = 0;
		if (extraEnabled > 4) extraEnabled = 4;

		// 半透明暗化背景
		var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set();
		bg.alpha = 0.55;
		add(bg);

		// 标题
		var title:FlxText = new FlxText(0, 24, FlxG.width, Language.get('extra_key_bindings'));
		title.setFormat(Paths.font("vcr.ttf"), 38, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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
			var bgBt:FlxSprite = new FlxSprite(x, slotY).makeGraphic(Std.int(slotW), Std.int(slotH), FlxColor.BLACK);
			bgBt.alpha = i < extraEnabled ? 0.75 : 0.25;
			add(bgBt);

			var keyName:String = Reflect.field(ClientPrefs.data, 'extraKeyReturn' + (i + 1));
			var label:FlxText = new FlxText(x, slotY, slotW);
			label.text = Language.get('extra_bind_slot') + ' ' + (i + 1) + '\n' + keyName;
			label.setFormat(Paths.font("vcr.ttf"), i < extraEnabled ? 20 : 16, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 2;
			label.y += (slotH - label.height) / 2;
			add(label);

			slotBgs.push(bgBt);
			slotLabels.push(label);
		}

		// 提示语
		var hint:FlxText = new FlxText(0, slotY + slotH + 10, FlxG.width, Language.get('extra_bind_hint'));
		hint.setFormat(Paths.font("vcr.ttf"), 16, 0xFFCCCCCC, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hint.borderSize = 1;
		add(hint);

		// 键位网格
		var keyW:Float = 62;
		var keyH:Float = 40;
		var gridGap:Float = 8;
		var cols:Int = Std.int(Math.max(1, Std.int((FlxG.width - 24) / (keyW + gridGap))));
		var gridY:Float = slotY + slotH + 40;
		for (i in 0...KEYS.length)
		{
			var row:Int = Std.int(i / cols);
			var col:Int = i % cols;
			var x:Float = 12 + col * (keyW + gridGap);
			var y:Float = gridY + row * (keyH + gridGap);
			var bgBt:FlxSprite = new FlxSprite(x, y).makeGraphic(Std.int(keyW), Std.int(keyH), 0xFF222222);
			bgBt.alpha = 0.7;
			add(bgBt);

			var label:FlxText = new FlxText(x, y, keyW, DISPLAY[i]);
			label.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 2;
			label.y += (keyH - label.height) / 2;
			add(label);

			keyBgs.push(bgBt);
			keyLabels.push(label);
		}
		var gridBottom:Float = gridY + Math.ceil(KEYS.length / cols) * (keyH + gridGap);

		// 退出按钮
		exitBt = new FlxSprite(FlxG.width - 210, gridBottom + 20).makeGraphic(190, 44, 0xFF0066FF);
		exitBt.alpha = 0.85;
		add(exitBt);
		var exitText:FlxText = new FlxText(exitBt.x, exitBt.y, exitBt.width, Language.get('key_bind_exit'));
		exitText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		exitText.borderSize = 2;
		exitText.y += (44 - exitText.height) / 2;
		add(exitText);

		// 重置按钮
		resetBt = new FlxSprite(20, gridBottom + 20).makeGraphic(150, 44, 0xFFA60000);
		resetBt.alpha = 0.85;
		add(resetBt);
		var resetText:FlxText = new FlxText(resetBt.x, resetBt.y, resetBt.width, Language.get('key_bind_reset'));
		resetText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		resetText.borderSize = 2;
		resetText.y += (44 - resetText.height) / 2;
		add(resetText);

		// 当前选中槽位高亮
		updateSlotHighlight();

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
				if (curSlot < extraEnabled)
				{
					Reflect.setProperty(ClientPrefs.data, 'extraKeyReturn' + (curSlot + 1), KEYS[i]);
					ClientPrefs.saveSettings();
					slotLabels[curSlot].text = Language.get('extra_bind_slot') + ' ' + (curSlot + 1) + '\n' + KEYS[i];
					FlxG.sound.play(Paths.sound('confirmMenu'));
				}
				break;
			}
		}

		if (justTapped(exitBt) || controls.BACK)
		{
			ClientPrefs.saveSettings();
			// 激活实例（controls.isInSubstate / MusicBeatSubstate.instance）的恢复由本类 destroy() 处理
			close();
		}

		if (justTapped(resetBt))
		{
			for (i in 0...4)
			{
				Reflect.setProperty(ClientPrefs.data, 'extraKeyReturn' + (i + 1), Reflect.field(ClientPrefs.defaultData, 'extraKeyReturn' + (i + 1)));
				slotLabels[i].text = Language.get('extra_bind_slot') + ' ' + (i + 1) + '\n' + Reflect.field(ClientPrefs.data, 'extraKeyReturn' + (i + 1));
			}
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	override function destroy()
	{
		super.destroy(); // MusicBeatSubstate.destroy 会把 controls.isInSubstate 置 false（顶层子状态关闭的语义）

		// 本子状态嵌套于 MobileOptionsSubState 之上，关闭后父菜单仍是活动层。
		// 若不清除残留，Controls 会把 requestedInstance 指向 OptionsState（其 touchPad 为空），
		// 导致父菜单的移动端触控导航失效，界面出现“卡死”。这里把父菜单恢复为当前活动实例。
		if (parentMenu != null)
		{
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
			if (i == curSlot && i < extraEnabled)
				slotBgs[i].color = 0xFF00FF66;
			else
				slotBgs[i].color = FlxColor.BLACK;
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
}