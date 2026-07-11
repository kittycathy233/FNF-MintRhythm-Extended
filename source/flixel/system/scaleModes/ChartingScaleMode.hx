package flixel.system.scaleModes;

import flixel.FlxG;

/**
 * 制谱器专用高分辨率缩放模式。
 * 将内部渲染缓冲（backbuffer）设定在一个分辨率区间内：
 *   - 桌面端：最低 720P（1280x720），最高 1080P（1920x1080）；
 *   - 移动端：允许宽度适当加宽（移动端通常高 DPI / 横屏更宽），高度仍封顶 1080P。
 * 再把整个画面缩放到窗口，从而在制谱器内获得更清晰、更高清的画面。
 * 该模式只在使用制谱器时临时启用，退出制谱器后会还原为原来的缩放模式。
 */
class ChartingScaleMode extends BaseScaleMode
{
	/** 目标最小宽度（默认 1280 = 720P） */
	public var targetWidth:Int = 1280;
	/** 目标最小高度（默认 720 = 720P） */
	public var targetHeight:Int = 720;
	/** 允许的最大宽度（桌面端上限 1920 = 1080P） */
	public var maxWidth:Int = 1920;
	/** 允许的最大高度（1080P） */
	public var maxHeight:Int = 1080;
	/** 移动端允许的最大宽度（比桌面端更宽，以利用更多屏幕，但高度仍封顶 1080P） */
	public var mobileMaxWidth:Int = 2160;

	public function new(targetWidth:Int = 1280, targetHeight:Int = 720, maxWidth:Int = 1920, maxHeight:Int = 1080, mobileMaxWidth:Int = 2160)
	{
		super();
		this.targetWidth = targetWidth;
		this.targetHeight = targetHeight;
		this.maxWidth = maxWidth;
		this.maxHeight = maxHeight;
		this.mobileMaxWidth = mobileMaxWidth;
	}

	override public function onMeasure(Width:Int, Height:Int):Void
	{
		// 桌面端：内部缓冲最低 720P、最高 1080P；移动端允许宽度适当加宽
		var curMaxW:Int = FlxG.onMobile ? mobileMaxWidth : maxWidth;

		if (Width <= 0) Width = targetWidth;
		if (Height <= 0) Height = targetHeight;

		// 关键：内部缓冲必须与窗口保持相同宽高比，否则整幅铺满窗口时会被拉伸变形。
		// 先按窗口比例确定高度（限制在 720~1080），再按比例推算宽度，最后再对宽度做上/下限修正。
		var aspect:Float = Width / Height;

		// 高度先夹在 [targetHeight, maxHeight] 之间，并尽量贴合窗口原生高度
		var th:Float = Math.min(maxHeight, Math.max(targetHeight, Height));
		// 宽度按同比例推算，保持不拉伸
		var tw:Float = th * aspect;

		// 若宽度超出允许范围，则以宽度为准反推高度，继续保持比例
		if (tw > curMaxW)
		{
			tw = curMaxW;
			th = tw / aspect;
		}
		else if (tw < targetWidth)
		{
			tw = targetWidth;
			th = tw / aspect;
		}

		// 设定内部缓冲分辨率（保持窗口比例，更高清且不拉伸）
		FlxG.width = Math.round(tw);
		FlxG.height = Math.round(th);

		// 窗口 / 设备尺寸与缩放偏移
		updateGameSize(Width, Height);
		updateDeviceSize(Width, Height);
		updateScaleOffset();
		updateGamePosition();
	}
}
