package options;

import flixel.addons.display.FlxBackdrop;
import backend.CoolUtil;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import objects.Note;
import shaders.ColorSwap;

using StringTools;

/**
 * Legacy Psych Engine v0.6.3 arrow color editor.
 *
 * Shows the 4 note directions vertically, each with three integer columns
 * (Hue / Saturation / Brightness) that SHIFT the note texture's colors via the
 * ColorSwap HSV shader. Up/Down selects a note, Left/Right selects H/S/B,
 * Accept enters edit mode, Left/Right changes the value, Reset zeroes it.
 *
 * Edits write straight into ClientPrefs.data.arrowHSV AND the shared
 * Note.globalColorSwapShaders so they reflect live in gameplay (mirrors how the
 * RGB NotesColorSubState uses Note.globalRgbShaders).
**/
class NotesColorSubStateLegacy extends MusicBeatSubstate
{
	private static var curSelected:Int = 0;
	private static var typeSelected:Int = 0;
	private var grpNumbers:FlxTypedGroup<Alphabet>;
	private var grpNotes:FlxTypedGroup<FlxSprite>;
	private var shaderArray:Array<ColorSwap> = [];
	var curValue:Float = 0;
	var holdTime:Float = 0;
	var nextAccept:Int = 5;

	var blackBG:FlxSprite;
	var hsbTexts:Array<Alphabet> = [];
	var tipTxt:FlxText;

	var posX = 230;

	public function new() {
		super();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Note Colors Menu (Legacy)", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFEA71FD;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		var grid:FlxBackdrop = new FlxBackdrop(CoolUtil.getCachedGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.velocity.set(40, 40);
		grid.alpha = 0;
		FlxTween.tween(grid, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		add(grid);

		blackBG = new FlxSprite(posX - 25).makeGraphic(870, 200, FlxColor.BLACK);
		blackBG.alpha = 0.4;
		add(blackBG);

		grpNotes = new FlxTypedGroup<FlxSprite>();
		add(grpNotes);
		grpNumbers = new FlxTypedGroup<Alphabet>();
		add(grpNumbers);

		Note.globalColorSwapShaders = [];
		for (i in 0...ClientPrefs.data.arrowHSV.length) {
			var yPos:Float = (165 * i) + 35;
			for (j in 0...3) {
				var optionText:Alphabet = new Alphabet(posX + (225 * j) + 250, yPos + 60, Std.string(ClientPrefs.data.arrowHSV[i][j]), true);
				grpNumbers.add(optionText);
			}

		// 用 Note（落下的音符）复用与 PlayState 游玩完全一致皮肤解析（noteSkin 后缀、
		// HSV 的 hsv/ 目录、RGB/HSV 着色器、模组上下文），保持“落键”外观而非
		// StrumNote 的受体样式，让编辑器预览与游玩一致。
		var note:Note = new Note(0, i, null, false, true);
		note.x = posX;
		note.y = yPos;
		note.scale.set(0.7, 0.7);
		grpNotes.add(note);

		// HSV 模式：Note 已挂载与游玩同一个全局 ColorSwap（reloadNote 时挂上），
		// 直接引用即可让 arrowHSV 编辑实时生效；RGB 模式编辑 HSV 无效，用独立
		// ColorSwap 占位以免 shaderArray 出现空引用。
		if (note.colorSwap != null) shaderArray.push(note.colorSwap);
		else shaderArray.push(Note.initializeGlobalColorSwapShader(i));
		}

		// 三个 H/S/B 列标题，分别对齐到对应的数值列（x 与 grpNumbers 一致），
		// 避免原先单个居中字符串“Hue    Saturation  Brightness”整体偏移、不对应各列。
		var hsbLabels:Array<String> = ["Hue", "Saturation", "Brightness"];
		for (j in 0...3) {
			var label:Alphabet = new Alphabet(posX + (225 * j) + 250, 0, hsbLabels[j], false);
			label.scaleX = 0.6;
			label.scaleY = 0.6;
			add(label);
			hsbTexts.push(label);
		}

		// Tip text
		var tipX:Float = 20;
		var tipY:Float = controls.mobileC ? 0 : FlxG.height - 40;
		var reset:String = controls.mobileC ? "C" : "RESET";
		var tip:FlxText = new FlxText(tipX, tipY, 0, LanguageBasic.getPhrase('note_colors_legacy_tip', 'Up/Down: Note  -  Left/Right: H/S/B  -  Accept: Edit  -  {1}: Reset', [reset]), 16);
		tip.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tip.borderSize = 2;
		add(tip);
		tipTxt = tip;

		changeSelection();

		addTouchPad('LEFT_FULL', 'A_B_C');
		addTouchPadCamera();
		controls.isInSubstate = true;
	}

	var changingNote:Bool = false;
	override function update(elapsed:Float) {
		var resetPressed:Bool = (touchPad != null && touchPad.buttonC.justPressed) || controls.RESET;

		if(changingNote) {
			if(holdTime < 0.5) {
				if(controls.UI_LEFT_P) {
					updateValue(-1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				} else if(controls.UI_RIGHT_P) {
					updateValue(1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				} else if(resetPressed) {
					resetValue(curSelected, typeSelected);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
				if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					holdTime = 0;
				} else if(controls.UI_LEFT || controls.UI_RIGHT) {
					holdTime += elapsed;
				}
			} else {
				var add:Float = 90;
				switch(typeSelected) {
					case 1 | 2: add = 50;
				}
				if(controls.UI_LEFT) {
					updateValue(elapsed * -add);
				} else if(controls.UI_RIGHT) {
					updateValue(elapsed * add);
				}
				if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					FlxG.sound.play(Paths.sound('scrollMenu'));
					holdTime = 0;
				}
			}
		} else {
			if (controls.UI_UP_P) {
				changeSelection(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_DOWN_P) {
				changeSelection(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_LEFT_P) {
				changeType(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_RIGHT_P) {
				changeType(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if(resetPressed) {
				for (i in 0...3) {
					resetValue(curSelected, i);
				}
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.ACCEPT && nextAccept <= 0) {
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changingNote = true;
				holdTime = 0;
				for (i in 0...grpNumbers.length) {
					var item = grpNumbers.members[i];
					item.alpha = 0;
					if ((curSelected * 3) + typeSelected == i) {
						item.alpha = 1;
					}
				}
				for (i in 0...grpNotes.length) {
					var item = grpNotes.members[i];
					item.alpha = 0;
					if (curSelected == i) {
						item.alpha = 1;
					}
				}
				super.update(elapsed);
				return;
			}
		}

		if (controls.BACK || (changingNote && controls.ACCEPT)) {
			if(!changingNote) {
				close();
			} else {
				changeSelection();
			}
			changingNote = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = ClientPrefs.data.arrowHSV.length-1;
		if (curSelected >= ClientPrefs.data.arrowHSV.length)
			curSelected = 0;

		curValue = ClientPrefs.data.arrowHSV[curSelected][typeSelected];
		updateValue();

		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i) {
				item.alpha = 1;
			}
		}
		for (i in 0...grpNotes.length) {
			var item = grpNotes.members[i];
			item.alpha = 0.6;
			item.scale.set(0.75, 0.75);
			if (curSelected == i) {
				item.alpha = 1;
				item.scale.set(1, 1);
				for (label in hsbTexts) label.y = item.y - 70;
				blackBG.y = item.y - 20;
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function changeType(change:Int = 0) {
		typeSelected += change;
		if (typeSelected < 0)
			typeSelected = 2;
		if (typeSelected > 2)
			typeSelected = 0;

		curValue = ClientPrefs.data.arrowHSV[curSelected][typeSelected];
		updateValue();

		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i) {
				item.alpha = 1;
			}
		}
	}

	function resetValue(selected:Int, type:Int) {
		curValue = 0;
		ClientPrefs.data.arrowHSV[selected][type] = 0;
		switch(type) {
			case 0: shaderArray[selected].hue = 0;
			case 1: shaderArray[selected].saturation = 0;
			case 2: shaderArray[selected].brightness = 0;
		}

		var item = grpNumbers.members[(selected * 3) + type];
		item.text = '0';

		var add = (40 * (item.letters.length - 1)) / 2;
		for (letter in item.letters)
		{
			letter.offset.x += add;
		}
	}
	function updateValue(change:Float = 0) {
		curValue += change;
		var roundedValue:Int = Math.round(curValue);
		var max:Float = 180;
		switch(typeSelected) {
			case 1 | 2: max = 100;
		}

		if(roundedValue < -max) {
			curValue = -max;
		} else if(roundedValue > max) {
			curValue = max;
		}
		roundedValue = Math.round(curValue);
		ClientPrefs.data.arrowHSV[curSelected][typeSelected] = roundedValue;

		switch(typeSelected) {
			case 0: shaderArray[curSelected].hue = roundedValue / 360;
			case 1: shaderArray[curSelected].saturation = roundedValue / 100;
			case 2: shaderArray[curSelected].brightness = roundedValue / 100;
		}

		var item = grpNumbers.members[(curSelected * 3) + typeSelected];
		item.text = Std.string(roundedValue);

		var add = (40 * (item.letters.length - 1)) / 2;
		for (letter in item.letters)
		{
			letter.offset.x += add;
			if(roundedValue < 0) letter.offset.x += 10;
		}
	}

	override function destroy()
	{
		Note.globalColorSwapShaders = [];
		controls.isInSubstate = false;
		super.destroy();
	}
}
