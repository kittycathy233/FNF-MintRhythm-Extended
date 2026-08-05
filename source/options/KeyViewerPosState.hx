package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.Paths;
import backend.ClientPrefs;
import objects.KeyViewer;

/**
 * Key Viewer 位置校准界面。
 * 仿照 NoteOffsetState 的拖动交互：进入后展示真实的 KeyViewer 覆盖层，
 * 通过鼠标或触摸拖动其面板即可调整位置，偏移量实时存入 ClientPrefs（跨重启持久化）。
 * 游戏内 PlayState 创建 KeyViewer 时会读取该偏移并应用到整块面板。
 */
class KeyViewerPosState extends MusicBeatState
{
	var viewer:KeyViewer;
	var dragging:Bool = false;
	var lastX:Float = 0;
	var lastY:Float = 0;
	var offsetText:FlxText;

	override function create()
	{
		FlxG.mouse.visible = true;
		FlxG.camera.zoom = 1; // 让拖动用屏幕坐标，与游戏内偏移量单位一致

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFF00BFFF;
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set(0, 0);
		add(bg);

		var title = new FlxText(0, 18, FlxG.width, 'Key Viewer 位置校准', 28);
		title.setFormat(Paths.font("BlackSugarPlumCandy-Bold.ttf"), 28, FlxColor.WHITE, CENTER);
		title.scrollFactor.set(0, 0);
		add(title);

		var hint = new FlxText(0, 58, FlxG.width,
			'拖动下方面板调整 Key Viewer 位置（鼠标或触摸）\n按 R 重置为默认位置 · 按 ESC / BACK 返回并保存', 16);
		hint.setFormat(Paths.font("BlackSugarPlumCandy-Bold.ttf"), 16, FlxColor.WHITE, CENTER);
		hint.scrollFactor.set(0, 0);
		add(hint);

		offsetText = new FlxText(0, 112, FlxG.width, '', 16);
		offsetText.setFormat(Paths.font("BlackSugarPlumCandy-Bold.ttf"), 16, FlxColor.YELLOW, CENTER);
		offsetText.scrollFactor.set(0, 0);
		add(offsetText);

		rebuildViewer();
		updateOffsetText();

		super.create();
	}

	function rebuildViewer():Void
	{
		if (viewer != null)
		{
			remove(viewer);
			viewer.destroy();
		}
		viewer = new KeyViewer();
		// 不设置 viewerCam：让 KeyViewer 使用 defaultCameras，从而不受 MusicBeatState 进入时
		// initPsychCamera() 重置相机的影响（显式赋 FlxG.camera 会捕获到被销毁的旧相机快照）
		add(viewer);
	}

	function updateOffsetText():Void
	{
		offsetText.text = '当前偏移  X: ${Math.round(ClientPrefs.data.keyViewerPosX)}'
			+ '  Y: ${Math.round(ClientPrefs.data.keyViewerPosY)}';
	}

	override function update(elapsed:Float)
	{
		// 返回并保存
		if (controls.BACK)
		{
			ClientPrefs.saveSettings();
			MusicBeatState.switchState(new OptionsState());
			return;
		}
		// 重置为默认位置
		if (FlxG.keys.justPressed.R)
		{
			ClientPrefs.data.keyViewerPosX = 0;
			ClientPrefs.data.keyViewerPosY = 0;
			rebuildViewer();
			updateOffsetText();
			ClientPrefs.saveSettings();
		}

		handleDrag();
		super.update(elapsed);
	}

	function handleDrag():Void
	{
		if (viewer == null || viewer.bgSprite == null)
			return;

		var bg = viewer.bgSprite;
		var mx:Float = 0;
		var my:Float = 0;
		var pressed:Bool = false;
		var justPressed:Bool = false;

		// 鼠标
		if (FlxG.mouse != null)
		{
			var p = FlxG.mouse.getScreenPosition(FlxG.camera);
			mx = p.x;
			my = p.y;
			pressed = FlxG.mouse.pressed;
			justPressed = FlxG.mouse.justPressed;
		}

		// 触摸：取第一个活动触摸点
		#if mobile
		for (t in FlxG.touches.list)
		{
			if (t != null)
			{
				mx = t.x;
				my = t.y;
				pressed = t.pressed;
				justPressed = t.justPressed;
				break;
			}
		}
		#end

		if (!dragging && justPressed)
		{
			if (mx >= bg.x && mx <= bg.x + bg.width && my >= bg.y && my <= bg.y + bg.height)
			{
				dragging = true;
				lastX = mx;
				lastY = my;
			}
		}

		if (dragging)
		{
			var dx:Float = mx - lastX;
			var dy:Float = my - lastY;
			lastX = mx;
			lastY = my;
			viewer.moveBy(dx, dy);
			ClientPrefs.data.keyViewerPosX += dx;
			ClientPrefs.data.keyViewerPosY += dy;
			updateOffsetText();
			if (!pressed)
			{
				dragging = false;
				ClientPrefs.saveSettings();
			}
		}
	}
}

