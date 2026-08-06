package objects;

import backend.Conductor;
import backend.animation.PsychAnimationController;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;
import shaders.ColorSwap;

class StrumNote extends FlxSprite
{
	public var rgbShader:RGBShaderReference;
	public var colorSwap:ColorSwap;
	public var resetAnim:Float = 0;
	public var holdConfirmActive:Bool = false;
	private var noteData:Int = 0;
	// direction 为角度（默认 90，即向上）。缓存 cos/sin 避免每个流动音符每帧各算一次 Math.cos/sin
	// （安卓 HXCPP 上走 C 库调用，高密度谱下数千次/帧）。
	public var direction(default, set):Float = 90;
	public var dirCos:Float = 0; // cos(90°)=0，缓存供流动音符快速路径读取
	public var dirSin:Float = 1; // sin(90°)=1，缓存供流动音符快速路径读取
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;
	private var player:Int;

	private function set_direction(value:Float):Float {
		if (direction != value) {
			direction = value;
			var rad:Float = value * Math.PI / 180.0;
			dirCos = Math.cos(rad);
			dirSin = Math.sin(rad);
		}
		return value;
	}
	
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

		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(Note.styleIndex(leData)));
		rgbShader.enabled = false;
		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;
		
		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[Note.styleIndex(leData)];
		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[Note.styleIndex(leData)];
		
		if(arr != null && arr.length >= 3)
		{
			@:bypassAccessor
			{
				rgbShader.r = arr[0];
				rgbShader.g = arr[1];
				rgbShader.b = arr[2];
			}
		}

		// Legacy HSV path: share the per-direction ColorSwap shader. The sprite
		// starts disabled (null shader = static); playAnim toggles it on/off.
		if(ClientPrefs.data.arrowColorMode == 'HSV') {
			colorSwap = Note.initializeGlobalColorSwapShader(Note.styleIndex(leData));
		}

		noteData = leData;
		this.player = player;
		this.noteData = leData;
		this.ID = noteData;
		super(x, y);

		var skin:String = null;
		if(PlayState.SONG != null && PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) skin = PlayState.SONG.arrowSkin;
		else skin = Note.defaultNoteSkin;

		// 与 Note.reloadNote 一致的皮肤解析：HSV 时优先走 hsv 目录，
		// 保证 StrumNote 与流动音符使用同一套箭头（而非默认/RGB 纹理）。
		// 像素舞台的箭头资源在 pixelUI/ 下，这里的自定义皮肤解析查的是非 pixelUI 路径，
		// 无意义；且 HSV 目录查找统一交给 resolveSkinPath（已支持 pixelUI/<folder>/hsv），
		// 故像素场景跳过此处，避免把含 hsv 的路径再次传入 resolveSkinPath 造成双重查找。
		var customSkin:String = skin + Note.getNoteSkinPostfix();
		var customExists:Bool = false;
		if (!PlayState.isPixelStage)
		{
			if(ClientPrefs.data.arrowColorMode == 'HSV')
			{
				var parts:Array<String> = customSkin.split('/');
				var filename:String = parts.pop();
				var folder:String = parts.join('/');
				customExists = Paths.fileExists('images/$folder/hsv/$filename.png', IMAGE) || Paths.fileExists('images/$customSkin.png', IMAGE);
			}
			else
				customExists = Paths.fileExists('images/$customSkin.png', IMAGE);

			if(!customExists) customSkin = skin;
		}
		skin = Note.getNoteSkinPath(customSkin);

		texture = skin; //Load texture and anims
		scrollFactor.set();
		playAnim('static');

		// 初始化方向三角函数缓存（与 direction setter 逻辑一致）
		var rad:Float = direction * Math.PI / 180.0;
		dirCos = Math.cos(rad);
		dirSin = Math.sin(rad);
	}

	public function reloadNote()
	{
		var lastAnim:String = null;
		if(animation.curAnim != null) lastAnim = animation.curAnim.name;

		if(PlayState.isPixelStage)
		{
			loadGraphic(Paths.image('pixelUI/' + texture));
			width = width / 4;
			height = height / 5;
			loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));

			antialiasing = false;
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));

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
			}
		}
		else
		{
			frames = Paths.getSparrowAtlas(texture);
			animation.addByPrefix('green', 'arrowUP');
			animation.addByPrefix('blue', 'arrowDOWN');
			animation.addByPrefix('purple', 'arrowLEFT');
			animation.addByPrefix('red', 'arrowRIGHT');

			antialiasing = ClientPrefs.data.antialiasing;
			setGraphicSize(Std.int(width * 0.7));

			// 多键：按 style 索引决定 strum 前缀（LEFT/DOWN/UP/RIGHT/ROMBUS/CIRCLE）。
			// 若当前皮肤缺少对应箭头帧，则回退到标准 UP 箭头，避免空帧（普通 strumnote）。
			var style:Int = Note.styleIndex(noteData);
			var strumName:String = backend.ExtraKeysHandler.instance.strumOf(style);
			if (!hasFrame('arrow' + strumName)) strumName = 'UP';

			var pressName:String = strumName.toLowerCase() + ' press';
			if (!hasFrame(pressName)) pressName = 'up press';
			var confirmName:String = strumName.toLowerCase() + ' confirm';
			if (!hasFrame(confirmName)) confirmName = 'up confirm';

			animation.addByPrefix('static', 'arrow' + strumName, 24, false);
			animation.addByPrefix('pressed', pressName, 24, false);
			animation.addByPrefix('confirm', confirmName, 24, false);
		}
		updateHitbox();

		if(lastAnim != null)
		{
			playAnim(lastAnim, true);
		}
	}

	// 判断皮肤图集中是否存在名为 `name + '0000'` 的帧（用于缺失动画的回退判断）
	function hasFrame(name:String):Bool
	{
		return frames != null && frames.getByName(name + '0000') != null;
	}

	public function playerPosition()
	{
		x += Note.swagWidth * noteData;
		x += 50;
		x += ((FlxG.width / 2) * player);
	}

	public var lastHoldAnimTime:Float = 0;
	public var isBotplayMode:Bool = false;
	
	override function update(elapsed:Float) {
		// player = 0 是对手箭头，始终能自动恢复
		// player = 1 且 isBotplayMode 是 true，也始终能自动恢复
		// 其他情况受 autoResetStrumAnim 控制
		if(ClientPrefs.data.autoResetStrumAnim || player == 0 || isBotplayMode) {
			if(holdConfirmActive && resetAnim <= 0) {
				// 检查是否很久没有处理 hold note 了
				lastHoldAnimTime += elapsed;
				// 动态获取当前时间的 BPM 信息，计算 2 个 16 分音符的时间（毫秒转秒）
				var currentBPMInfo = Conductor.getBPMFromSeconds(Conductor.songPosition);
				var timeoutSeconds = (currentBPMInfo.stepCrochet * 2) / 1000;
				if(lastHoldAnimTime >= timeoutSeconds) {
					// 超时了，自动重置到 static
					playAnim('static');
					holdConfirmActive = false;
				}
			}
			
			if(resetAnim > 0) {
				resetAnim -= elapsed;
				if(resetAnim <= 0) {
					playAnim('static');
					resetAnim = 0;
					holdConfirmActive = false;
				}
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
		// HSV mode: 始终挂载 ColorSwap 着色器（hue=0 时为恒等变换，仍显示箭头本色），
		// 与流动音符保持一致；修改 arrowHSV 后静态箭头也会同步变色。
		if(ClientPrefs.data.arrowColorMode == 'HSV' && colorSwap != null) {
			shader = colorSwap.shader;
		} else if(useRGBShader) {
			rgbShader.enabled = (animation.curAnim != null && animation.curAnim.name != 'static');
		}
	}
}
