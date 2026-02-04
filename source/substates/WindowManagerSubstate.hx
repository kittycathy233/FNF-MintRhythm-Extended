package substates;

import backend.MusicBeatSubstate;
import backend.NativeWindowManager;
import backend.Controls;
import backend.Paths;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;

/**
 * WindowManagerSubstate - 多窗口管理器
 * 提供窗口管理UI，允许创建、关闭和管理多个额外窗口
 */
class WindowManagerSubstate extends MusicBeatSubstate
{
	// UI元素
	private var bg:FlxSprite;
	private var windowListText:FlxText;
	private var addWindowBtn:FlxButton;
	private var closeAllBtn:FlxButton;
	private var refreshBtn:FlxButton;
	private var closeBtn:FlxButton;
	private var titleText:FlxText;
	private var windowButtons:Map<Int, FlxButton> = new Map();

	// 配置
	private static inline var DEFAULT_WINDOW_WIDTH:Int = 800;
	private static inline var DEFAULT_WINDOW_HEIGHT:Int = 600;

	public function new()
	{
		super();
		persistentUpdate = false; // 暂停主界面更新
	}

	override function create()
	{
		super.create();

		// 创建半透明背景
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.7;
		add(bg);

		// 渐入背景
		bg.alpha = 0;
		FlxTween.tween(bg, {alpha: 0.7}, 0.3, {ease: FlxEase.circOut});

		// 创建UI
		createUI();
		updateWindowList();

		// 确保鼠标可见
		FlxG.mouse.visible = true;
	}

	private function createUI()
	{
		// 标题
		var lang:String = ClientPrefs.data.language;
		titleText = new FlxText(0, 30, FlxG.width, "多窗口管理器", 40);
		titleText.setFormat(Paths.font(Language.get('game_font')), 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set();
		add(titleText);

		// 窗口列表文本区域
		windowListText = new FlxText(100, 120, FlxG.width - 200, "", 22);
		windowListText.setFormat(Paths.font(Language.get('game_font')), 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		windowListText.scrollFactor.set();
		add(windowListText);

		// 添加窗口按钮
		addWindowBtn = new FlxButton(100, FlxG.height - 180, "+ 添加窗口", onAddWindow);
		addWindowBtn.scale.set(1.2, 1.2);
		addWindowBtn.updateHitbox();
		addWindowBtn.scrollFactor.set();
		add(addWindowBtn);

		// 关闭所有窗口按钮
		closeAllBtn = new FlxButton(300, FlxG.height - 180, "关闭所有窗口", onCloseAllWindows);
		closeAllBtn.scale.set(1.2, 1.2);
		closeAllBtn.updateHitbox();
		closeAllBtn.scrollFactor.set();
		add(closeAllBtn);

		// 刷新按钮
		refreshBtn = new FlxButton(FlxG.width - 250, FlxG.height - 180, "刷新列表", () -> {
			updateWindowList();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		});
		refreshBtn.scale.set(1.2, 1.2);
		refreshBtn.updateHitbox();
		refreshBtn.scrollFactor.set();
		add(refreshBtn);

		// 关闭substate按钮
		closeBtn = new FlxButton(FlxG.width - 200, 30, "关闭 [ESC]", onClose);
		closeBtn.scrollFactor.set();
		add(closeBtn);

		// 按钮提示文本
		var hintText = new FlxText(0, FlxG.height - 50, FlxG.width, "提示: 点击按钮创建窗口，ESC键退出", 16);
		hintText.setFormat(Paths.font(Language.get('game_font')), 16, FlxColor.YELLOW, CENTER);
		hintText.scrollFactor.set();
		add(hintText);
	}

	private function updateWindowList()
	{
		var windowIds = NativeWindowManager.getAllWindowIds();
		var text = "窗口列表:\n";
		var yPos:Int = 120;

		// 清除之前的窗口按钮
		for (btn in windowButtons)
		{
			remove(btn);
			btn.destroy();
		}
		windowButtons.clear();

		if (windowIds.length == 0)
		{
			text += "  (暂无窗口，点击下方按钮创建)";
		}
		else
		{
			for (i in 0...windowIds.length)
			{
				var id = windowIds[i];
				var pos = NativeWindowManager.getWindowPosition(id);
				text += '  ${i + 1}. 窗口 #${id} (${pos.width}x${pos.height})\n';

				// 为每个窗口创建关闭按钮
				var closeWindowBtn = new FlxButton(FlxG.width - 220, yPos + i * 40, "关闭", function() {
					onCloseWindow(id);
				});
				closeWindowBtn.scrollFactor.set();
				add(closeWindowBtn);
				windowButtons.set(id, closeWindowBtn);

				yPos += 40;
			}

			text += "\n  共 ${windowIds.length} 个活动窗口";
		}

		windowListText.text = text;

		// 调整窗口列表高度
		windowListText.height = yPos - 120 + 50;
	}

	private function onAddWindow()
	{
		#if (cpp && windows)
		var windowId = NativeWindowManager.createWindow(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT);
		if (windowId > 0)
		{
			FlxG.sound.play(Paths.sound('confirmMenu'));
			updateWindowList();
		}
		else
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		#else
		FlxG.sound.play(Paths.sound('cancelMenu'));
		#end
	}

	private function onCloseWindow(windowId:Int)
	{
		if (NativeWindowManager.closeWindow(windowId))
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			updateWindowList();
		}
	}

	private function onCloseAllWindows()
	{
		var count = NativeWindowManager.closeAllWindows();
		if (count > 0)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			updateWindowList();
		}
	}

	private function onClose()
	{
		// 渐出背景
		FlxTween.tween(bg, {alpha: 0}, 0.2, {
			ease: FlxEase.circIn,
			onComplete: function(twn:FlxTween) {
				close();
			}
		});
	}

	override function update(elapsed:Float)
	{
		// ESC键退出
		if (controls.BACK)
		{
			onClose();
		}

		// 点击背景关闭
		if (FlxG.mouse.justPressed && !FlxG.mouse.overlaps(windowListText) && !FlxG.mouse.overlaps(addWindowBtn) && !FlxG.mouse.overlaps(closeAllBtn) && !FlxG.mouse.overlaps(refreshBtn) && !FlxG.mouse.overlaps(closeBtn))
		{
			var buttonOverlaps = false;
			for (btn in windowButtons)
			{
				if (FlxG.mouse.overlaps(btn))
				{
					buttonOverlaps = true;
					break;
				}
			}
			if (!buttonOverlaps)
			{
				onClose();
			}
		}

		super.update(elapsed);
	}

	override function destroy()
	{
		// 清理所有窗口按钮
		for (btn in windowButtons)
		{
			if (btn != null)
			{
				remove(btn);
				btn.destroy();
			}
		}
		windowButtons.clear();

		super.destroy();
	}
}
