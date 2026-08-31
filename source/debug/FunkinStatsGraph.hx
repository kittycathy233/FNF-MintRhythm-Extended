package debug;

import flixel.math.FlxMath;
import flixel.util.FlxColor;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.AntiAliasType;
import openfl.display.JointStyle;

/**
 * 原版 FNF FunkinDebugDisplay 的迷你统计折线图组件。
 * 完整复刻自原版 `FunkinStatsGraph`，并做了高度参数化：
 * 颜色、线宽、历史长度、坐标轴、文本字体/大小/行内容均可由外部配置。
 */
class FunkinStatsGraph extends Sprite
{
	public static inline var DEFAULT_HISTORY_MAX:Int = 100;

	/** 数据最小值（用于纵向缩放） */
	public var minValue:Float = 0;
	/** 数据最大值（用于纵向缩放） */
	public var maxValue:Float = 0;
	/** 折线颜色 */
	public var graphColor:FlxColor;
	/** 历史采样点上限长度 */
	public var historyMax:Int;
	/** 折线粗细 */
	public var lineThickness:Float;
	/** 坐标轴颜色 */
	public var axisColor:FlxColor;
	/** 坐标轴透明度 */
	public var axisAlpha:Float;
	/** 图形相对坐标轴的内边距（向右缩进） */
	public var axisInset:Float;
	/** 是否显示上方的文本信息 */
	public var showText:Bool;
	/** 是否启用曲线平滑（用二次贝塞尔中点圆滑折线，让图看起来不那么尖锐） */
	public var smooth:Bool;
	/** 文本字体（openfl 直用的字体，可为 "_sans" 或资产路径） */
	public var fontName:String;
	/** 文本字号 */
	public var textSize:Int;
	/** 显示在折线上方的文本行 */
	public var textLines:Array<String> = [];

	public var history:Array<Float> = [];
	public var textDisplay:TextField;
	public var textGap:Int = 0;
	public var axis:Shape;
	public var axisWidth:Int;
	public var axisHeight:Int;

	public function new(x:Int, y:Int, width:Int, height:Int, graphColor:FlxColor = 0xFF00D9FF, fontName:String = "vcr.ttf", textSize:Int = 12)
	{
		super();

		this.x = x;
		this.y = y;
		this.graphColor = graphColor;
		this.axisWidth = width;
		this.axisHeight = height;
		this.fontName = fontName;
		this.textSize = textSize;

		this.historyMax = FunkinStatsGraph.DEFAULT_HISTORY_MAX;
		this.lineThickness = 1;
		this.axisColor = 0xFFFFFF;
		this.axisAlpha = 0.5;
		this.axisInset = 4;
		this.showText = true;
		this.smooth = false;
		this.textLines = [];

		if (showText)
		{
			buildText();
		}
		buildAxis();
	}

	/**
	 * 从项目字体路径建立一个开放的 TextField。
	 */
	function buildText():Void
	{
		textDisplay = new TextField();
		textDisplay.width = 500;
		textDisplay.y -= 22;
		textDisplay.selectable = false;
		textDisplay.mouseEnabled = false;
		textDisplay.defaultTextFormat = new TextFormat(fontName, textSize, (graphColor:Int), LEFT);
		textDisplay.antiAliasType = AntiAliasType.NORMAL;
		textDisplay.multiline = true;
		addChild(textDisplay);
	}

	public function updateText():Void
	{
		if (textDisplay != null)
		{
			textDisplay.defaultTextFormat = new TextFormat(fontName, textSize, (graphColor:Int), LEFT);
			// 文本高度可能随字号/行数变化，让文本底边始终贴着图形顶部向上生长，
			// 这样文本本身不会压到折线图，也便于外部根据 textHeight 做纵向布局。
			textDisplay.width = 500;
			textDisplay.text = textLines.join('\n');
			// 文本底边与图形顶部之间留出 textGap 间距，避免文字紧贴折线
			textDisplay.y = -textDisplay.textHeight - textGap;
		}
	}

	function buildAxis():Void
	{
		axis = new Shape();
		axis.x += axisInset;
		addChild(axis);
		drawAxes();
	}

	function drawAxes():Void
	{
		axis.graphics.clear();

		axis.graphics.lineStyle(1, (axisColor:Int), axisAlpha, false, null, null, JointStyle.MITER, 255);

		axis.graphics.moveTo(0, 0);
		axis.graphics.lineTo(0, axisHeight);

		axis.graphics.moveTo(0, axisHeight);
		axis.graphics.lineTo(axisWidth, axisHeight);
	}

	function drawGraph():Void
	{
		graphics.clear();

		graphics.lineStyle(lineThickness, (graphColor:Int), 1, false, null, null, JointStyle.MITER, 255);

		if (history.length == 0)
		{
			return;
		}

		var inc:Float = (axisWidth - 2) / (historyMax - 1);
		var range:Float = Math.max(maxValue - minValue, maxValue * 0.1);
		if (range <= 0) range = 1;
		var scale:Float = axisHeight / range;

		// 先收集所有点的坐标
		var ptsX:Array<Float> = [];
		var ptsY:Array<Float> = [];
		for (i in 0...history.length)
		{
			var pointY:Float = axisHeight - ((history[i] - minValue) * scale) - 1;
			pointY = Math.max(0, Math.min(pointY, axisHeight));
			ptsX.push(axis.x + 1 + (i * inc));
			ptsY.push(pointY);
		}

		if (!smooth)
		{
			for (i in 0...ptsX.length)
			{
				if (i == 0) graphics.moveTo(ptsX[i], ptsY[i]);
				else graphics.lineTo(ptsX[i], ptsY[i]);
			}
			return;
		}

		// 平滑：以相邻两点的中点作为曲线端点、以原采样点为控制点的二次贝塞尔，
		// 能在不明显偏离数据点的前提下让折线变得圆润。
		if (ptsX.length == 1)
		{
			graphics.moveTo(ptsX[0], ptsY[0]);
			return;
		}

		graphics.moveTo(ptsX[0], ptsY[0]);
		for (i in 1...(ptsX.length - 1))
		{
			var midX:Float = (ptsX[i] + ptsX[i + 1]) / 2;
			var midY:Float = (ptsY[i] + ptsY[i + 1]) / 2;
			graphics.curveTo(ptsX[i], ptsY[i], midX, midY);
		}
		graphics.lineTo(ptsX[ptsX.length - 1], ptsY[ptsX.length - 1]);
	}

	public function update(value:Float):Void
	{
		history.push(value);

		if (history.length > historyMax)
		{
			history.shift();
		}

		maxValue = Math.max(maxValue, value);
		minValue = Math.min(minValue, value);

		drawGraph();
	}

	public function average():Float
	{
		if (history.length == 0)
		{
			return 0;
		}

		var sum:Float = 0;
		for (v in history)
		{
			sum += v;
		}
		return sum / history.length;
	}

	public function lowest():Float
	{
		if (history.length == 0)
		{
			return 0;
		}

		var val:Float = history[0];
		for (v in history)
		{
			if (v < val)
			{
				val = v;
			}
		}
		return val;
	}

	/**
	 * 整体应用一组显示配置（坐标轴、线宽、历史长度、文本可见性）。
	 */
	public function applyConfig(newHistoryMax:Int, newLineThickness:Float, newAxisColor:FlxColor, newAxisAlpha:Float, newAxisInset:Float,
			newShowText:Bool, newSmooth:Bool):Void
	{
		historyMax = newHistoryMax;
		lineThickness = newLineThickness;
		axisColor = newAxisColor;
		axisAlpha = newAxisAlpha;
		axisInset = newAxisInset;
		showText = newShowText;
		smooth = newSmooth;

		// 历史上限变化时裁剪已有采样
		while (history.length > historyMax)
		{
			history.shift();
		}

		if (showText && textDisplay == null)
		{
			buildText();
		}
		else if (!showText && textDisplay != null)
		{
			removeChild(textDisplay);
			textDisplay = null;
		}

		axis.x = axisInset;
		drawAxes();
		drawGraph();
	}

	public function destroy():Void
	{
		if (axis != null)
		{
			removeChild(axis);
			axis = null;
		}
		if (textDisplay != null)
		{
			removeChild(textDisplay);
			textDisplay = null;
		}
		history = null;
	}
}