package backend;

import flixel.FlxG;
import flixel.system.FlxAssets;
import flixel.util.FlxColor;
import flixel.system.ui.FlxSoundTray;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
#if flash
import openfl.text.AntiAliasType;
import openfl.text.GridFitType;
#end

/**
 * Dave Engine Style Sound Tray
 */
class DaveEngineSoundTray extends FlxSoundTray
{
	var text:TextField;

	public function new()
	{
		super();
		removeChildren();

		visible = false;
		scaleX = 2.0;
		scaleY = 2.0;
		var tmp:Bitmap = new Bitmap(new BitmapData(80, 30, true, 0x7F000000));
		screenCenter();
		addChild(tmp);

		text = new TextField();
		text.width = tmp.width;
		text.height = tmp.height;
		text.multiline = true;
		text.wordWrap = true;
		text.selectable = false;

		#if flash
		text.embedFonts = true;
		text.antiAliasType = AntiAliasType.NORMAL;
		text.gridFitType = GridFitType.PIXEL;
		#end
		var dtf:TextFormat = new TextFormat("assets/fonts/comic.ttf", 8, 0xFFFFFF, false);
		dtf.align = TextFormatAlign.CENTER;
		text.defaultTextFormat = dtf;
		addChild(text);
		text.text = "Volume - 100%";
		text.y = 14;

		var bx:Int = 10;
		var by:Int = 14;
		_bars = new Array();

		for (i in 0...10)
		{
			tmp = new Bitmap(new BitmapData(4, i + 1, false, FlxColor.WHITE));
			tmp.x = bx;
			tmp.y = by;
			addChild(tmp);
			_bars.push(tmp);
			bx += 6;
			by--;
		}

		y = -height;
		visible = false;
	}

	function getSound():openfl.media.Sound
	{
		final key:String = 'soundtray/clicky';
		return Paths.returnSound('sounds/$key');
	}

	override public function update(MS:Float):Void
	{
		// Animate stupid sound tray thing
		if (_timer > 0)
		{
			_timer -= MS / 1000;
		}
		else if (y > -height)
		{
			y -= (MS / 1000) * FlxG.height * 2;

			if (y <= -height)
			{
				visible = false;
				active = false;

				// Save sound preferences
				#if FLX_SAVE
				FlxG.save.data.mute = FlxG.sound.muted;
				FlxG.save.data.volume = FlxG.sound.volume;
				FlxG.save.flush();
				#end
			}
		}
	}

	override public function show(up:Bool = false):Void
	{
		if (!silent)
		{
			var sound = null;
			#if MODS_ALLOWED
			sound = getSound();
			#else
			sound = FlxAssets.getSound('clicky');
			#end
			if (sound != null)
				FlxG.sound.load(sound).play();
		}

		_timer = 1;
		y = 0;
		visible = true;
		active = true;
		var globalVolume:Int = Math.round(FlxG.sound.volume * 10);

		if (FlxG.sound.muted)
		{
			globalVolume = 0;
		}

		for (i in 0..._bars.length)
		{
			if (i < globalVolume)
			{
				_bars[i].alpha = 1;
			}
			else
			{
				_bars[i].alpha = 0.4;
			}
		}

		text.text = "Volume - " + globalVolume * 10 + "%";
	}

	override public function screenCenter():Void
	{
		scaleX = 2.0;
		scaleY = 2.0;

		x = (0.5 * (Lib.current.stage.stageWidth - 80 * 2.0) - FlxG.game.x);
	}
}
