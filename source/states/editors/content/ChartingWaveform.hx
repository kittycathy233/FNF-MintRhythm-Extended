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

		var arrayLength:Int = Math.ceil(waveformBuffer.length / _durationSamples) * _effectiveSize;
		drawPoints.resize(arrayLength);
		resetDrawArray(drawPoints);

		if (channel < waveformBuffer.numChannels)
			buildDrawData(channel, drawPoints, false, true);
	}
}
