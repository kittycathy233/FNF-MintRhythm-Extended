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
import openfl.display.GradientType;
import openfl.geom.Matrix;
import openfl.geom.ColorTransform;
import haxe.io.Bytes;
import openfl.utils.AssetType;
import openfl.utils.Assets;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
#if flash
import openfl.text.AntiAliasType;
import openfl.text.GridFitType;
#end

/**
 * The Kathy sound tray
 */
class KathySoundTray extends FlxSoundTray
{
	var _label:TextField;
	var _percentLabel:TextField;
	var _volumeIcon:Bitmap;
	var _bg:Sprite;
	var _progressBg:Sprite;
	var _progressFill:Sprite;
	var _minWidth:Int = 200;
	var _progressBarHeight:Int = 10;
	var _targetProgressWidth:Float = 0;
	var _currentProgressWidth:Float = 0;
	var _currentColor:FlxColor;
	var _targetColor:FlxColor;
	var _frameCounter:Int = 0;
	var _updateFrequency:Int = 1;
	var volumeMaxSound:String;
	
	var _lerpYPos:Float;
	var _alphaTarget:Float;
	var _showTime:Float;
	var _isShowing:Bool;

	public function new()
	{
		super();
		removeChildren();

		_bg = new Sprite();
		_bg.graphics.beginFill(0xDD000000);
		_bg.graphics.drawRoundRect(0, 0, _minWidth, 45, 12, 12);
		_bg.graphics.endFill();
		addChild(_bg);

		try {
			var iconBitmapData = getImage('images/soundtray/volicon');
			_volumeIcon = new Bitmap(iconBitmapData);
			_volumeIcon.x = 10;
			_volumeIcon.y = 12;
			_volumeIcon.width = 20;
			_volumeIcon.height = 20;
			addChild(_volumeIcon);
		} catch (e:Dynamic) {
			trace('Failed to load volume icon: ' + e);
		}

		_label = new TextField();
		_label.width = 120;
		_label.height = 20;
		_label.multiline = false;
		_label.selectable = false;

		#if flash
		_label.embedFonts = true;
		_label.antiAliasType = AntiAliasType.NORMAL;
		_label.gridFitType = GridFitType.PIXEL;
		#end
		
		var dtf:TextFormat = new TextFormat('Furore-2.otf', 14, 0xFFFFFF, false);
		dtf.align = TextFormatAlign.LEFT;
		_label.defaultTextFormat = dtf;
		addChild(_label);
		_label.text = 'VOLUME';
		_label.x = 40;
		_label.y = 5;

		_percentLabel = new TextField();
		_percentLabel.width = 100;
		_percentLabel.height = 20;
		_percentLabel.multiline = false;
		_percentLabel.selectable = false;

		#if flash
		_percentLabel.embedFonts = true;
		_percentLabel.antiAliasType = AntiAliasType.NORMAL;
		_percentLabel.gridFitType = GridFitType.PIXEL;
		#end
		
		var percentFormat = new TextFormat('Furore-2.otf', 14, 0xFFFFFF, true);
		percentFormat.align = TextFormatAlign.RIGHT;
		_percentLabel.defaultTextFormat = percentFormat;
		addChild(_percentLabel);
		_percentLabel.x = _minWidth - _percentLabel.width - 18;
		_percentLabel.y = 5;

		_progressBg = new Sprite();
		var bgMatrix = new Matrix();
		bgMatrix.createGradientBox(_minWidth - 35, _progressBarHeight, Math.PI / 2, 0, 0);
		_progressBg.graphics.beginGradientFill(
			GradientType.LINEAR,
			[0x606060, 0x303030],
			[1.0, 1.0],
			[0, 255],
			bgMatrix
		);
		_progressBg.graphics.drawRoundRect(35, 28, _minWidth - 50, _progressBarHeight, 6, 6);
		_progressBg.graphics.endFill();
		
		_progressBg.graphics.lineStyle(1, 0x202020, 0.5);
		_progressBg.graphics.drawRoundRect(35, 28, _minWidth - 50, _progressBarHeight, 6, 6);
		addChild(_progressBg);

		_progressFill = new Sprite();
		addChild(_progressFill);
		
		screenCenter();
		_lerpYPos = -height - 10;
		y = _lerpYPos;
		visible = false;
		alpha = 0;
		_showTime = 0;
		_isShowing = false;
		
		_currentProgressWidth = (_minWidth - 50) * FlxG.sound.volume;
		_targetProgressWidth = _currentProgressWidth;
		
		var initialVolume = FlxG.sound.volume;
		_currentColor = getVolumeColor(initialVolume);
		_targetColor = _currentColor;

		volumeUpSound = 'Meow';
		volumeDownSound = 'Meow';
		volumeMaxSound = 'VolMAX';
	}

	function getImage(path:String):Dynamic
	{
		final imagePath = Paths.getPath('$path.png', IMAGE);
		#if MODS_ALLOWED
		return BitmapData.fromFile(imagePath);
		#end
		return Assets.getBitmapData(imagePath);
	}

	function getSound(path):openfl.media.Sound
	{
		final key:String = 'soundtray/Kathy/$path';
		return Paths.returnSound('sounds/$key');
	}

	function easeOutElastic(t:Float):Float
	{
		var c4 = (2 * Math.PI) / 3;
		if (t == 0)
			return 0;
		if (t == 1)
			return 1;
		return Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
	}

	function easeOutBounce(t:Float):Float
	{
		var n1 = 7.5625;
		var d1 = 2.75;
		if (t < 1 / d1)
			return n1 * t * t;
		else if (t < 2 / d1)
			return n1 * (t -= 1.5 / d1) * t + 0.75;
		else if (t < 2.5 / d1)
			return n1 * (t -= 2.25 / d1) * t + 0.9375;
		else
			return n1 * (t -= 2.625 / d1) * t + 0.984375;
	}

	override public function update(MS:Float):Void
	{
		_frameCounter++;
		var shouldUpdateVisuals = (_frameCounter % _updateFrequency == 0);

		if (_timer > 0)
		{
			_timer -= (MS / 1000);
			_isShowing = true;
			_showTime += MS;
		}
		else
		{
			_isShowing = false;
			_showTime = 0;
		}

		// 动画计算
		var startY = -height - 10;
		var endY = 10;
		var duration = 0.5; // 0.5秒动画

		if (_isShowing)
		{
			// 显示动画：弹跳飞入
			var t = Math.min(_showTime / (duration * 1000), 1);
			var eased = easeOutElastic(t); // 使用弹性效果
			y = startY + (endY - startY) * eased;
			alpha = CoolUtil.coolLerp(alpha, 1, 0.25);
		}
		else if (y > startY)
		{
			// 隐藏动画：简单淡出
			y = CoolUtil.coolLerp(y, startY, 0.1);
			alpha = CoolUtil.coolLerp(alpha, 0, 0.25);
		}

		if (y <= startY && !_isShowing)
		{
			visible = false;
			active = false;

			#if FLX_SAVE
			if (FlxG.save.isBound)
			{
				FlxG.save.data.mute = FlxG.sound.muted;
				FlxG.save.data.volume = FlxG.sound.volume;
				FlxG.save.flush();
			}
			#end
		}

		var progressSpeed = 0.3;
		if (Math.abs(_currentProgressWidth - _targetProgressWidth) > 0.5)
		{
			_currentProgressWidth += (_targetProgressWidth - _currentProgressWidth) * progressSpeed;
			if (shouldUpdateVisuals)
				updateProgressBarVisual();
		}
		else
		{
			_currentProgressWidth = _targetProgressWidth;
			if (shouldUpdateVisuals)
				updateProgressBarVisual();
		}

		var currentVolume = _currentProgressWidth / (_minWidth - 50);
		_targetColor = getVolumeColor(currentVolume);

		var colorSpeed = 0.04;
		if (!areColorsEqual(_currentColor, _targetColor))
		{
			_currentColor = interpolateColor(_currentColor, _targetColor, colorSpeed);
			if (shouldUpdateVisuals)
				updateProgressBarVisual();
		}
		else
		{
			_currentColor = _targetColor;
			if (shouldUpdateVisuals)
				updateProgressBarVisual();
		}
	}

	override public function show(up:Bool = false):Void
	{
		final volume = FlxG.sound.muted ? 0 : FlxG.sound.volume;
		var isMaxVolume = volume >= 0.99;
		var isMuted = volume <= 0.01;
		
		if (!silent)
		{
			var sound = null;
			#if MODS_ALLOWED
			sound = getSound((up ? volumeUpSound : volumeDownSound));
			#else
			sound = FlxAssets.getSound(up ? volumeUpSound : volumeDownSound);
			#end

			if (isMaxVolume && volumeMaxSound != null)
				sound = getSound(volumeMaxSound);
			
			if (sound != null)
				FlxG.sound.load(sound).play();
		}
		
		_timer = 1;
		// 如果已经在显示，重置动画时间
		if (!_isShowing)
			_showTime = 0;
		visible = true;
		active = true;
		
		_targetProgressWidth = Math.round((_minWidth - 50) * volume);
		updateVolumeIcon(volume);
		
		var percentage = Math.round(volume * 100);
		_label.text = 'VOLUME';

		if (isMuted)
		{
			_percentLabel.text = 'MUTED';
		}
		else if (isMaxVolume)
		{
			_percentLabel.text = 'MAX';
		}
		else
		{
			_percentLabel.text = percentage + '%';
		}
	}

	override public function screenCenter():Void
	{
		scaleX = 2.0;
		scaleY = 2.0;

		x = (0.5 * (Lib.current.stage.stageWidth - _minWidth * 2.0) - FlxG.game.x);
	}

	function updateProgressBarVisual():Void
	{
		_progressFill.graphics.clear();
		
		var barColor = _currentColor;
		
		var fillMatrix = new Matrix();
		fillMatrix.createGradientBox(_currentProgressWidth, _progressBarHeight, Math.PI / 2, 0, 0);
		
		var lightColor = FlxColor.fromRGBFloat(
			Math.min(1.0, barColor.redFloat + 0.2),
			Math.min(1.0, barColor.greenFloat + 0.2),
			Math.min(1.0, barColor.blueFloat + 0.2)
		);
		
		_progressFill.graphics.beginGradientFill(
			GradientType.LINEAR,
			[lightColor, barColor],
			[1.0, 1.0],
			[0, 255],
			fillMatrix
		);
		
		_progressFill.graphics.drawRoundRect(35, 28, _currentProgressWidth, _progressBarHeight, 6, 6);
		_progressFill.graphics.endFill();
		
		var highlightMatrix = new Matrix();
		highlightMatrix.createGradientBox(_currentProgressWidth, _progressBarHeight / 2, Math.PI / 2, 0, 0);
		_progressFill.graphics.beginGradientFill(
			GradientType.LINEAR,
			[FlxColor.WHITE, FlxColor.TRANSPARENT],
			[0.3, 0.0],
			[0, 255],
			highlightMatrix
		);
		_progressFill.graphics.drawRoundRect(35, 28, _currentProgressWidth, _progressBarHeight / 2, 6, 6);
		_progressFill.graphics.endFill();
	}

	function getVolumeColor(volume:Float):FlxColor
	{
		if (volume <= 0.25)
			return FlxColor.fromString('#CD5C5C');
		else if (volume <= 0.7)
			return FlxColor.fromString('#CCCCFF');
		else if (volume < 0.9)
			return FlxColor.fromString('#87CEFA');
		else if (volume < 1.0)
		{
			var lightBlueColor = FlxColor.fromString('#87CEFA');
			var goldColor = FlxColor.fromString('#FFD700');
			var transition = (volume - 0.9) / 0.1;
			return interpolateColor(lightBlueColor, goldColor, transition);
		}
		else
			return FlxColor.fromString('#FFD700');
	}

	function areColorsEqual(color1:FlxColor, color2:FlxColor):Bool
	{
		return Math.abs(color1.redFloat - color2.redFloat) < 0.01 &&
			   Math.abs(color1.greenFloat - color2.greenFloat) < 0.01 &&
			   Math.abs(color1.blueFloat - color2.blueFloat) < 0.01;
	}

	function interpolateColor(fromColor:FlxColor, toColor:FlxColor, factor:Float):FlxColor
	{
		var red = fromColor.redFloat + (toColor.redFloat - fromColor.redFloat) * factor;
		var green = fromColor.greenFloat + (toColor.greenFloat - fromColor.greenFloat) * factor;
		var blue = fromColor.blueFloat + (toColor.blueFloat - fromColor.blueFloat) * factor;
		
		return FlxColor.fromRGBFloat(red, green, blue);
	}

	function updateVolumeIcon(volume:Float):Void
	{
		if (_volumeIcon != null)
		{
			_volumeIcon.alpha = 1.0;
			_volumeIcon.transform.colorTransform = new ColorTransform(
				1.0, 1.0, 1.0, 1.0, 0, 0, 0, 0
			);
		}
	}
}
