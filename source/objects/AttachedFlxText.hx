package objects;

import flixel.text.FlxText;
import flixel.FlxSprite;

/**
 * A FlxText that follows another sprite (its `sprTracker`), used to display
 * an option's value / keybind next to the option label while the list scrolls.
 * Replaces the old Alphabet-based `AttachedText` so the whole settings UI
 * shares one font/rendering path.
 */
class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var copyAlpha:Bool = true;
	public var copyVisible:Bool = true;

	public function new(x:Float = 0, y:Float = 0, fieldWidth:Float = 0, text:String = "", size:Int = 16)
	{
		super(x, y, fieldWidth, text, size);
	}

	override function update(elapsed:Float):Void
	{
		if (sprTracker != null)
		{
			setPosition(sprTracker.x + offsetX, sprTracker.y + offsetY);
			if (copyVisible)
				visible = sprTracker.visible;
			if (copyAlpha)
				alpha = sprTracker.alpha;
		}
		super.update(elapsed);
	}
}
