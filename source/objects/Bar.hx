package objects;

import flixel.math.FlxRect;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.geom.Point;

class Bar extends FlxSpriteGroup
{
	public var leftBar:FlxSprite;
	public var rightBar:FlxSprite;
	public var bg:FlxSprite;
	public var stripedOverlay:FlxSprite;
	public var valueFunction:Void->Float = null;
	public var percent(default, set):Float = 0;
	public var bounds:Dynamic = {min: 0, max: 1};
	public var leftToRight(default, set):Bool = true;
	public var barCenter(default, null):Float = 0;
	public var showStripes:Bool = false;
	public var stripeWidth:Int = 7;
	public var stripeGap:Int = 12;
	public var stripeAngle:Float = 45;
	public var stripeColor:FlxColor = FlxColor.WHITE;
	public var stripeBaseAlpha:Float = 0.2;

	// you might need to change this if you want to use a custom bar
	public var barWidth(default, set):Int = 1;
	public var barHeight(default, set):Int = 1;
	public var barOffset:FlxPoint = new FlxPoint(3, 3);

	public function new(x:Float, y:Float, image:String = 'healthBar', valueFunction:Void->Float = null, boundX:Float = 0, boundY:Float = 1)
	{
		super(x, y);
		
		this.valueFunction = valueFunction;
		setBounds(boundX, boundY);
		
		bg = new FlxSprite().loadGraphic(Paths.image(image));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		barWidth = Std.int(bg.width - 6);
		barHeight = Std.int(bg.height - 6);

		leftBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height), FlxColor.WHITE);
		leftBar.antialiasing = antialiasing = ClientPrefs.data.antialiasing;

		rightBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height), FlxColor.WHITE);
		rightBar.color = FlxColor.BLACK;
		rightBar.antialiasing = ClientPrefs.data.antialiasing;

		stripedOverlay = new FlxSprite();
		stripedOverlay.antialiasing = ClientPrefs.data.antialiasing;

		add(leftBar);
		add(rightBar);
		add(stripedOverlay);
		add(bg);
		regenerateClips();
	}

	public var enabled:Bool = true;
	override function update(elapsed:Float) {
		if(!enabled)
		{
			super.update(elapsed);
			return;
		}

		if(valueFunction != null)
		{
			var value:Null<Float> = FlxMath.remapToRange(FlxMath.bound(valueFunction(), bounds.min, bounds.max), bounds.min, bounds.max, 0, 100);
			percent = (value != null ? value : 0);
		}
		else percent = 0;
		super.update(elapsed);
	}

	override function set_alpha(value:Float):Float
	{
		super.set_alpha(value);
		if(stripedOverlay != null)
			stripedOverlay.alpha = stripeBaseAlpha * value;
		return value;
	}
	
	public function setBounds(min:Float, max:Float)
	{
		bounds.min = min;
		bounds.max = max;
	}

	public function setColors(left:FlxColor = null, right:FlxColor = null)
	{
		if (left != null)
			leftBar.color = left;
		if (right != null)
			rightBar.color = right;
	}

	public function updateBar()
	{
		if(leftBar == null || rightBar == null) return;

		leftBar.setPosition(bg.x, bg.y);
		rightBar.setPosition(bg.x, bg.y);

		var leftSize:Float = 0;
		if(leftToRight) leftSize = FlxMath.lerp(0, barWidth, percent / 100);
		else leftSize = FlxMath.lerp(0, barWidth, 1 - percent / 100);

		leftBar.clipRect.width = leftSize;
		leftBar.clipRect.height = barHeight;
		leftBar.clipRect.x = barOffset.x;
		leftBar.clipRect.y = barOffset.y;

		rightBar.clipRect.width = barWidth - leftSize;
		rightBar.clipRect.height = barHeight;
		rightBar.clipRect.x = barOffset.x + leftSize;
		rightBar.clipRect.y = barOffset.y;

		barCenter = leftBar.x + leftSize + barOffset.x;

		if(stripedOverlay != null && showStripes)
		{
			stripedOverlay.clipRect = new FlxRect(barOffset.x, barOffset.y, barWidth, barHeight);
			stripedOverlay.clipRect = stripedOverlay.clipRect;
			stripedOverlay.visible = true;
		}
		else if(stripedOverlay != null)
		{
			stripedOverlay.visible = false;
		}

		leftBar.clipRect = leftBar.clipRect;
		rightBar.clipRect = rightBar.clipRect;
	}

	public function createStripedOverlay()
	{
		if(stripedOverlay == null || bg == null) return;
		
		var width:Int = Std.int(bg.width);
		var height:Int = Std.int(bg.height);
		var stripeW:Int = stripeWidth;
		var gap:Int = stripeGap;
		var angleRad:Float = stripeAngle * Math.PI / 180;
		
		var diagonal:Float = Math.sqrt(width * width + height * height);
		var totalStripeWidth:Int = stripeW + gap;
		
		var padding:Int = Math.ceil(diagonal);
		var textureSize:Int = Math.ceil(diagonal) + padding * 2;
		
		var tempBmp:BitmapData = new BitmapData(textureSize, textureSize, true, 0x00000000);
		
		var numStripes:Int = Math.ceil(textureSize / totalStripeWidth) + 2;
		for(i in 0...numStripes)
		{
			var x:Float = i * totalStripeWidth;
			tempBmp.fillRect(new Rectangle(x, 0, stripeW, textureSize), stripeColor);
		}
		
		var rotatedBmp:BitmapData = new BitmapData(textureSize, textureSize, true, 0x00000000);
		var matrix:Matrix = new Matrix();
		matrix.translate(-textureSize / 2, -textureSize / 2);
		matrix.rotate(-angleRad);
		matrix.translate(textureSize / 2, textureSize / 2);
		rotatedBmp.draw(tempBmp, matrix);
		
		var finalBmp:BitmapData = new BitmapData(width, height, true, 0x00000000);
		var srcX:Int = Std.int((textureSize - width) / 2);
		var srcY:Int = Std.int((textureSize - height) / 2);
		finalBmp.copyPixels(rotatedBmp, new Rectangle(srcX, srcY, width, height), new Point(0, 0));
		
		stripedOverlay.loadGraphic(finalBmp);
		stripedOverlay.visible = showStripes;
		updateBar();
	}
	
	public function regenerateClips()
	{
		if(leftBar != null)
		{
			leftBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			leftBar.updateHitbox();
			leftBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		if(rightBar != null)
		{
			rightBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			rightBar.updateHitbox();
			rightBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		if(showStripes && stripedOverlay != null)
		{
			createStripedOverlay();
		}
		updateBar();
	}

	private function set_percent(value:Float)
	{
		var doUpdate:Bool = false;
		if(value != percent) doUpdate = true;
		percent = value;

		if(doUpdate) updateBar();
		return value;
	}

	private function set_leftToRight(value:Bool)
	{
		leftToRight = value;
		updateBar();
		return value;
	}

	private function set_barWidth(value:Int)
	{
		barWidth = value;
		regenerateClips();
		return value;
	}

	private function set_barHeight(value:Int)
	{
		barHeight = value;
		regenerateClips();
		return value;
	}
}
