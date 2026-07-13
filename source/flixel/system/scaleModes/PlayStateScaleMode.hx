package flixel.system.scaleModes;

import flixel.FlxG;

/**
 * PlayState 专用的宽屏自适应缩放模式。
 * 与制谱器 ChartingScaleMode 类似，但策略不同：
 *   - 高度严格锁定在 720（不随窗口缩放）
 *   - 宽度根据窗口宽高比自适应，限制在 [960, 1600] 之间
 *   - 保持画面不拉伸变形（等比例缩放 + 黑边）
 * 该模式根据设置开关在进入 PlayState 时临时启用，退出后还原。
 */
class PlayStateScaleMode extends BaseScaleMode
{
	/** 最小宽度（默认 960） */
	public var minWidth:Int = 960;
	/** 锁定高度（默认 720） */
	public var lockedHeight:Int = 720;
	/** 最大宽度（默认 1600） */
	public var maxWidth:Int = 1600;

	public function new(minWidth:Int = 960, lockedHeight:Int = 720, maxWidth:Int = 1600)
	{
		super();
		this.minWidth = minWidth;
		this.lockedHeight = lockedHeight;
		this.maxWidth = maxWidth;
	}

	override public function onMeasure(Width:Int, Height:Int):Void
	{
		// 高度严格锁定 720
		if (Width <= 0) Width = minWidth;
		if (Height <= 0) Height = lockedHeight;

		// 按窗口宽高比计算宽度：tw = lockedHeight * (windowW / windowH)
		// 限制在 [minWidth, maxWidth] 区间内
		var aspect:Float = Width / Height;
		var tw:Float = lockedHeight * aspect;
		tw = Math.min(maxWidth, Math.max(minWidth, tw));

		FlxG.width = Math.round(tw);
		FlxG.height = lockedHeight;

		updateGameSize(Width, Height);
		updateDeviceSize(Width, Height);
		updateScaleOffset();
		updateGamePosition();
	}

	/**
	 * 重写游戏画面缩放：保持内部渲染分辨率的长宽比不变，
	 * 整体缩放到窗口中（多余空间留黑边），防止画面变形。
	 */
	override function updateGameSize(Width:Int, Height:Int):Void
	{
		var gameRatio:Float = FlxG.width / FlxG.height;
		var windowRatio:Float = Width / Height;

		// 窗口比游戏更"窄高" → 以宽度为准，上下留黑边
		if (windowRatio < gameRatio)
		{
			gameSize.x = Width;
			gameSize.y = Math.floor(Width / gameRatio);
		}
		// 窗口比游戏更"宽矮" → 以高度为准，左右留黑边
		else
		{
			gameSize.y = Height;
			gameSize.x = Math.floor(Height * gameRatio);
		}
	}
}
