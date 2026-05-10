package objects;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.Rating;
import backend.ClientPrefs;
import flixel.FlxG;
import flixel.FlxBasic;
import backend.Paths;

/**
 * 独立的评分计数器模块，提供动画效果
 */
class RatingCounter extends FlxBasic
{
	// 评分文本组件数组
	public var ratingTexts:Array<RatingText>;
	// MA和PA文本组件
	public var maText:FlxText;
	public var paText:FlxText;
	
	// 基础位置
	public var baseX:Float;
	public var baseY:Float;
	
	// 当前评分数据引用
	public var ratingsData:Array<Rating>;
	
	// 动画参数
	private static var ANIM_OFFSET:Float = 20; // 向右移动距离
	private static var ANIM_DURATION:Float = 0.15; // 动画时长（加快到0.15秒）
	private static var LINE_HEIGHT:Float = 18; // 固定行高，与字体大小一致
	
	// 评分颜色（确保透明度为FF，完全不透明）
	public static inline var COLOR_PERFECT:FlxColor = 0xFFC0CB; // 浅粉色
	public static inline var COLOR_SICK:FlxColor = 0xFF87CEEB; // 浅蓝色
	public static inline var COLOR_GOOD:FlxColor = 0xFF90EE90; // 浅绿色
	public static inline var COLOR_BAD:FlxColor = 0xFFFFA07A; // 浅红色
	public static inline var COLOR_SHIT:FlxColor = 0xFFDEB887; // 浅棕色
	public static inline var COLOR_DEFAULT:FlxColor = 0xFFFFFFFF; // 完全不透明白色
	
	/**
	 * 构造函数
	 * @param X 基础X坐标
	 * @param Y 基础Y坐标
	 * @param RatingsData 评分数据数组
	 */
	public function new(X:Float, Y:Float, RatingsData:Array<Rating>)
	{
		super();
		baseX = X;
		baseY = Y;
		ratingsData = RatingsData;
		ratingTexts = [];
		createRatingTexts();
	}
	
	/**
	 * 创建评分文本组件
	 */
	private function createRatingTexts():Void
	{
		// 创建对应的文本组件
		for (i in 0...ratingsData.length)
		{
			var rating:Rating = ratingsData[i];
			var text:String = getRatingText(rating.name);
			
			var ratingText:RatingText = new RatingText(
				baseX,
				baseY, // 初始位置，会在updatePosition中更新
				text,
				rating.name
			);
			
			ratingTexts.push(ratingText);
		}
		
		// 创建MA文本（仅在启用perfect时显示）
		maText = new FlxText(baseX, baseY, 0, '', 18);
		maText.setFormat(Paths.font("vcr.ttf"), 18, COLOR_DEFAULT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		maText.scrollFactor.set();
		maText.visible = !ClientPrefs.data.rmPerfect;
		
		// 创建PA文本
		paText = new FlxText(baseX, baseY, 0, '', 18);
		paText.setFormat(Paths.font("vcr.ttf"), 18, COLOR_DEFAULT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		paText.scrollFactor.set();
		
		// 初始化位置
		updatePosition();
	}
	
	/**
	 * 获取评分显示文本
	 * @param ratingName 评分名称
	 * @return 显示文本
	 */
	private function getRatingText(ratingName:String):String
	{
		var label:String = '';
		switch (ratingName.toLowerCase())
		{
			case 'perfect': label = 'Perfects';
			case 'sick': label = 'Sicks';
			case 'good': label = 'Goods';
			case 'bad': label = 'Bads';
			case 'shit': label = 'Shits';
			default: label = ratingName;
		}
		return label + ': 0';
	}
	
	/**
	 * 获取评分配色
	 * @param ratingName 评分名称
	 * @return 颜色
	 */
	private function getRatingColor(ratingName:String):FlxColor
	{
		switch (ratingName.toLowerCase())
		{
			case 'perfect': return COLOR_PERFECT;
			case 'sick': return COLOR_SICK;
			case 'good': return COLOR_GOOD;
			case 'bad': return COLOR_BAD;
			case 'shit': return COLOR_SHIT;
			default: return COLOR_DEFAULT;
		}
	}
	
	/**
	 * 添加到显示组
	 * @param group 显示组
	 */
	public function addToGroup(group:FlxTypedSpriteGroup<FlxSprite>):Void
	{
		for (ratingText in ratingTexts)
		{
			group.add(ratingText.text);
		}
		group.add(maText);
		group.add(paText);
	}
	
	/**
	 * 更新评分计数
	 */
	public function updateCounters():Void
	{
		var hasPerfect:Bool = !ClientPrefs.data.rmPerfect;
		var perfects:Int = 0;
		var sicks:Int = 0;
		var goods:Int = 0;
		var bads:Int = 0;
		var shits:Int = 0;
		
		if (hasPerfect)
		{
			perfects = ratingsData[0].hits;
			sicks = ratingsData[1].hits;
			goods = ratingsData[2].hits;
			bads = ratingsData[3].hits;
			shits = ratingsData[4].hits;
		}
		else
		{
			sicks = ratingsData[0].hits;
			goods = ratingsData[1].hits;
			bads = ratingsData[2].hits;
			shits = ratingsData[3].hits;
		}
		
		// 更新评分文本
		for (i in 0...ratingsData.length)
		{
			var rating:Rating = ratingsData[i];
			var ratingText:RatingText = ratingTexts[i];
			
			// 更新文本
			var label:String = '';
			switch (rating.name.toLowerCase())
			{
				case 'perfect': label = 'Perfects';
				case 'sick': label = 'Sicks';
				case 'good': label = 'Goods';
				case 'bad': label = 'Bads';
				case 'shit': label = 'Shits';
				default: label = rating.name;
			}
			ratingText.text.text = label + ': ' + rating.hits;
		}
		
		// 计算分母
		var MA_denominator:Float = sicks + goods + bads + shits;
		var PA_denominator:Float = goods + bads + shits;
		
		// 更新MA（仅在启用perfect时显示）
		if (hasPerfect)
		{
			maText.visible = true;
			if (perfects > 0 && MA_denominator > 0)
			{
				maText.text = 'MA: ' + FlxMath.roundDecimal(perfects / MA_denominator, 2);
			}
			else
			{
				maText.text = '';
			}
		}
		else
		{
			maText.visible = false;
		}
		
		// 更新PA
		if (PA_denominator > 0)
		{
			var PA_numerator:Float = hasPerfect ? (perfects + sicks) : sicks;
			paText.text = 'PA: ' + FlxMath.roundDecimal(PA_numerator / PA_denominator, 2);
		}
		else
		{
			paText.text = '';
		}
	}
	
	/**
	 * 触发评分命中动画
	 * @param ratingName 被命中的评分名称
	 */
	public function triggerHitAnimation(ratingName:String):Void
	{
		if (!ClientPrefs.data.ratCounterAnimation)
			return;
		
		// 查找对应的文本组件
		for (ratingText in ratingTexts)
		{
			if (ratingText.ratingName.toLowerCase() == ratingName.toLowerCase())
			{
				triggerAnimation(ratingText);
				break;
			}
		}
	}
	
	/**
	 * 触发单个文本的动画
	 * @param ratingText 评分文本对象
	 */
	private function triggerAnimation(ratingText:RatingText):Void
	{
		var text:FlxText = ratingText.text;
		var targetColor:FlxColor = getRatingColor(ratingText.ratingName);
		
		// 保存原始位置和颜色
		var originalX:Float = ratingText.baseX;
		var originalColor:FlxColor = COLOR_DEFAULT;
		
		// 取消正在进行的tween
		if (ratingText.tween != null)
		{
			ratingText.tween.cancel();
			ratingText.tween.destroy();
		}
		if (ratingText.colorTween != null)
		{
			ratingText.colorTween.cancel();
			ratingText.colorTween.destroy();
		}
		
		// 1. 瞬间向右移动
		text.x = originalX + ANIM_OFFSET;
		
		// 2. 向左tween回原位
		ratingText.tween = FlxTween.tween(text, { x: originalX }, ANIM_DURATION, {
			ease: FlxEase.quadOut
		});
		
		// 3. 颜色渐变动画 - 使用自定义方法，确保透明度不变
		text.color = targetColor;
		ratingText.colorTween = tweenColorNoAlpha(text, ANIM_DURATION, targetColor, originalColor);
	}
	
	/**
	 * 自定义颜色tween方法，透明度保持为FF不变
	 * @param target 目标对象
	 * @param duration 持续时间
	 * @param fromColor 起始颜色
	 * @param toColor 结束颜色
	 * @return FlxTween对象
	 */
	private function tweenColorNoAlpha(target:FlxText, duration:Float, fromColor:FlxColor, toColor:FlxColor):FlxTween
	{
		// 创建动画进度tween
		var tweenObj = { t: 0.0 };
		return FlxTween.tween(tweenObj, { t: 1.0 }, duration, {
			ease: FlxEase.linear,
			onUpdate: function(tw:FlxTween):Void
			{
				var progress:Float = tweenObj.t;
				var r:Int = Std.int(fromColor.red + (toColor.red - fromColor.red) * progress);
				var g:Int = Std.int(fromColor.green + (toColor.green - fromColor.green) * progress);
				var b:Int = Std.int(fromColor.blue + (toColor.blue - fromColor.blue) * progress);
				// 保持透明度为FF（完全不透明）
				target.color = FlxColor.fromRGB(r, g, b, 0xFF);
			}
		});
	}
	
	/**
	 * 设置可见性
	 * @param visible 是否可见
	 */
	public function setVisible(visible:Bool):Void
	{
		for (ratingText in ratingTexts)
		{
			ratingText.text.visible = visible;
		}
		maText.visible = visible && !ClientPrefs.data.rmPerfect;
		paText.visible = visible;
	}
	
	/**
	 * 更新位置（居中）
	 */
	public function updatePosition():Void
	{
		// 计算显示的总行数（评分 + MA + PA）
		var totalLines:Int = ratingTexts.length;
		if (!ClientPrefs.data.rmPerfect) totalLines += 2;
		else totalLines += 1;
		
		var totalHeight:Float = totalLines * LINE_HEIGHT;
		var startY:Float = (FlxG.height - totalHeight) / 2;
		var currentY:Float = startY;
		
		// 更新评分文本位置
		for (i in 0...ratingTexts.length)
		{
			var ratingText:RatingText = ratingTexts[i];
			ratingText.baseY = currentY;
			ratingText.text.y = currentY;
			currentY += LINE_HEIGHT;
		}
		
		// 更新MA文本位置
		maText.y = currentY;
		if (!ClientPrefs.data.rmPerfect) currentY += LINE_HEIGHT;
		
		// 更新PA文本位置
		paText.y = currentY;
	}
	
	/**
	 * 销毁
	 */
	override function destroy():Void
	{
		for (ratingText in ratingTexts)
		{
			if (ratingText.tween != null)
			{
				ratingText.tween.cancel();
				ratingText.tween.destroy();
			}
			if (ratingText.colorTween != null)
			{
				ratingText.colorTween.cancel();
				ratingText.colorTween.destroy();
			}
			ratingText.text.destroy();
		}
		maText.destroy();
		paText.destroy();
		ratingTexts = [];
		super.destroy();
	}
}

/**
 * 评分文本数据结构
 */
private class RatingText
{
	public var text:FlxText;
	public var ratingName:String;
	public var baseX:Float;
	public var baseY:Float;
	public var tween:FlxTween; // 位置动画tween引用
	public var colorTween:FlxTween; // 颜色tween引用

	public function new(X:Float, Y:Float, Text:String, RatingName:String)
	{
		text = new FlxText(X, Y, 0, Text, 18);
		text.setFormat(Paths.font("vcr.ttf"), 18, RatingCounter.COLOR_DEFAULT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.scrollFactor.set();

		ratingName = RatingName;
		baseX = X;
		baseY = Y;
		tween = null;
		colorTween = null;
	}
}
