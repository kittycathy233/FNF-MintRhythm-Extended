package states.editors.old;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSpriteUtil;

/**
 * Drop-in stand-in for `flixel.addons.ui.FlxUISlider`, used by the ported 0.7.3 editor.
 *
 * `FlxUISlider` inherits `flixel.addons.ui.FlxSlider`, whose `update()` calls
 * `getDefaultCamera()` -- an API this project's Flixel 5.9.0 does not ship, so simply referencing
 * the widget breaks the build. Rather than hand-patching an installed haxelib (which would not
 * survive a fresh `haxelib install`), the handful of slider features the editor actually needs are
 * reimplemented here, keeping the original look and the "bind to a variable by name" behaviour.
 */
class OldSlider extends FlxSpriteGroup
{
	public var body:FlxSprite;
	public var handle:FlxSprite;

	public var nameLabel:FlxText;
	public var valueLabel:FlxText;
	public var minLabel:FlxText;
	public var maxLabel:FlxText;

	public var minValue:Float;
	public var maxValue:Float;
	public var decimals:Int = 2;

	/** Name of the variable on `_object` this slider reads from / writes to. */
	public var varString:String;

	/** Called with the new value whenever the user drags the handle. */
	public var onChange:Float->Void;

	public var value(get, never):Float;

	var _object:Dynamic;
	var _bounds:FlxRect;
	var _width:Int;
	var _height:Int;
	var _thickness:Int;
	var _color:FlxColor;
	var _handleColor:FlxColor;
	var _lastValue:Float = Math.NaN;

	public function new(Object:Dynamic, VarString:String, X:Float = 0, Y:Float = 0, MinValue:Float = 0, MaxValue:Float = 10, Width:Int = 100,
			Height:Int = 15, Thickness:Int = 3, Color:FlxColor = FlxColor.WHITE, HandleColor:FlxColor = FlxColor.BLACK)
	{
		super();

		x = X;
		y = Y;

		if (MinValue == MaxValue)
			FlxG.log.error('OldSlider: MinValue and MaxValue can\'t be the same ($MinValue)');

		decimals = Std.int(Math.max(FlxMath.getDecimals(MinValue), FlxMath.getDecimals(MaxValue))) + 1;

		minValue = MinValue;
		maxValue = MaxValue;
		_object = Object;
		varString = VarString;
		_width = Width;
		_height = Height;
		_thickness = Thickness;
		_color = Color;
		_handleColor = HandleColor;

		createSlider();
	}

	function createSlider():Void
	{
		offset.set(7, 18);
		_bounds = FlxRect.get(x + offset.x, y + offset.y, _width, _height);

		body = new FlxSprite(offset.x, offset.y);
		body.makeGraphic(_width, _height, FlxColor.TRANSPARENT, false, 'oldSlider:W=${_width}H=${_height}C=${_color.toHexString()}T=$_thickness');
		body.scrollFactor.set();
		FlxSpriteUtil.drawLine(body, 0, _height / 2, _width, _height / 2, {color: _color, thickness: _thickness});

		handle = new FlxSprite(offset.x, offset.y);
		handle.makeGraphic(_thickness, _height, _handleColor);
		handle.scrollFactor.set();

		nameLabel = new FlxText(offset.x, 0, _width, varString);
		nameLabel.alignment = CENTER;
		nameLabel.color = _color;
		nameLabel.scrollFactor.set();

		var textOffset:Float = _height + offset.y + 3;

		valueLabel = new FlxText(offset.x, textOffset, _width);
		valueLabel.alignment = CENTER;
		valueLabel.color = _handleColor;
		valueLabel.scrollFactor.set();

		minLabel = new FlxText(-50 + offset.x, textOffset, 100, Std.string(minValue));
		minLabel.alignment = CENTER;
		minLabel.color = _color;
		minLabel.scrollFactor.set();

		maxLabel = new FlxText(_width - 50 + offset.x, textOffset, 100, Std.string(maxValue));
		maxLabel.alignment = CENTER;
		maxLabel.color = _color;
		maxLabel.scrollFactor.set();

		add(body);
		add(handle);
		add(nameLabel);
		add(valueLabel);
		add(minLabel);
		add(maxLabel);
	}

	override public function update(elapsed:Float):Void
	{
		_bounds.set(x + offset.x, y + offset.y, _width, _height);

		#if FLX_MOUSE
		if (FlxG.mouse.pressed)
		{
			var mousePosition = FlxG.mouse.getViewPosition(camera);
			if (FlxMath.pointInFlxRect(mousePosition.x, mousePosition.y, _bounds))
			{
				var ratio:Float = FlxMath.bound((mousePosition.x - _bounds.x) / _width, 0, 1);
				setValue(minValue + ratio * (maxValue - minValue));
			}
			mousePosition.put();
		}
		#end

		// Anything can change the bound variable (keyboard shortcuts do), so re-sync every frame.
		var current:Float = value;
		handle.x = x + offset.x + (FlxMath.bound((current - minValue) / (maxValue - minValue), 0, 1) * _width);
		valueLabel.text = Std.string(FlxMath.roundDecimal(current, decimals));

		super.update(elapsed);
	}

	function setValue(newValue:Float):Void
	{
		if (_lastValue == newValue)
			return;

		_lastValue = newValue;
		if (varString != null && _object != null)
			Reflect.setProperty(_object, varString, newValue);

		if (onChange != null)
			onChange(newValue);
	}

	function get_value():Float
	{
		if (varString == null || _object == null)
			return minValue;

		var raw:Dynamic = Reflect.getProperty(_object, varString);
		return (raw != null) ? cast(raw, Float) : minValue;
	}

	override public function destroy():Void
	{
		_bounds = FlxDestroyUtil.put(_bounds);
		_object = null;
		onChange = null;
		super.destroy();
	}
}
