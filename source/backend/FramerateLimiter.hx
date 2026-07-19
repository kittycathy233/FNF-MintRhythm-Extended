package backend;

import openfl.Lib;

/**
 * 帧率限制器：确保游戏实际渲染/更新速率不超过目标帧率。
 *
 * OpenFL 的 `stage.frameRate` 在部分平台（尤其是关闭 vsync 的桌面端）不够精确，
 * 实测帧率往往会略高于设定值（设定越高、绝对误差越明显）。
 * 这里用一个统一的节拍，把游戏主循环与 FPS 计数器对齐到目标帧率，
 * 使“设定值”和“计数器显示值”以及“实际渲染帧率”三者一致。
 */
class FramerateLimiter
{
	/** 当前目标帧率（由游戏主循环每帧写入，正常为设定值，失焦时为 focusLostFramerate） */
	public static var targetFps:Int = 60;

	/** 当前帧是否“允许”渲染/计数（由 tick() 决定，供 FPS 计数器读取） */
	public static var allowFrame:Bool = true;

	private static var _last:Int = -1;
	private static var _interval:Float = 1000 / 60;

	/**
	 * 由游戏主循环（KathyGame.onEnterFrame）在每帧调用，决定是否允许本帧执行。
	 * @return true 表示已达到目标间隔、允许执行；false 表示应跳过本帧。
	 */
	public static function tick():Bool
	{
		var now:Int = Lib.getTimer();
		_interval = 1000 / Math.max(1, targetFps);

		if (_last < 0)
		{
			_last = now;
			allowFrame = true;
			return true;
		}

		// 尚未到达目标间隔 -> 跳过本帧（不渲染、不更新、不计帧）
		if (now - _last < _interval - 0.5)
		{
			allowFrame = false;
			return false;
		}

		// 按精确间隔对齐，避免长期漂移累积
		_last += Std.int(_interval);
		// 落后太多（如切后台再回来）则重置，避免“死亡螺旋”一次性补大量帧
		if (now - _last > _interval * 4)
			_last = now;

		allowFrame = true;
		return true;
	}

	/** 切后台/状态重置时调用，避免恢复瞬间一次性补帧 */
	public static function reset():Void
	{
		_last = -1;
	}
}
