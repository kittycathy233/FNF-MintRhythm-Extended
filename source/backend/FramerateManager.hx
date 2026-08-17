package backend;

import openfl.Lib;

/**
 * 独立管理 draw framerate 和 update framerate 的工具类。
 * 两套帧率可分别设置，互不干扰。
 *
 * drawFramerate 直接写入 openfl stage.frameRate（绕过 FlxG.drawFramerate setter），
 * 避免底层驱动 snap 到支持的刷新率网格（如 30/60/75/90/120/144 等）。
 * updateFramerate 通过 FlxG.updateFramerate 设置（无 snap，仅 set _stepMS）。
 */
class FramerateManager
{
	/**
	 * 应用渲染帧率。直接写入 openfl stage.frameRate，允许任意整数值。
	 * 不经过 FlxG.drawFramerate setter，避免底层驱动 snap 行为。
	 */
	public static inline function applyDrawFramerate(value:Int):Void
	{
		// 直接写入 openfl stage，绕过 FlxG.drawFramerate setter 链
		// FlxG.drawFramerate setter 会调用 game.stage.frameRate = value，
		// 某些平台/驱动会对 value 做 snap（对齐到显示器支持的刷新率网格）
		if (Lib.current.stage != null)
			Lib.current.stage.frameRate = value;
		ClientPrefs.data.drawFramerate = value;
		ClientPrefs.saveSettings();
	}

	/**
	 * 应用逻辑更新帧率。update 必须 >= draw（Flixel 底层约束），否则自动补齐到 draw 值。
	 */
	public static inline function applyUpdateFramerate(value:Int):Void
	{
		// 使用本地保存的 drawFramerate 值做约束检查，而非读取 FlxG（可能已被 snap）
		final drawFr:Int = ClientPrefs.data.drawFramerate;
		if (value < drawFr)
			value = drawFr;
		FlxG.updateFramerate = value;
		ClientPrefs.data.updateFramerate = value;
		ClientPrefs.saveSettings();
	}

	/**
	 * 将两个帧率同时设置为同一值（兼容旧行为）。
	 */
	public static inline function applyBoth(value:Int):Void
	{
		applyDrawFramerate(value);
		applyUpdateFramerate(value);
	}

	/**
	 * 获取默认渲染刷新率（用于初始化选项的 defaultValue）。
	 */
	public static inline function getDefaultRefreshRate():Int
	{
		#if !html5
		return Std.int(FlxMath.bound(FlxG.stage.application.window.displayMode.refreshRate, 20, 1000));
		#end
		return 60;
	}
}
