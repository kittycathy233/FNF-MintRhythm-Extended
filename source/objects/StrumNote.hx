package objects;
import backend.InputFormatter;
import flixel.FlxBasic;
import backend.ExtraKeysHandler;

import backend.animation.PsychAnimationController;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;

class StrumNote extends FlxSprite
{
	public var rgbShader:RGBShaderReference;
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;
	public var direction:Float = 90;
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;
	public var trackedScale:Float = 0.7;
	private var player:Int;
	private var initialWidth:Float = 0;	
		
	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	public var useRGBShader:Bool = true;
	public function new(x:Float, y:Float, leData:Int, player:Int) {
		animation = new PsychAnimationController(this);

		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(leData));
		rgbShader.enabled = false;

		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;
		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;

		var mania = 3;
		if (PlayState.SONG != null) mania = PlayState.SONG.mania;

		var arrowRGBIndex = getIndex(mania, leData);

		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[arrowRGBIndex];

		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[arrowRGBIndex];

		@:bypassAccessor
		{
			rgbShader.r = arr[0];
			rgbShader.g = arr[1];
			rgbShader.b = arr[2];
		}
		/*var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[leData];
		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[leData];
		
		if(leData <= arr.length)
		{
			@:bypassAccessor
			{
				rgbShader.r = arr[0];
				rgbShader.g = arr[1];
				rgbShader.b = arr[2];
			}
		}*/

		noteData = leData;
		this.player = player;
		this.noteData = leData;
		this.ID = noteData;
		super(x, y);

		var skin:String = null;
		if(PlayState.SONG != null && PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) skin = PlayState.SONG.arrowSkin;
		else skin = Note.defaultNoteSkin;

		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if(Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

		texture = skin; //Load texture and anims
		scrollFactor.set();
		playAnim('static');
	}

	public function reloadNote()
	{
		var lastAnim:String = null;
		if(animation.curAnim != null) lastAnim = animation.curAnim.name;

		if(PlayState.isPixelStage)
		{
			loadGraphic(Paths.image('pixelUI/' + texture));
			width = width / 6;
			height = height / 5;
			loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));

			antialiasing = false;
			/*setGraphicSize(Std.int(width * PlayState.daPixelZoom));

			animation.add('green', [6]);
			animation.add('red', [7]);
			animation.add('blue', [5]);
			animation.add('purple', [4]);
			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.add('static', [0]);
					animation.add('pressed', [4, 8], 12, false);
					animation.add('confirm', [12, 16], 24, false);
				case 1:
					animation.add('static', [1]);
					animation.add('pressed', [5, 9], 12, false);
					animation.add('confirm', [13, 17], 24, false);
				case 2:
					animation.add('static', [2]);
					animation.add('pressed', [6, 10], 12, false);
					animation.add('confirm', [14, 18], 12, false);
				case 3:
					animation.add('static', [3]);
					animation.add('pressed', [7, 11], 12, false);
					animation.add('confirm', [15, 19], 24, false);
			}*/

			initialWidth = width;
			//trace(initialWidth);

			setGraphicSize(width * PlayState.daPixelZoom);

			var mania = 3;
			if (PlayState.SONG != null) mania = PlayState.SONG.mania;

			var noteAnimInt = getAnimSet(getIndex(mania, noteData)).pixel;

			animation.add('circle', [11]);
			animation.add('rombus', [10]);
			animation.add('red', [9]);
			animation.add('green', [8]);
			animation.add('blue', [7]);
			animation.add('purple', [6]);

			animation.add('static', [noteAnimInt]);
			animation.add('pressed', [noteAnimInt + 6, noteAnimInt + 12], 12, false);
			animation.add('confirm', [noteAnimInt + 18, noteAnimInt + 24], 24, false);

		}
		else
		{
			frames = Paths.getSparrowAtlas(texture);
			animation.addByPrefix('green', 'arrowUP');
			animation.addByPrefix('blue', 'arrowDOWN');
			animation.addByPrefix('purple', 'arrowLEFT');
			animation.addByPrefix('red', 'arrowRIGHT');

			/*antialiasing = ClientPrefs.data.antialiasing;
			setGraphicSize(Std.int(width * 0.7));

			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.addByPrefix('static', 'arrowLEFT');
					animation.addByPrefix('pressed', 'left press', 24, false);
					animation.addByPrefix('confirm', 'left confirm', 24, false);
				case 1:
					animation.addByPrefix('static', 'arrowDOWN');
					animation.addByPrefix('pressed', 'down press', 24, false);
					animation.addByPrefix('confirm', 'down confirm', 24, false);
				case 2:
					animation.addByPrefix('static', 'arrowUP');
					animation.addByPrefix('pressed', 'up press', 24, false);
					animation.addByPrefix('confirm', 'up confirm', 24, false);
				case 3:
					animation.addByPrefix('static', 'arrowRIGHT');
					animation.addByPrefix('pressed', 'right press', 24, false);
					animation.addByPrefix('confirm', 'right confirm', 24, false);
			}*/

			animation.addByPrefix('rombus', 'arrowROMBUS');
			animation.addByPrefix('circle', 'arrowCIRCLE');
			initialWidth = width;

			antialiasing = ClientPrefs.data.antialiasing;
			setGraphicSize(width * trackedScale);

			var mania = 3;
			if (PlayState.SONG != null) mania = PlayState.SONG.mania;

			animation.addByPrefix('static', 'arrow${getAnimSet(getIndex(mania, noteData)).strum}');
			animation.addByPrefix('pressed', '${getAnimSet(getIndex(mania, noteData)).anim} press', 24, false);
			animation.addByPrefix('confirm', '${getAnimSet(getIndex(mania, noteData)).anim} confirm', 24, false);

		}
		updateHitbox();

		if(lastAnim != null)
		{
			playAnim(lastAnim, true);
		}
	}
public function retryBound() {
		trackedScale = trackedScale * 0.85;
		setGraphicSize(initialWidth * (trackedScale * (PlayState.isPixelStage ? PlayState.daPixelZoom /** (1/ExtraKeysHandler.instance.data.pixelScales[PlayState.SONG.mania])) */: 1)));
		trace(trackedScale);
		updateHitbox();
		playerPosition();
	}
	
	public function playerPosition()
	{
var padding:Float = 0;
		var minPaddingStartThresh:Int = 4;
		//if (PlayState.isPixelStage) minPaddingStartThresh = 3;
		if (PlayState.SONG.mania > minPaddingStartThresh) {
			padding = 4 * (PlayState.SONG.mania - minPaddingStartThresh);
			if (padding > 8) padding = 8;
		}
		//trace(padding);

		// x = StrumBoundaries.getMiddlePoint().x;
		// x += ((Note.swagWidthUnscaled * trackedScale) - padding) * (-((PlayState.SONG.mania + 1) / 2) + noteData);
		// x += 25;
		// x += ((FlxG.width / 2) * player);
		ID = noteData;

		centerStrum(minPaddingStartThresh, padding);
	}

	/**
	 * Please refrain from asking me what happens here
	 * @param maniaThresh I don't know
	 * @param padding I don't know
	 */
	public function centerStrum(maniaThresh:Int, padding:Float) {
		var sWidth = /*(PlayState.isPixelStage && PlayState.SONG.mania > maniaThresh) ? (180 + ((10 + (5 * (PlayState.SONG.mania - maniaThresh))) * (PlayState.SONG.mania - maniaThresh))) : */ Note.swagWidthUnscaled;
		if (!ClientPrefs.data.middleScroll) {
			x = player == 0 ? 320 : 960;
			x += ((sWidth * trackedScale) - padding) * (-((PlayState.SONG.mania+1) / 2) + noteData);
		} else {
			x = player == 0 ? 320 : 640;
			if (player == 0) {
				if (noteData > Math.floor((PlayState.SONG.mania / 2))) x = 960;
			}
			x += ((sWidth * trackedScale) - padding) * (-((PlayState.SONG.mania+1) / 2) + noteData);
		}
		//trace(padding);	
		}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		if(animation.curAnim != null)
		{
			centerOffsets();
			centerOrigin();
		}
		if(useRGBShader) rgbShader.enabled = (animation.curAnim != null && animation.curAnim.name != 'static');
	}





	public function getIndex(mania:Int, note:Int) {
		return ExtraKeysHandler.instance.data.keys[mania].notes[note];
	}

	public function getAnimSet(index:Int) {
		return ExtraKeysHandler.instance.data.animations[index];
	}
}

class StrumBoundaries {
	public static var minBoundaryOpponent:FlxPoint = new FlxPoint(30, 50);
	public static var maxBoundaryOpponent:FlxPoint = new FlxPoint(630, 160);

	public static function getMiddlePoint():FlxPoint {
		return new FlxPoint(Std.int(getBoundaryWidth().x/2),Std.int(getBoundaryWidth().y/2));
	}

	public static function getBoundaryWidth():FlxPoint {
		return new FlxPoint(Std.int((maxBoundaryOpponent.x - minBoundaryOpponent.x)),Std.int((maxBoundaryOpponent.y - minBoundaryOpponent.y)));
	}
}



class KeybindShowcase extends FlxTypedGroup<FlxBasic> {
	public var background:FlxSprite;
	public var keyText:FlxText;
	public var keyCodes:Array<Int>;
	public dynamic function onComplete():Void {}

	public function new(x:Float,y:Float,keyCodes:Array<Int>, camera:FlxCamera, strumHalved:Float, mania:Int) {
		super();

		this.keyCodes = keyCodes;

		var xOffset = x + strumHalved;

		var size = 20 - (mania - 3);

		keyText = new FlxText(xOffset + 4,y + 4, InputFormatter.getKeyName(keyCodes[0]));
		keyText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		keyText.x -= keyText.width / 2;
		xOffset = keyText.x;

		background = new FlxSprite(xOffset-4,y);
		background.makeGraphic(Std.int(keyText.width + 8), Std.int(keyText.height + 8), 0xFF000000);
		background.alpha = 0.5;

		add(background);
		add(keyText);

		background.cameras = [camera];
		keyText.cameras = [camera];

		new FlxTimer().start(2, function(tmr:FlxTimer) {
			FlxTween.tween(keyText, {alpha: 0}, 0.5, {ease: FlxEase.linear, onComplete: function(t) {
				if (keyCodes.length > 1) {
					keyText.text = InputFormatter.getKeyName(keyCodes[1]);
				} else {
					keyText.text = '---';
				}

				FlxTween.tween(keyText, {alpha: 1}, 0.5);

				keyText.x = x + strumHalved + 4;
				keyText.x -= keyText.width / 2;
				xOffset = keyText.x;
				background.x = xOffset - 4;
				background.makeGraphic(Std.int(keyText.width + 8), Std.int(keyText.height + 8), 0xFF000000);
				new FlxTimer().start(2.5, function(tmr:FlxTimer) {
					FlxTween.tween(keyText, {alpha: 0}, 0.5, {ease: FlxEase.linear, onComplete: function(t) {
						onComplete();
					}});
				});
			}});
		});
	}
}