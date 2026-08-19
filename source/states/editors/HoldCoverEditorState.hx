package states.editors;

import haxe.Json;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import openfl.utils.AssetType;
import sys.io.File;
import objects.Note;
import objects.NoteHoldCover;
import objects.NoteHoldCover.HoldCoverAnim;
import objects.NoteHoldCover.HoldCoverConfig;
import objects.StrumNote;

/**
 * Hold Cover 编辑器（配置兼容 NoteSplash 风格）：
 *  - Properties 页：Base 路径、Scale、Save、Template、Reload Image
 *  - Animations 页：Color 下拉（四色）、Start/Hold/End 前缀、FPS、Offsets（方向键微调）
 * 保存为每个颜色独立的 JSON：assets/shared/images/holdCover/holdCover{Color}{后缀}.json
 */
class HoldCoverEditorState extends MusicBeatState
{
	var UI_box:PsychUIBox;

	var covers:FlxTypedGroup<NoteHoldCover> = new FlxTypedGroup<NoteHoldCover>();
	var strums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();

	var imageSkin:String = 'holdCover/holdCover';
	var _config:HoldCoverConfig;

	var _curColorIndex:Int = 0;
	var errorText:FlxText;
	var curText:FlxText;

	// 输入控件
	var imageInputText:PsychUIInputText;
	var scaleNumericStepper:PsychUINumericStepper;
	var startInput:PsychUIInputText;
	var holdInput:PsychUIInputText;
	var endInput:PsychUIInputText;
	var fpsStepper:PsychUINumericStepper;
	var colorDropdown:PsychUIDropDownMenu;
	var arrowKeysOption:PsychUICheckBox;

	var copiedOffset:Array<Float> = [0, 0];

	public static function getHoldCoverPostfix():String
	{
		var skinName:String = ClientPrefs.data.holdCoverSkin.trim();
		if (skinName != ClientPrefs.defaultData.holdCoverSkin && skinName.length > 0)
			return '-' + skinName.toLowerCase().replace(' ', '-');
		return '';
	}

	function currentColor():String
		return NoteHoldCover.COVER_COLORS[_curColorIndex];

	function currentAnim():HoldCoverAnim
		return _config.anims.get(currentColor());

	function colorLabel(color:String):String
	{
		return switch (color)
		{
			case 'Purple': Language.get('hold_cover_color_purple');
			case 'Blue':   Language.get('hold_cover_color_blue');
			case 'Green':  Language.get('hold_cover_color_green');
			case 'Red':    Language.get('hold_cover_color_red');
			default:       color;
		}
	}

	function uilabel(x:Float, y:Float, ?w:Int, s:String):FlxText
	{
		return new FlxText(x, y, w == null ? 0 : w, s, 12).setFormat(Paths.font(Language.get('uitab_font')), 12, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
	}

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.fromRGB(110, 90, 145);
		FlxG.mouse.visible = true;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Hold Cover Editor", null);
		#end

		_config = {scale: 1, anims: new Map()};
		for (color in NoteHoldCover.COVER_COLORS)
			_config.anims.set(color, loadColorConfig(color));
		var first = _config.anims.get(NoteHoldCover.COVER_COLORS[0]);
		if (first != null && first.scale != null) _config.scale = first.scale;

		// 4 个 strum + 各自的 Hold Cover 预览
		for (i in 0...NoteHoldCover.COVER_COLORS.length)
		{
			var color = NoteHoldCover.COVER_COLORS[i];
			var strumX = 120 + (640 / NoteHoldCover.COVER_COLORS.length) * i;
			var strumY = 250;
			var strum:StrumNote = new StrumNote(strumX, strumY, i, 0);
			strums.add(strum);

			var path:String = Note.resolveSkinPath(imageSkin + color + getHoldCoverPostfix(), true);
			if (Paths.fileExists('images/$path.png', AssetType.IMAGE))
			{
				try
				{
					var cover:NoteHoldCover = new NoteHoldCover(strum, i, NoteHoldCover.createDefaultConfig(color));
					cover.freezeHold = true;
					covers.add(cover);
				}
				catch (e:Dynamic) {}
			}
		}
		add(strums);
		add(covers);

		for (c in covers)
			applyConfigToCover(c, c.coverColor);

		// UI
		UI_box = new PsychUIBox(0, 0, 0, 0, [Language.get('hold_cover_tab_props'), Language.get('hold_cover_tab_anims')]);
		UI_box.canMove = UI_box.canMinimize = false;
		UI_box.resize(320, 240);
		UI_box.x = FlxG.width - UI_box.width - 10;
		UI_box.y = 20;
		UI_box.scrollFactor.set();
		add(UI_box);

		addPropertiesTab();
		addAnimationsTab();

		errorText = new FlxText(0, FlxG.height - 30, 0, '', 14);
		errorText.setFormat(Paths.font(Language.get('uitab_font')), 14, FlxColor.RED, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorText.scrollFactor.set();
		add(errorText);

		curText = new FlxText(0, 40, 0, '', 14);
		curText.setFormat(Paths.font(Language.get('uitab_font')), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		curText.scrollFactor.set();
		add(curText);
	}

	function loadColorConfig(color:String):HoldCoverAnim
	{
		var jsonPath:String = imageSkin + color + getHoldCoverPostfix();
		if (Paths.fileExists('images/$jsonPath.json', AssetType.TEXT))
		{
			try
			{
				var raw = Json.parse(Paths.getTextFromFile('images/$jsonPath.json'));
				return NoteHoldCover.parseAnim(raw);
			}
			catch (e:Dynamic) {}
		}
		return {start: 'holdCoverStart' + color, hold: 'holdCover' + color, end: 'holdCoverEnd' + color, fps: 24, offsets: [0, 0], scale: 1};
	}

	function applyConfigToCover(cover:NoteHoldCover, color:String)
	{
		cover.config.scale = _config.scale;
		cover.config.anims.set(color, _config.anims.get(color));
		cover.reloadAnims();
		cover.freezeHold = true;
		cover.startHold();
	}

	function addPropertiesTab()
	{
		var ui = UI_box.getTab(Language.get('hold_cover_tab_props')).menu;

		ui.add(uilabel(20, 10, 120, Language.get('hold_cover_base_path')));
		imageInputText = new PsychUIInputText(95, 10, 180, imageSkin, 12);
		imageInputText.onChange = function(old:String, cur:String)
		{
			imageSkin = cur;
			reloadAllImages();
		};
		ui.add(imageInputText);

		var reloadButton:PsychUIButton = new PsychUIButton(280, 6.8, Language.get('hold_cover_reload_image'), function()
		{
			reloadAllImages();
		});
		ui.add(reloadButton);

		ui.add(uilabel(20, 40, 120, Language.get('hold_cover_scale')));
		scaleNumericStepper = new PsychUINumericStepper(20, 57.5, 0.1, _config.scale, 0, 4, 2, 60);
		scaleNumericStepper.onValueChange = () ->
		{
			_config.scale = scaleNumericStepper.value;
			for (c in covers) applyConfigToCover(c, c.coverColor);
		};
		ui.add(scaleNumericStepper);

		var saveButton:PsychUIButton = new PsychUIButton(20, 130, Language.get('hold_cover_save'), function()
		{
			saveCFG();
		});
		ui.add(saveButton);

		var templateButton:PsychUIButton = new PsychUIButton(110, 130, Language.get('hold_cover_template'), function()
		{
			saveTemplate();
		});
		ui.add(templateButton);

		var helpButton:PsychUIButton = new PsychUIButton(210, 130, Language.get('hold_cover_help'), function()
		{
			openSubState(new HoldCoverEditorHelp());
		});
		ui.add(helpButton);

		var exitButton:PsychUIButton = new PsychUIButton(210, 6.8, Language.get('hold_cover_exit'), function()
		{
			exitState();
		});
		ui.add(exitButton);
	}

	function exitState():Void
	{
		MusicBeatState.switchState(new MasterEditorMenu());
	}

	function addAnimationsTab()
	{
		var ui = UI_box.getTab(Language.get('hold_cover_tab_anims')).menu;

		ui.add(uilabel(20, 10, 60, Language.get('hold_cover_color')));
		var colorOptions:Array<String> = [for (c in NoteHoldCover.COVER_COLORS) colorLabel(c)];
		colorDropdown = new PsychUIDropDownMenu(70, 8, colorOptions, function(id:Int, name:String)
		{
			_curColorIndex = id;
			refreshAnimInputs();
		});
		colorDropdown.selectedLabel = colorLabel(NoteHoldCover.COVER_COLORS[_curColorIndex]);
		ui.add(colorDropdown);

		ui.add(uilabel(20, 45, 60, Language.get('hold_cover_start')));
		startInput = new PsychUIInputText(70, 45, 160, '', 12);
		startInput.onChange = function(old:String, cur:String)
		{
			if (currentAnim() != null) { currentAnim().start = cur; applyForCurrentColor(); }
		};
		ui.add(startInput);

		ui.add(uilabel(20, 75, 60, Language.get('hold_cover_hold')));
		holdInput = new PsychUIInputText(70, 75, 160, '', 12);
		holdInput.onChange = function(old:String, cur:String)
		{
			if (currentAnim() != null) { currentAnim().hold = cur; applyForCurrentColor(); }
		};
		ui.add(holdInput);

		ui.add(uilabel(20, 105, 60, Language.get('hold_cover_end')));
		endInput = new PsychUIInputText(70, 105, 160, '', 12);
		endInput.onChange = function(old:String, cur:String)
		{
			if (currentAnim() != null) { currentAnim().end = cur; applyForCurrentColor(); }
		};
		ui.add(endInput);

		ui.add(uilabel(20, 140, 60, Language.get('hold_cover_fps')));
		fpsStepper = new PsychUINumericStepper(60, 140, 1, 24, 1, 60, 0, 60);
		fpsStepper.onValueChange = () ->
		{
			if (currentAnim() != null) { currentAnim().fps = Std.int(fpsStepper.value); applyForCurrentColor(); }
		};
		ui.add(fpsStepper);

		arrowKeysOption = new PsychUICheckBox(20, 175, Language.get('hold_cover_use_arrow_keys'), 200, function()
		{
			// 仅作为开关；偏移微调在 update() 中通过 FlxG.keys 处理，
			// 不再向 FlxG.stage 注册监听器，避免 state 重建后崩溃。
		});
		ui.add(arrowKeysOption);

		refreshAnimInputs();
	}

	function refreshAnimInputs():Void
	{
		var anim = currentAnim();
		if (anim == null) return;
		startInput.text = (anim.start != null) ? anim.start : '';
		holdInput.text = (anim.hold != null) ? anim.hold : '';
		endInput.text = (anim.end != null) ? anim.end : '';
		fpsStepper.value = (anim.fps != null) ? anim.fps : 24;
	}

	function applyForCurrentColor():Void
	{
		for (c in covers)
			if (c.coverColor == currentColor())
				applyConfigToCover(c, currentColor());
	}

	function reloadAllImages():Void
	{
		for (i in 0...NoteHoldCover.COVER_COLORS.length)
		{
			var color = NoteHoldCover.COVER_COLORS[i];
			_config.anims.set(color, loadColorConfig(color));

			var path:String = Note.resolveSkinPath(imageSkin + color + getHoldCoverPostfix(), true);
			for (c in covers)
			{
				if (c.coverColor == color)
				{
					if (Paths.fileExists('images/$path.png', AssetType.IMAGE))
						c.reloadAtlas(path);
					applyConfigToCover(c, color);
				}
			}
		}
		refreshAnimInputs();
	}

	function saveCFG():Void
	{
		for (color in NoteHoldCover.COVER_COLORS)
		{
			var anim = _config.anims.get(color);
			var obj:Dynamic = {
				scale: _config.scale,
				start: anim.start,
				hold: anim.hold,
				end: anim.end,
				fps: anim.fps,
				offsets: anim.offsets
			};
			var fileName:String = 'holdCover' + color + getHoldCoverPostfix();
			var data:String = Json.stringify(obj, "\t");
			#if mobile
			StorageUtil.saveContent(fileName + '.json', data);
			#else
			File.saveContent('assets/shared/images/holdCover/' + fileName + '.json', data);
			#end
		}
		showError(Language.get('hold_cover_saved_cfg'), FlxColor.GREEN);
	}

	function saveTemplate():Void
	{
		var obj:Dynamic = {
			scale: 1,
			start: 'holdCoverStart{COLOR}',
			hold: 'holdCover{COLOR}',
			end: 'holdCoverEnd{COLOR}',
			fps: 24,
			offsets: [0, 0]
		};
		var data:String = Json.stringify(obj, "\t");
		#if mobile
		StorageUtil.saveContent('holdCoverBlue.json', data);
		#else
		File.saveContent('assets/shared/images/holdCover/template.json', data);
		#end
		showError(Language.get('hold_cover_saved_template'), FlxColor.GREEN);
	}

	function showError(msg:String, color:FlxColor):Void
	{
		errorText.color = color;
		errorText.text = msg;
		errorText.alpha = 1;
		FlxTween.cancelTweensOf(errorText);
		FlxTween.tween(errorText, {alpha: 0}, 1, {startDelay: 2});
	}

	// ---- 方向键微调 Offsets ----
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var blockInput:Bool = PsychUIInputText.focusOn != null;
		if (!blockInput && (controls.BACK || FlxG.keys.justPressed.ESCAPE))
		{
			exitState();
			return;
		}

		errorText.x = FlxG.width - errorText.width - 5;

		curText.text = Language.get('hold_cover_copied_offsets', [Std.string(copiedOffset).replace(', ', ', ')]);
		curText.text += Language.get('hold_cover_current_color', [colorLabel(currentColor())]);
		if (currentAnim() != null && currentAnim().offsets != null)
			curText.text += ' (${Std.string(currentAnim().offsets).replace(', ', ', ')})';

		if (arrowKeysOption.checked && !blockInput && currentAnim() != null && currentAnim().offsets != null)
		{
			var anim = currentAnim();
			var changed:Bool = false;
			if (FlxG.keys.pressed.LEFT) { anim.offsets[0] -= 1; changed = true; }
			else if (FlxG.keys.pressed.RIGHT) { anim.offsets[0] += 1; changed = true; }
			if (FlxG.keys.pressed.UP) { anim.offsets[1] -= 1; changed = true; }
			else if (FlxG.keys.pressed.DOWN) { anim.offsets[1] += 1; changed = true; }

			if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C)
				copiedOffset = anim.offsets.copy();

			if (changed)
				for (c in covers)
					if (c.coverColor == currentColor())
						c.setOffsets(anim.offsets);
		}
	}
}

class HoldCoverEditorHelp extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var helpText:FlxText;

	override function create()
	{
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.85;
		add(bg);

		helpText = new FlxText(40, 40, FlxG.width - 80,
			Language.get('hold_cover_help_title') + "\n\n" +
			Language.get('hold_cover_help_p1') + "\n" +
			Language.get('hold_cover_help_p2') + "\n" +
			Language.get('hold_cover_help_p3') + "\n" +
			Language.get('hold_cover_help_p4') + "\n" +
			Language.get('hold_cover_help_p5') + "\n" +
			Language.get('hold_cover_help_p6') + "\n" +
			Language.get('hold_cover_help_p7') + "\n\n" +
			Language.get('hold_cover_help_p8') + "\n" +
			Language.get('hold_cover_help_close'), 14);
		helpText.setFormat(Paths.font(Language.get('uitab_font')), 14, FlxColor.WHITE, LEFT);
		add(helpText);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE || FlxG.mouse.justPressed)
			close();
	}
}
