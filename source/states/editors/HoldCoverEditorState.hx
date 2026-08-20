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
 * Hold Cover 编辑器（完整版，同时支持 HSV 与 RGB 皮肤）：
 *  - Properties 页：编辑目标切换(HSV/RGB)、Scale、disableRGB、Save、Template、Reload、Help、Exit
 *  - Animations 页：颜色下拉(HSV)、Start/Hold/End 前缀、FPS
 *  - Offsets 页：全局 offsets + 三段 startOffset/holdOffset/endOffset 的 X/Y 数值框微调
 *
 * 保存路径：
 *  - HSV：assets/shared/images/holdCover/hsv/holdCover{Color}.json（每色独立）
 *  - RGB：assets/shared/images/holdCover/sustain_cover.json（单素材）
 */
class HoldCoverEditorState extends MusicBeatState
{
	var UI_box:PsychUIBox;

	var covers:FlxTypedGroup<NoteHoldCover> = new FlxTypedGroup<NoteHoldCover>();
	var strums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();

	var _config:HoldCoverConfig;
	var _isRGB:Bool = false;

	var _curColorIndex:Int = 0;
	var errorText:FlxText;
	var curText:FlxText;

	// 输入控件
	var scaleNumericStepper:PsychUINumericStepper;
	var startInput:PsychUIInputText;
	var holdInput:PsychUIInputText;
	var endInput:PsychUIInputText;
	var fpsStepper:PsychUINumericStepper;
	var colorDropdown:PsychUIDropDownMenu;
	var arrowKeysOption:PsychUICheckBox;
	var disableRGBCheck:PsychUICheckBox;

	// 偏移数值框（Offsets 页）
	var allocGlobalX:PsychUINumericStepper;
	var allocGlobalY:PsychUINumericStepper;
	var allocStartX:PsychUINumericStepper;
	var allocStartY:PsychUINumericStepper;
	var allocHoldX:PsychUINumericStepper;
	var allocHoldY:PsychUINumericStepper;
	var allocEndX:PsychUINumericStepper;
	var allocEndY:PsychUINumericStepper;

	var copiedOffset:Array<Float> = [0, 0];

	public static function getHoldCoverPostfix():String
		return NoteHoldCover.getHoldCoverPostfix();

	function currentColor():String
		return _isRGB ? 'RGB' : NoteHoldCover.COVER_COLORS[_curColorIndex];

	function currentAnim():HoldCoverAnim
		return (_config != null) ? _config.anims.get(currentColor()) : null;

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

		_isRGB = NoteHoldCover.isRGBSkin();
		loadConfigFromDisk();

		// UI
		UI_box = new PsychUIBox(0, 0, 0, 0, [
			Language.get('hold_cover_tab_props'),
			Language.get('hold_cover_tab_anims'),
			Language.get('hold_cover_tab_offsets')
		]);
		UI_box.canMove = UI_box.canMinimize = false;
		UI_box.resize(360, 285);
		UI_box.x = FlxG.width - UI_box.width - 10;
		UI_box.y = 20;
		UI_box.scrollFactor.set();

		addPropertiesTab();
		addAnimationsTab();
		addOffsetsTab();

		errorText = new FlxText(0, FlxG.height - 30, 0, '', 14);
		errorText.setFormat(Paths.font(Language.get('uitab_font')), 14, FlxColor.RED, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorText.scrollFactor.set();
		add(errorText);

		curText = new FlxText(0, 40, FlxG.width, '', 14);
		curText.setFormat(Paths.font(Language.get('uitab_font')), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		curText.scrollFactor.set();
		add(curText);

		rebuildPreviews();
		// UI 面板最后 add，确保绘制在预览(strums/covers)之上，下拉框不会被盖住
		add(UI_box);
	}

	// ---- 配置加载（深拷贝，避免污染 NoteHoldCover 静态缓存）----

	function loadConfigFromDisk():Void
	{
		_config = {scale: 1, anims: new Map<String, HoldCoverAnim>(), disableRGB: false};

		if (_isRGB)
		{
			var raw:Dynamic = null;
			var jsonPath:String = 'holdCover/sustain_cover';
			if (Paths.fileExists('images/$jsonPath.json', AssetType.TEXT))
			{
				try raw = Json.parse(Paths.getTextFromFile('images/$jsonPath.json'))
				catch (e:Dynamic) {}
			}
			var anim:HoldCoverAnim = (raw != null) ? NoteHoldCover.parseAnim(raw) : NoteHoldCover.rgbDefaultAnim();
			_config.anims.set('RGB', cloneAnim(anim));
			if (raw != null)
			{
				if (raw.scale != null) _config.scale = raw.scale;
				if (raw.disableRGB != null) _config.disableRGB = (raw.disableRGB == true);
			}
		}
		else
		{
			for (color in NoteHoldCover.COVER_COLORS)
				_config.anims.set(color, cloneAnim(loadColorConfig(color)));
		}
	}

	function cloneAnim(a:HoldCoverAnim):HoldCoverAnim
	{
		return {
			start: (a != null && a.start != null) ? a.start : null,
			hold: (a != null && a.hold != null) ? a.hold : null,
			end: (a != null && a.end != null) ? a.end : null,
			fps: (a != null && a.fps != null) ? a.fps : 24,
			offsets: ((a != null && a.offsets != null) ? a.offsets : [0.0, 0.0]).copy(),
			startOffset: ((a != null && a.startOffset != null) ? a.startOffset : [0.0, 0.0]).copy(),
			holdOffset: ((a != null && a.holdOffset != null) ? a.holdOffset : [0.0, 0.0]).copy(),
			endOffset: ((a != null && a.endOffset != null) ? a.endOffset : [0.0, 0.0]).copy(),
			scale: (a != null && a.scale != null) ? a.scale : 1
		};
	}

	function loadColorConfig(color:String):HoldCoverAnim
	{
		var jsonPath:String = NoteHoldCover.getConfigJsonPath(color);
		if (Paths.fileExists('images/$jsonPath.json', AssetType.TEXT))
		{
			try
			{
				var raw = Json.parse(Paths.getTextFromFile('images/$jsonPath.json'));
				return NoteHoldCover.parseAnim(raw);
			}
			catch (e:Dynamic) {}
		}
		return {start: 'holdCoverStart' + color, hold: 'holdCover' + color, end: 'holdCoverEnd' + color, fps: 24, offsets: [0, 0], startOffset: [0, 0], holdOffset: [0, 0], endOffset: [0, 0], scale: 1};
	}

	// ---- 预览重建 ----

	function rebuildPreviews():Void
	{
		for (c in covers) c.destroy();
		for (s in strums) s.destroy();
		covers.clear();
		strums.clear();

		for (i in 0...NoteHoldCover.COVER_COLORS.length)
		{
			var color = NoteHoldCover.COVER_COLORS[i];
			var strumX = 120 + (640 / NoteHoldCover.COVER_COLORS.length) * i;
			var strumY = 250;
			var strum:StrumNote = new StrumNote(strumX, strumY, i, 0);
			strums.add(strum);

			try
			{
				// HSV 模式强制用基础 hsv 图集，忽略全局皮肤后缀，避免切到 HSV 时读到不存在的路径
				var atlasPath:String = _isRGB ? null : ('holdCover/hsv/holdCover' + color);
				var cover:NoteHoldCover = new NoteHoldCover(strum, i, _config, _isRGB, atlasPath);
				cover.freezeHold = true;
				covers.add(cover);
			}
			catch (e:Dynamic) {}
		}
		add(strums);
		add(covers);

		for (c in covers)
			applyConfigToCover(c, c.coverColor);
		refreshAnimInputs();
		refreshOffsetInputs();
	}

	function applyConfigToCover(cover:NoteHoldCover, color:String)
	{
		var key:String = _isRGB ? 'RGB' : color;
		var anim:HoldCoverAnim = _config.anims.get(key);
		cover.config.scale = _config.scale;
		if (anim != null) cover.reloadAnims(anim);
		if (_isRGB) cover.config.disableRGB = _config.disableRGB;
		if (_isRGB && cover.rgbShader != null)
			cover.rgbShader.enabled = !cover.config.disableRGB;
		cover.freezeHold = true;
		cover.startHold();
	}

	function applyForCurrentColor():Void
	{
		// RGB 模式下单配置作用于所有列；HSV 只作用于当前选中色
		if (_isRGB)
		{
			for (c in covers) applyConfigToCover(c, c.coverColor);
			return;
		}
		for (c in covers)
			if (c.coverColor == currentColor())
				applyConfigToCover(c, currentColor());
	}

	// ---- Properties 页 ----

	function addPropertiesTab()
	{
		var ui = UI_box.getTab(Language.get('hold_cover_tab_props')).menu;

		ui.add(uilabel(20, 10, 90, Language.get('hold_cover_edit_target')));
		var modeOptions:Array<String> = [
			'HSV',
			Language.get('hold_cover_skin_rgb')
		];
		var modeDropdown:PsychUIDropDownMenu = new PsychUIDropDownMenu(105, 8, modeOptions, function(id:Int, name:String)
		{
			_isRGB = (id == 1);
			for (c in covers) c.destroy();
			loadConfigFromDisk();
			rebuildPreviews();
			var lbl:String = (colorDropdown != null) ? colorLabel(currentColor()) : '';
			if (colorDropdown != null)
			{
				colorDropdown.visible = !_isRGB;
				colorDropdown.selectedLabel = lbl;
			}
		});
		modeDropdown.selectedLabel = _isRGB ? Language.get('hold_cover_skin_rgb') : 'HSV';
		ui.add(modeDropdown);

		ui.add(uilabel(20, 42, 90, Language.get('hold_cover_scale')));
		scaleNumericStepper = new PsychUINumericStepper(105, 42, 0.1, _config.scale, 0, 4, 2, 70);
		scaleNumericStepper.onValueChange = () ->
		{
			_config.scale = scaleNumericStepper.value;
			for (c in covers) applyConfigToCover(c, c.coverColor);
		};
		ui.add(scaleNumericStepper);

		disableRGBCheck = new PsychUICheckBox(20, 78, Language.get('hold_cover_disable_rgb'), 200, function()
		{
			_config.disableRGB = disableRGBCheck.checked;
			for (c in covers)
				if (_isRGB) applyConfigToCover(c, c.coverColor);
		});
		disableRGBCheck.checked = _config.disableRGB;
		ui.add(disableRGBCheck);

		var reloadButton:PsychUIButton = new PsychUIButton(20, 108, Language.get('hold_cover_reload_image'), function()
		{
			for (c in covers) c.destroy();
			loadConfigFromDisk();
			rebuildPreviews();
		});
		ui.add(reloadButton);

		var saveButton:PsychUIButton = new PsychUIButton(110, 108, Language.get('hold_cover_save'), saveCFG);
		ui.add(saveButton);

		var templateButton:PsychUIButton = new PsychUIButton(210, 108, Language.get('hold_cover_template'), saveTemplate);
		ui.add(templateButton);

		var helpButton:PsychUIButton = new PsychUIButton(20, 145, Language.get('hold_cover_help'), function()
		{
			openSubState(new HoldCoverEditorHelp());
		});
		ui.add(helpButton);

		var exitButton:PsychUIButton = new PsychUIButton(110, 145, Language.get('hold_cover_exit'), exitState);
		ui.add(exitButton);
	}

	function exitState():Void
	{
		MusicBeatState.switchState(new MasterEditorMenu());
	}

	// ---- Animations 页 ----

	function addAnimationsTab()
	{
		var ui = UI_box.getTab(Language.get('hold_cover_tab_anims')).menu;

		ui.add(uilabel(20, 10, 60, Language.get('hold_cover_color')));
		var colorOptions:Array<String> = [for (c in NoteHoldCover.COVER_COLORS) colorLabel(c)];
		colorDropdown = new PsychUIDropDownMenu(70, 8, colorOptions, function(id:Int, name:String)
		{
			_curColorIndex = id;
			refreshAnimInputs();
			refreshOffsetInputs();
		});
		colorDropdown.selectedLabel = colorLabel(NoteHoldCover.COVER_COLORS[_curColorIndex]);
		colorDropdown.visible = !_isRGB;
		ui.add(colorDropdown);

		ui.add(uilabel(20, 45, 60, Language.get('hold_cover_start')));
		startInput = new PsychUIInputText(70, 45, 220, '', 12);
		startInput.onChange = function(old:String, cur:String)
		{
			if (currentAnim() != null) { currentAnim().start = cur; applyForCurrentColor(); }
		};
		ui.add(startInput);

		ui.add(uilabel(20, 75, 60, Language.get('hold_cover_hold')));
		holdInput = new PsychUIInputText(70, 75, 220, '', 12);
		holdInput.onChange = function(old:String, cur:String)
		{
			if (currentAnim() != null) { currentAnim().hold = cur; applyForCurrentColor(); }
		};
		ui.add(holdInput);

		ui.add(uilabel(20, 105, 60, Language.get('hold_cover_end')));
		endInput = new PsychUIInputText(70, 105, 220, '', 12);
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

		arrowKeysOption = new PsychUICheckBox(20, 175, Language.get('hold_cover_use_arrow_keys'), 230, function() {});
		ui.add(arrowKeysOption);

		refreshAnimInputs();
	}

	function refreshAnimInputs():Void
	{
		var anim = currentAnim();
		if (anim == null || startInput == null) return;
		startInput.text = (anim.start != null) ? anim.start : '';
		holdInput.text = (anim.hold != null) ? anim.hold : '';
		endInput.text = (anim.end != null) ? anim.end : '';
		fpsStepper.value = (anim.fps != null) ? anim.fps : 24;
	}

	// ---- Offsets 页（数值框微调）----

	function addOffsetRow(ui:FlxSpriteGroup, y:Float, label:String, gx:PsychUINumericStepper, gy:PsychUINumericStepper)
	{
		ui.add(uilabel(12, y + 2, 70, label));
		// X / Y 两组数值框，横排放置
		ui.add(uilabel(95, y + 2, 18, 'X'));
		ui.add(gx);
		ui.add(uilabel(215, y + 2, 18, 'Y'));
		ui.add(gy);
	}

	function makeOffsetStepper(x:Float, y:Float, defVal:Float):PsychUINumericStepper
	{
		var s = new PsychUINumericStepper(x, y, 1, defVal, -999, 999, 0, 60);
		return s;
	}

	function addOffsetsTab()
	{
		var ui = UI_box.getTab(Language.get('hold_cover_tab_offsets')).menu;
		var y:Float = 8;

		allocGlobalX = makeOffsetStepper(110, y, 0);
		allocGlobalY = makeOffsetStepper(230, y, 0);
		addOffsetRow(ui, y, Language.get('hold_cover_offsets_global'), allocGlobalX, allocGlobalY);
		y += 34;

		allocStartX = makeOffsetStepper(110, y, 0);
		allocStartY = makeOffsetStepper(230, y, 0);
		addOffsetRow(ui, y, Language.get('hold_cover_offsets_start'), allocStartX, allocStartY);
		y += 34;

		allocHoldX = makeOffsetStepper(110, y, 0);
		allocHoldY = makeOffsetStepper(230, y, 0);
		addOffsetRow(ui, y, Language.get('hold_cover_offsets_hold'), allocHoldX, allocHoldY);
		y += 34;

		allocEndX = makeOffsetStepper(110, y, 0);
		allocEndY = makeOffsetStepper(230, y, 0);
		addOffsetRow(ui, y, Language.get('hold_cover_offsets_end'), allocEndX, allocEndY);
		y += 44;

		ui.add(uilabel(12, y, 340, Language.get('hold_cover_offsets_tip')));

		bindOffsetSteppers();
		refreshOffsetInputs();
	}

	function refreshOffsetInputs():Void
	{
		var anim = currentAnim();
		if (anim == null || allocGlobalX == null) return;

		unbindOffsetSteppers();
		allocGlobalX.value = (anim.offsets != null) ? anim.offsets[0] : 0;
		allocGlobalY.value = (anim.offsets != null) ? anim.offsets[1] : 0;
		allocStartX.value = (anim.startOffset != null) ? anim.startOffset[0] : 0;
		allocStartY.value = (anim.startOffset != null) ? anim.startOffset[1] : 0;
		allocHoldX.value = (anim.holdOffset != null) ? anim.holdOffset[0] : 0;
		allocHoldY.value = (anim.holdOffset != null) ? anim.holdOffset[1] : 0;
		allocEndX.value = (anim.endOffset != null) ? anim.endOffset[0] : 0;
		allocEndY.value = (anim.endOffset != null) ? anim.endOffset[1] : 0;
		bindOffsetSteppers();
	}

	function bindOffsetSteppers():Void
	{
		if (_bound) return;
		_bound = true;

		allocGlobalX.onValueChange = () -> { if (currentAnim() != null) { currentAnim().offsets[0] = allocGlobalX.value; applyForCurrentColor(); } };
		allocGlobalY.onValueChange = () -> { if (currentAnim() != null) { currentAnim().offsets[1] = allocGlobalY.value; applyForCurrentColor(); } };
		allocStartX.onValueChange = () -> { if (currentAnim() != null) { currentAnim().startOffset[0] = allocStartX.value; applyForCurrentColor(); } };
		allocStartY.onValueChange = () -> { if (currentAnim() != null) { currentAnim().startOffset[1] = allocStartY.value; applyForCurrentColor(); } };
		allocHoldX.onValueChange = () -> { if (currentAnim() != null) { currentAnim().holdOffset[0] = allocHoldX.value; applyForCurrentColor(); } };
		allocHoldY.onValueChange = () -> { if (currentAnim() != null) { currentAnim().holdOffset[1] = allocHoldY.value; applyForCurrentColor(); } };
		allocEndX.onValueChange = () -> { if (currentAnim() != null) { currentAnim().endOffset[0] = allocEndX.value; applyForCurrentColor(); } };
		allocEndY.onValueChange = () -> { if (currentAnim() != null) { currentAnim().endOffset[1] = allocEndY.value; applyForCurrentColor(); } };
	}

	function unbindOffsetSteppers():Void
	{
		_bound = false;
		if (allocGlobalX != null) allocGlobalX.onValueChange = null;
		if (allocGlobalY != null) allocGlobalY.onValueChange = null;
		if (allocStartX != null) allocStartX.onValueChange = null;
		if (allocStartY != null) allocStartY.onValueChange = null;
		if (allocHoldX != null) allocHoldX.onValueChange = null;
		if (allocHoldY != null) allocHoldY.onValueChange = null;
		if (allocEndX != null) allocEndX.onValueChange = null;
		if (allocEndY != null) allocEndY.onValueChange = null;
	}
	var _bound:Bool = false;

	// ---- 保存 ----

	function saveCFG():Void
	{
		if (_isRGB)
		{
			var anim = currentAnim();
			var obj:Dynamic = {
				scale: _config.scale,
				disableRGB: _config.disableRGB,
				start: anim.start,
				hold: anim.hold,
				end: anim.end,
				fps: anim.fps,
				offsets: anim.offsets,
				startOffset: anim.startOffset,
				holdOffset: anim.holdOffset,
				endOffset: anim.endOffset
			};
			var data:String = Json.stringify(obj, "\t");
			#if mobile
			StorageUtil.saveContent('holdCover/sustain_cover.json', data);
			#else
			File.saveContent('assets/shared/images/holdCover/sustain_cover.json', data);
			#end
		}
		else
		{
			var postfix:String = getHoldCoverPostfix();
			var subDir:String = (postfix.length == 0) ? 'hsv/' : '';
			for (color in NoteHoldCover.COVER_COLORS)
			{
				var anim = _config.anims.get(color);
				var obj:Dynamic = {
					scale: _config.scale,
					disableRGB: false,
					start: anim.start,
					hold: anim.hold,
					end: anim.end,
					fps: anim.fps,
					offsets: anim.offsets,
					startOffset: anim.startOffset,
					holdOffset: anim.holdOffset,
					endOffset: anim.endOffset
				};
				var fileName:String = 'holdCover' + color + postfix;
				var data:String = Json.stringify(obj, "\t");
				#if mobile
				StorageUtil.saveContent(subDir + fileName + '.json', data);
				#else
				File.saveContent('assets/shared/images/holdCover/' + subDir + fileName + '.json', data);
				#end
			}
		}
		showError(Language.get('hold_cover_saved_cfg'), FlxColor.GREEN);
	}

	function saveTemplate():Void
	{
		var obj:Dynamic = {
			scale: 1,
			disableRGB: false,
			start: 'holdCoverStart{COLOR}',
			hold: 'holdCover{COLOR}',
			end: 'holdCoverEnd{COLOR}',
			fps: 24,
			offsets: [0, 0],
			startOffset: [0, 0],
			holdOffset: [0, 0],
			endOffset: [0, 0]
		};
		var data:String = Json.stringify(obj, "\t");
		#if mobile
		StorageUtil.saveContent('holdCoverTemplate.json', data);
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

	// ---- 方向键微调（可选的补充入口，作用于当前 color/段 的 offsets） ----

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

		var anim = currentAnim();
		curText.text = Language.get('hold_cover_edited_target', [
			(_isRGB ? Language.get('hold_cover_skin_rgb') : colorLabel(currentColor())),
			Std.string(colorDropdown == null ? '' : colorDropdown.selectedLabel)
		]);
		if (anim != null)
		{
			curText.text += "\n";
			curText.text += Language.get('hold_cover_offsets_global') + ': [' + (anim.offsets == null ? '0, 0' : anim.offsets.join(', ')) + ']  ';
			curText.text += Language.get('hold_cover_offsets_start') + ': [' + (anim.startOffset == null ? '0, 0' : anim.startOffset.join(', ')) + ']  ';
			curText.text += Language.get('hold_cover_offsets_hold') + ': [' + (anim.holdOffset == null ? '0, 0' : anim.holdOffset.join(', ')) + ']  ';
			curText.text += Language.get('hold_cover_offsets_end') + ': [' + (anim.endOffset == null ? '0, 0' : anim.endOffset.join(', ')) + ']';
		}

		if (arrowKeysOption.checked && !blockInput && anim != null)
		{
			var changed:Bool = false;
			if (anim.offsets == null) anim.offsets = [0, 0];
			if (FlxG.keys.pressed.LEFT) { anim.offsets[0] -= 1; changed = true; }
			else if (FlxG.keys.pressed.RIGHT) { anim.offsets[0] += 1; changed = true; }
			if (FlxG.keys.pressed.UP) { anim.offsets[1] -= 1; changed = true; }
			else if (FlxG.keys.pressed.DOWN) { anim.offsets[1] += 1; changed = true; }

			if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C)
				copiedOffset = anim.offsets.copy();

			if (changed)
			{
				for (c in covers)
					if (c.coverColor == currentColor())
						c.setOffsets(anim.offsets);
				refreshOffsetInputs();
			}
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