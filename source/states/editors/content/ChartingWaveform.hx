package states.editors.content;

import flixel.addons.display.waveform.FlxWaveform;
import flixel.addons.display.waveform.FlxWaveform.WaveformDrawMode;
import flixel.addons.display.waveform.data.WaveformSegment;
import flixel.util.FlxColor;

/**
 * 制谱器专用 FlxWaveform 子类。
 *
 * 原库的 prepareDrawData() 在 waveformDuration（当前 section 时间窗长度）变化时，
 * 会用 buildDrawData(full=true) 把整首歌的波形数据全量重建（扫描全部采样点），
 * 导致制谱器每次切 section 都卡一下。
 *
 * 这里覆盖为只重建当前可见窗口（full=false），把单次计算量从"整首歌"降到"当前 section"。
 * 制谱器从不滚动浏览波形（time/duration 总是一起改），所以不影响显示正确性。
 */
class ChartingWaveform extends FlxWaveform
{
	public function new(?x:Float = 0, ?y:Float = 0, width:Int, height:Int, ?color:FlxColor = 0xFFFFFFFF, ?backgroundColor:FlxColor = 0x00000000, ?drawMode:WaveformDrawMode = COMBINED)
	{
		super(x, y, width, height, color, backgroundColor, drawMode);
	}

	override function prepareDrawData(channel:Int):Void
	{
		var drawPoints:Array<WaveformSegment> = null;

		if (channel == 0)
			drawPoints = _drawPointsLeft;
		else if (channel == 1)
			drawPoints = _drawPointsRight;

		// full=false 时 buildDrawData 只会填充 [0.._effectiveSize) 范围的数据，
		// 无需为全曲预留空间。按全曲长度分配（ceil(songLen/duration)*effectiveSize）
		// 会在长曲末段触发巨大的无用数组，导致内存暴涨后崩溃。
		var arrayLength:Int = _effectiveSize;
		drawPoints.resize(arrayLength);
		resetDrawArray(drawPoints);

		if (channel < waveformBuffer.numChannels)
			buildDrawData(channel, drawPoints, false, true);
	}

	/**
	 * 原库的 set_waveformTime 只标记 _waveformDirty、不标记 _drawDataDirty。
	 * 绘制数据数组按"绝对采样位置"索引，当相邻 section 时长相同（waveformDuration 不变）时，
	 * 切 section 只有 time 变化，会导致 generateWaveformBitmap() 跳过绘制数据重建，
	 * drawPeaks() 读到旧窗口位置上的空数据 → 波形空白（制谱器里三个频谱会同时出问题）。
	 * 这里在 time 变化时强制标记重建绘制数据，保证每次切 section 都按新窗口重算。
	 */
	override function set_waveformTime(value:Float):Float
	{
		if (waveformTime != value)
			_drawDataDirty = true;
		return super.set_waveformTime(value);
	}
}
