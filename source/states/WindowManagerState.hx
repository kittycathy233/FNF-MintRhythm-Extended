package states;

import backend.MusicBeatState;
import backend.NativeWindowManager;
import backend.Controls;
import backend.Paths;
import backend.ClientPrefs;
import backend.Language;
import options.OptionsState;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;

/**
 * WindowManagerState - Window Manager (Standalone State)
 * Provides window management UI to create, close and manage multiple extra windows
 * Runs as a standalone state, press ESC to return to settings
 */
class WindowManagerState extends MusicBeatState
{
	// UI元素
	private var bg:FlxSprite;
	private var windowListText:FlxText;
	private var addWindowBtn:FlxButton;
	private var addTransparentBtn:FlxButton;
	private var closeAllBtn:FlxButton;
	private var refreshBtn:FlxButton;
	private var backBtn:FlxButton;
	private var titleText:FlxText;
	private var windowButtons:Map<Int, FlxButton> = new Map();
	private var menuBG:FlxSprite;

	// 透明窗口ID集合
	private var transparentWindows:Map<Int, Bool> = new Map();

	// 配置
	private static inline var DEFAULT_WINDOW_WIDTH:Int = 800;
	private static inline var DEFAULT_WINDOW_HEIGHT:Int = 600;

	public function new()
	{
		super();
	}

	override function create()
	{
		super.create();

		// Discord状态
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Window Manager", null);
		#end

		// 创建菜单背景
		menuBG = OptionsState.menuBG;
		add(menuBG);

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

		// 添加触摸板（如果需要）
		addTouchPad('NONE', 'A');
	}

	private function createUI()
	{
		var lang:String = ClientPrefs.data.language;
		var gameFont:String = Paths.font(Language.get('game_font'));

		// 标题
		titleText = new FlxText(0, 30, FlxG.width, "Window Manager", 40);
		titleText.setFormat(gameFont, 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set();
		add(titleText);

		// 窗口列表文本区域
		windowListText = new FlxText(100, 120, FlxG.width - 200, "", 22);
		windowListText.setFormat(gameFont, 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		windowListText.scrollFactor.set();
		add(windowListText);

		// 添加窗口按钮
		addWindowBtn = new FlxButton(100, FlxG.height - 240, "+ Add Window", onAddWindow);
		addWindowBtn.label.setFormat(gameFont, 20, FlxColor.WHITE, CENTER);
		addWindowBtn.scale.set(1.2, 1.2);
		addWindowBtn.updateHitbox();
		addWindowBtn.scrollFactor.set();
		add(addWindowBtn);

		// 添加透明窗口按钮
		addTransparentBtn = new FlxButton(300, FlxG.height - 240, "+ Add Transparent Window", onAddTransparentWindow);
		addTransparentBtn.label.setFormat(gameFont, 20, FlxColor.WHITE, CENTER);
		addTransparentBtn.scale.set(1.2, 1.2);
		addTransparentBtn.updateHitbox();
		addTransparentBtn.scrollFactor.set();
		add(addTransparentBtn);

		// 关闭所有窗口按钮
		closeAllBtn = new FlxButton(500, FlxG.height - 240, "Close All Windows", onCloseAllWindows);
		closeAllBtn.label.setFormat(gameFont, 20, FlxColor.WHITE, CENTER);
		closeAllBtn.scale.set(1.2, 1.2);
		closeAllBtn.updateHitbox();
		closeAllBtn.scrollFactor.set();
		add(closeAllBtn);

		// 刷新按钮
		refreshBtn = new FlxButton(FlxG.width - 250, FlxG.height - 180, "Refresh List", () -> {
			updateWindowList();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		});
		refreshBtn.label.setFormat(gameFont, 20, FlxColor.WHITE, CENTER);
		refreshBtn.scale.set(1.2, 1.2);
		refreshBtn.updateHitbox();
		refreshBtn.scrollFactor.set();
		add(refreshBtn);

		// 返回按钮
		backBtn = new FlxButton(FlxG.width - 200, 30, "Back [ESC]", onBack);
		backBtn.label.setFormat(gameFont, 20, FlxColor.WHITE, CENTER);
		backBtn.scrollFactor.set();
		add(backBtn);

		// 按钮提示文本
		var hintText = new FlxText(0, FlxG.height - 50, FlxG.width, "Tip: Transparent windows are fullscreen with no titlebar, press ESC to return", 16);
		hintText.setFormat(gameFont, 16, FlxColor.YELLOW, CENTER);
		hintText.scrollFactor.set();
		add(hintText);
	}

	private function updateWindowList()
	{
		var windowIds = NativeWindowManager.getAllWindowIds();
		var text = "Window List:\n";
		var yPos:Int = 120;
		var gameFont:String = Paths.font(Language.get('game_font'));

		// 清除之前的窗口按钮
		for (btn in windowButtons)
		{
			remove(btn);
			btn.destroy();
		}
		windowButtons.clear();

		if (windowIds.length == 0)
		{
			text += "  (No windows, click button below to create)";
		}
		else
		{
			for (i in 0...windowIds.length)
			{
				var id = windowIds[i];
				var pos = NativeWindowManager.getWindowPosition(id);
				var isTransparent = transparentWindows.exists(id);
				var windowType = isTransparent ? "[Transparent] " : "";
				text += '  ${i + 1}. ${windowType}Window #${id} (${pos.width}x${pos.height})\n';

				// 为每个窗口创建关闭按钮
				var closeWindowBtn = new FlxButton(FlxG.width - 220, yPos + i * 40, "Close", function() {
					onCloseWindow(id);
				});
				closeWindowBtn.label.setFormat(gameFont, 18, FlxColor.WHITE, CENTER);
				closeWindowBtn.scrollFactor.set();
				add(closeWindowBtn);
				windowButtons.set(id, closeWindowBtn);

				yPos += 40;
			}

			text += "\n  Total: ${windowIds.length} active windows";
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

	private function onAddTransparentWindow()
	{
		#if (cpp && windows)
		var windowId = NativeWindowManager.createTransparentWindow();
		if (windowId > 0)
		{
			transparentWindows.set(windowId, true);
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
			transparentWindows.remove(windowId);
			FlxG.sound.play(Paths.sound('cancelMenu'));
			updateWindowList();
		}
	}

	private function onCloseAllWindows()
	{
		var count = NativeWindowManager.closeAllWindows();
		if (count > 0)
		{
			transparentWindows.clear();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			// 立即刷新列表
			updateWindowList();
		}
	}

	private function onBack()
	{
		// 渐出背景
		FlxTween.tween(bg, {alpha: 0}, 0.2, {
			ease: FlxEase.circIn,
			onComplete: function(twn:FlxTween) {
				MusicBeatState.switchState(new options.OptionsState());
			}
		});
	}

	override function update(elapsed:Float)
	{
		// ESC键返回设置
		if (controls.BACK)
		{
			onBack();
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

		// 清理透明窗口记录
		transparentWindows.clear();

		super.destroy();
	}
}
