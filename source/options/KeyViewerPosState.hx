package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.Paths;
import backend.ClientPrefs;
import objects.KeyViewer;
import android.FlxVirtualPad;
import android.FlxVirtualPad.FlxDPadMode;
import android.FlxVirtualPad.FlxActionMode;

/**
 * Key Viewer 位置校准界面。
 * 仿照 NoteOffsetState 的拖动交互：进入后展示真实的 KeyViewer 覆盖层，
 * 通过鼠标或触摸拖动其面板即可调整位置，偏移量实时存入 ClientPrefs（跨重启持久化）。
 * 游戏内 PlayState 创建 KeyViewer 时会读取该偏移并应用到整块面板。
 *
 * 存档安全说明：
 * ClientPrefs.saveSettings() 会把整个 funkin.sol 全量重写一遍（非原子写）。
 * 如果在写盘瞬间进程被杀（Android 划掉后台 / 崩溃），.sol 会被截断，
 * 下次启动反序列化失败 -> FlxG.save.data 为空 -> 所有设置回退默认值。
 * 因此这里**不再每次松手就存盘**，改为「脏标记 + 延迟合并写入」，
 * 并在退出 / destroy 时兜底提交，把整存次数从几十次压到 1~2 次。
 */
class KeyViewerPosState extends MusicBeatState
{
	// 偏移量允许的最大绝对值，防止面板被拖到永远找不回来的地方
	static inline var LIMIT_X:Float = 1280;
	static inline var LIMIT_Y:Float = 720;

	// 最后一次改动后延迟多久才真正写盘（秒）
	static inline var SAVE_DELAY:Float = 1.5;

	var viewer:KeyViewer;
	var _virtualpad:FlxVirtualPad;
	var dragging:Bool = false;
	var lastX:Float = 0;
	var lastY:Float = 0;
	var offsetText:FlxText;

	// 延迟存盘
	var pendingSave:Bool = false;
	var saveCooldown:Float = 0;
	var savedFlash:FlxText;

	override function create()
	{
		FlxG.mouse.visible = true;
		FlxG.camera.zoom = 1; // 让拖动用屏幕坐标，与游戏内偏移量单位一致

		// 进来先修一遍可能已经被写坏的值（NaN / Infinity / 超范围）
		ClientPrefs.data.keyViewerPosX = sanitize(ClientPrefs.data.keyViewerPosX, LIMIT_X);
		ClientPrefs.data.keyViewerPosY = sanitize(ClientPrefs.data.keyViewerPosY, LIMIT_Y);

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFF00BFFF;
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set(0, 0);
		add(bg);

		var title = new FlxText(0, 18, FlxG.width, Language.get('keyviewer_cal_title'), 28);
		title.setFormat(Paths.font("BlackSugarPlumCandy-Bold.ttf"), 28, FlxColor.WHITE, CENTER);
		title.scrollFactor.set(0, 0);
		add(title);

		var hintStr:String = #if mobile Language.get('keyviewer_cal_hint_mobile') #else Language.get('keyviewer_cal_hint_desktop') #end;
		var hint = new FlxText(0, 58, FlxG.width, hintStr, 16);
		hint.setFormat(Paths.font("BlackSugarPlumCandy-Bold.ttf"), 16, FlxColor.WHITE, CENTER);
		hint.scrollFactor.set(0, 0);
		add(hint);

		offsetText = new FlxText(0, 112, FlxG.width, '', 16);
		offsetText.setFormat(Paths.font("BlackSugarPlumCandy-Bold.ttf"), 16, FlxColor.YELLOW, CENTER);
		offsetText.scrollFactor.set(0, 0);
		add(offsetText);

		savedFlash = new FlxText(0, 138, FlxG.width, '', 15);
		savedFlash.setFormat(Paths.font("BlackSugarPlumCandy-Bold.ttf"), 15, FlxColor.LIME, CENTER);
		savedFlash.scrollFactor.set(0, 0);
		savedFlash.alpha = 0;
		add(savedFlash);

		rebuildViewer();
		updateOffsetText();

		// 移动端：B = 返回并保存，C = 重置
		// 改用 FlxVirtualPad（直接 add 进 state，始终渲染在最上层，无需独立相机，避免 touchPadCam 在完整 MusicBeatState 下失效）
		// FlxActionMode 枚举没有 B_C 组合，故以 NONE 构造后手动添加 B / C 两个按钮（沿用 virtualpad 图集的 b / c 帧）
		_virtualpad = new FlxVirtualPad(FlxDPadMode.NONE, FlxActionMode.NONE);
		_virtualpad.buttonB = _virtualpad.createButton(FlxG.width - 86 * 3, FlxG.height - 45 * 3, 44 * 3, 127, "b", 0xFFCB00);
		_virtualpad.buttonC = _virtualpad.createButton(FlxG.width - 128 * 3, FlxG.height - 45 * 3, 44 * 3, 127, "c", 0x44FF00);
		_virtualpad.actions.add(_virtualpad.buttonB);
		_virtualpad.actions.add(_virtualpad.buttonC);
		_virtualpad.add(_virtualpad.buttonB);
		_virtualpad.add(_virtualpad.buttonC);
		add(_virtualpad);

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
		offsetText.text = Language.get('keyviewer_cal_offset',
			[Std.string(Math.round(ClientPrefs.data.keyViewerPosX)), Std.string(Math.round(ClientPrefs.data.keyViewerPosY))])
			+ (pendingSave ? Language.get('keyviewer_cal_pending') : '');
	}

	// ---------------- 存盘控制 ----------------

	/** 标记有改动，重新开始倒计时；不立刻写盘 */
	inline function markDirty():Void
	{
		pendingSave = true;
		saveCooldown = SAVE_DELAY;
	}

	/** 真正写盘。整个界面生命周期内理想情况只会走 1~2 次 */
	function commitSave():Void
	{
		if (!pendingSave)
			return;

		// 写盘前再兜一次底，绝不把 NaN / Infinity 写进存档
		ClientPrefs.data.keyViewerPosX = sanitize(ClientPrefs.data.keyViewerPosX, LIMIT_X);
		ClientPrefs.data.keyViewerPosY = sanitize(ClientPrefs.data.keyViewerPosY, LIMIT_Y);

		pendingSave = false;
		saveCooldown = 0;
		ClientPrefs.saveSettings();

		if (savedFlash != null)
		{
			savedFlash.text = Language.get('keyviewer_cal_saved');
			savedFlash.alpha = 1;
		}
		updateOffsetText();
	}

	static inline function sanitize(v:Float, limit:Float):Float
	{
		if (Math.isNaN(v) || !Math.isFinite(v))
			return 0;
		if (v > limit)
			return limit;
		if (v < -limit)
			return -limit;
		return v;
	}

	// ---------------- 主循环 ----------------

	override function update(elapsed:Float)
	{
		// 返回并保存（桌面 BACK 键 / 移动端 B 虚拟键）
		// 拖动期间虚拟键已隐藏并禁用，这里也跳过其判定，避免松手瞬间误触发
		var backPressed:Bool = controls.BACK;
		if (!backPressed && !dragging && _virtualpad != null && _virtualpad.buttonB != null && _virtualpad.buttonB.justPressed)
			backPressed = true;

		if (backPressed)
		{
			commitSave();
			MusicBeatState.switchState(new OptionsState());
			return;
		}

		// 重置为默认位置（键盘 R / 移动端 C 键）
		var resetPressed:Bool = FlxG.keys.justPressed.R;
		if (!resetPressed && !dragging && _virtualpad != null && _virtualpad.buttonC != null && _virtualpad.buttonC.justPressed)
			resetPressed = true;

		if (resetPressed)
		{
			ClientPrefs.data.keyViewerPosX = 0;
			ClientPrefs.data.keyViewerPosY = 0;
			rebuildViewer();
			markDirty();
			updateOffsetText();
		}

		handleDrag();

		// 延迟合并写入：停手 SAVE_DELAY 秒后才真正落盘
		if (pendingSave && !dragging)
		{
			saveCooldown -= elapsed;
			if (saveCooldown <= 0)
				commitSave();
		}

		if (savedFlash != null && savedFlash.alpha > 0)
			savedFlash.alpha = Math.max(0, savedFlash.alpha - elapsed * 0.8);

		super.update(elapsed);
	}

	/** 判断某屏幕坐标是否落在虚拟按键上，避免点按钮时误触发拖动 */
	function overlapsVirtualPad(x:Float, y:Float):Bool
	{
		if (_virtualpad == null)
			return false;
		// 拖动期间按钮已隐藏且不吃输入，无需再挡；同时避免按钮隐藏后坐标误判
		if (dragging)
			return false;

		for (btn in [_virtualpad.buttonB, _virtualpad.buttonC])
		{
			if (btn == null || !btn.visible)
				continue;
			if (x >= btn.x && x <= btn.x + btn.width && y >= btn.y && y <= btn.y + btn.height)
				return true;
		}
		return false;
	}

	function handleDrag():Void
	{
		if (viewer == null || viewer.bgSprite == null)
			return;

		var bg = viewer.bgSprite;
		var mx:Float = lastX;
		var my:Float = lastY;
		var pressed:Bool = false;
		var justPressed:Bool = false;

		#if mobile
		// 触摸：只认真正处于按下 / 刚抬起状态的触摸点，忽略落在虚拟按键上的
		for (t in FlxG.touches.list)
		{
			if (t == null)
				continue;
			if (!t.pressed && !t.justPressed && !t.justReleased)
				continue;
			// 只在「还没开始拖」时过滤虚拟按键；已经在拖的时候手指滑过按钮不该断开
			if (!dragging && overlapsVirtualPad(t.x, t.y))
				continue;

			mx = t.x;
			my = t.y;
			pressed = t.pressed;
			justPressed = t.justPressed;
			break;
		}
		#else
		if (FlxG.mouse != null)
		{
			var p = FlxG.mouse.getScreenPosition(FlxG.camera);
			mx = p.x;
			my = p.y;
			pressed = FlxG.mouse.pressed;
			justPressed = FlxG.mouse.justPressed;
			p.put();
		}
		#end

		// 坐标本身脏了就直接放弃这一帧，别让 NaN 传染到存档
		if (Math.isNaN(mx) || Math.isNaN(my) || !Math.isFinite(mx) || !Math.isFinite(my))
		{
			dragging = false;
			return;
		}

		if (!dragging && justPressed)
		{
			if (mx >= bg.x && mx <= bg.x + bg.width && my >= bg.y && my <= bg.y + bg.height)
			{
				dragging = true;
				lastX = mx;
				lastY = my;
				// 拖动期间临时禁用虚拟键操控（隐藏且不吃输入），避免手指滑过 B/C 误触返回/重置
				if (_virtualpad != null)
					_virtualpad.visible = false;
			}
		}

		if (dragging)
		{
			var dx:Float = mx - lastX;
			var dy:Float = my - lastY;
			lastX = mx;
			lastY = my;

			// 夹取到合法范围，并按实际生效的位移量同步移动画面，避免 UI 与存档值脱节
			var newX:Float = sanitize(ClientPrefs.data.keyViewerPosX + dx, LIMIT_X);
			var newY:Float = sanitize(ClientPrefs.data.keyViewerPosY + dy, LIMIT_Y);
			var appliedX:Float = newX - ClientPrefs.data.keyViewerPosX;
			var appliedY:Float = newY - ClientPrefs.data.keyViewerPosY;

			ClientPrefs.data.keyViewerPosX = newX;
			ClientPrefs.data.keyViewerPosY = newY;

			if (appliedX != 0 || appliedY != 0)
			{
				viewer.moveBy(appliedX, appliedY);
				markDirty();
			}
			updateOffsetText();

			if (!pressed)
			{
				dragging = false;
				// 松手恢复虚拟键操控
				if (_virtualpad != null)
					_virtualpad.visible = true;
				// 松手不再立刻整存，交给延迟合并写入
				saveCooldown = SAVE_DELAY;
			}
		}
	}

	override function destroy()
	{
		// 兜底：任何路径离开这个 State 都保证改动落盘
		commitSave();
		super.destroy();
	}
}
