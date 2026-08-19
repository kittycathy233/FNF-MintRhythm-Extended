package states.editors;

import backend.StageData;
import backend.PsychCamera;
import backend.Language;
import backend.Paths;
import objects.Character;
import psychlua.LuaUtils;

import flixel.FlxObject;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;
import openfl.utils.ByteArray;

import openfl.display.Sprite;

import openfl.net.FileReference;

import openfl.events.Event;
import openfl.events.IOErrorEvent;

import psychlua.ModchartSprite;
import flash.net.FileFilter;

import states.editors.content.Prompt;
import states.editors.content.PreloadListSubState;

class StageEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	final minZoom = 0.1;
	final maxZoom = 2;

	var gf:Character;
	var dad:Character;
	var boyfriend:Character;
	var stageJson:StageFile;

	var camGame:FlxCamera;
	public var camHUD:FlxCamera;

	var UI_stagebox:PsychUIBox;
	var UI_box:PsychUIBox;
	var spriteList_box:PsychUIBox;
	var stageSprites:Array<StageEditorMetaSprite> = [];
	public function new(stageToLoad:String = 'stage', cachedJson:StageFile = null)
	{
		lastLoadedStage = stageToLoad;
		stageJson = cachedJson;
		super();
	}

	var lastLoadedStage:String;
	var camFollow:FlxObject = new FlxObject(0, 0, 1, 1);

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	var posTxt:FlxText;
	var outputTxt:FlxText;

	var animationEditor:StageEditorAnimationSubstate;
	var unsavedProgress:Bool = false;
	
	var selectionSprites:FlxSpriteGroup = new FlxSpriteGroup();
	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Stage Editor', 'Stage: ' + lastLoadedStage);
		#end

		if(stageJson == null) stageJson = StageData.getStageFile(lastLoadedStage);
		FlxG.camera.follow(null, LOCKON, 0);

		loadJsonAssetDirectory();
		gf = new Character(0, 0, stageJson._editorMeta != null ? stageJson._editorMeta.gf : 'gf');
		gf.visible = !(stageJson.hide_girlfriend);
		gf.scrollFactor.set(0.95, 0.95);
		dad = new Character(0, 0, stageJson._editorMeta != null ? stageJson._editorMeta.dad : 'dad');
		boyfriend = new Character(0, 0, stageJson._editorMeta != null ? stageJson._editorMeta.boyfriend : 'bf', true);

		for (i in 0...4)
		{
			var spr:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.LIME);
			spr.alpha = 0.8;
			selectionSprites.add(spr);
		}

		FlxG.camera.zoom = stageJson.defaultZoom;
		repositionGirlfriend();
		repositionDad();
		repositionBoyfriend();
		var point = focusOnTarget('boyfriend');
		FlxG.camera.scroll.set(point.x - FlxG.width/2, point.y - FlxG.height/2);

		screenUI();
		spriteCreatePopup();
		editorUI();
		
		add(camFollow);
		updateSpriteList();

		addHelpScreen();
		FlxG.mouse.visible = true;
		animationEditor = new StageEditorAnimationSubstate();

		addTouchPad('LEFT_FULL', 'CHARACTER_EDITOR');
		addTouchPadCamera();

		super.create();
	}

	function lbl(x:Float, y:Float, w:Int, text:String, ?size:Int = 12):FlxText
	{
		var s:Int = size != null ? size : 12;
		var fontKey:String = (s <= 10) ? 'uitab_font_small' : 'uitab_font';
		var flxText:FlxText = new FlxText(x, y, w, text, s).setFormat(Paths.font(Language.get(fontKey)), s);
		// If text wraps within the given width, expand fieldWidth to fit on one line
		var curHeight:Float = flxText.height;
		var lineH:Float = s * 1.3; // Estimate line height from font size (CJK fonts are taller)
		if (curHeight > lineH)
		{
			// Estimate needed width based on CJK character size (slightly wider than size)
			var estWidth:Int = Std.int(text.length * (s + 2) + 20);
			if (estWidth > w)
				flxText.fieldWidth = estWidth;
			// Verify and adjust if still wrapping
			if (flxText.height > lineH)
			{
				var neededWidth:Int = w;
				while (flxText.height > lineH && neededWidth < 2000)
				{
					neededWidth += 20;
					flxText.fieldWidth = neededWidth;
				}
			}
		}
		return flxText;
	}

	function loadJsonAssetDirectory()
	{
		var directory:String = 'shared';
		var weekDir:String = stageJson.directory;
		if (weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);
	}

	var showSelectionQuad:Bool = true;
	function addHelpScreen()
	{
		#if FLX_DEBUG
		var btn = 'F3';
		#else
		var btn = 'F2';
		#end

		var str:Array<String> = (controls.mobileC) ? [
			Language.get('stage_editor_help_m_zoom'),
			Language.get('stage_editor_help_m_move_cam'),
			Language.get('stage_editor_help_m_reset_zoom'),
			Language.get('stage_editor_help_m_move_obj'),
			"",
			Language.get('stage_editor_help_m_toggle_hud'),
			Language.get('stage_editor_help_m_fast')
		] : [
			Language.get('stage_editor_help_d_zoom'),
			Language.get('stage_editor_help_d_move_cam'),
			Language.get('stage_editor_help_d_reset_zoom'),
			Language.get('stage_editor_help_d_move_obj'),
			"",
			Language.get('stage_editor_help_d_toggle_hud', [btn]),
			Language.get('stage_editor_help_d_select_rect'),
			Language.get('stage_editor_help_d_fast'),
			Language.get('stage_editor_help_d_slow')
		];

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.6;
		helpBg.cameras = [camHUD];
		helpBg.active = helpBg.visible = false;
		add(helpBg);

		helpTexts = new FlxSpriteGroup();
		helpTexts.cameras = [camHUD];
		#if mobile
		var helpSize:Int = 16;
		var helpSpacing:Int = 32;
		var helpWidth:Int = 680;
		#else
		var helpSize:Int = 12;
		var helpSpacing:Int = 24;
		var helpWidth:Int = 680;
		#end
		for (i => txt in str)
		{
			if(txt.length < 1) continue;

			var helpText:FlxText = lbl(0, 0, helpWidth, txt, helpSize);
			helpText.setFormat(Paths.font(Language.get('uitab_font')), helpSize, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.borderColor = FlxColor.BLACK;
			helpText.scrollFactor.set();
			helpText.borderSize = 1;
			helpText.screenCenter();
			add(helpText);
			helpText.y += ((i - str.length/2) * helpSpacing) + 16;
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	function updateSpriteList()
	{
		for (spr in stageSprites)
			if(spr != null && !StageData.reservedNames.contains(spr.type))
				spr.sprite = FlxDestroyUtil.destroy(spr.sprite);

		stageSprites = [];
		var list:Map<String, FlxSprite> = [];
		if(stageJson.objects != null && stageJson.objects.length > 0)
		{
			list = StageData.addObjectsToState(stageJson.objects, gf, dad, boyfriend, null, true);
			for (key => spr in list)
				stageSprites[spr.ID] = new StageEditorMetaSprite(stageJson.objects[spr.ID], spr);

			/*for (num => spr in stageSprites)
				trace('$num: ${spr.type}, ${spr.name}');*/
		}

		for (character in ['gf', 'dad', 'boyfriend'])
			if(!list.exists(character))
				stageSprites.push(new StageEditorMetaSprite({type: character}, Reflect.field(this, character)));

		updateSpriteListRadio();
	}

	var spriteListRadioGroup:PsychUIRadioGroup;
	var focusRadioGroup:PsychUIRadioGroup;

	function screenUI()
	{
		var lowQualityCheckbox:PsychUICheckBox = null;
		var highQualityCheckbox:PsychUICheckBox = null;
		function visibilityFilterUpdate()
		{
			curFilters = 0;
			if(lowQualityCheckbox.checked) curFilters |= LOW_QUALITY;
			if(highQualityCheckbox.checked) curFilters |= HIGH_QUALITY;
		}

		spriteList_box = new PsychUIBox(25, #if mobile 70 #else 40 #end, 250, 200, [Language.get('stage_editor_sprite_list')]);
		spriteList_box.scrollFactor.set();
		spriteList_box.cameras = [camHUD];
		add(spriteList_box);
		addSpriteListBox();

		#if mobile
		var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
		bg.cameras = [camHUD];
		bg.alpha = 0.4;
		bg.scale.set(FlxG.width, 60);
		bg.updateHitbox();
		add(bg);
		
		var targetTxt:FlxText = lbl(30, 8, 300, Language.get('stage_editor_camera_target'), 16);
		targetTxt.alignment = CENTER;
		targetTxt.cameras = [camHUD];
		targetTxt.scrollFactor.set();
		targetTxt.active = false;
		add(targetTxt);

		focusRadioGroup = new PsychUIRadioGroup(targetTxt.x, 36, ['dad', 'boyfriend', 'gf'], 10, 0, true);
		focusRadioGroup.onClick = function() {
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
			FlxG.camera.target = camFollow;
		}
		focusRadioGroup.radios[0].label = Language.get('stage_editor_opponent');
		focusRadioGroup.radios[1].label = Language.get('stage_editor_boyfriend');
		focusRadioGroup.radios[2].label = Language.get('stage_editor_girlfriend');

		for (radio in focusRadioGroup.radios)
			radio.text.size = 11;
		
		focusRadioGroup.cameras = [camHUD];
		add(focusRadioGroup);

		lowQualityCheckbox = new PsychUICheckBox(FlxG.width - 340, 24, Language.get('stage_editor_can_see_low_quality'), 160);
		lowQualityCheckbox.cameras = [camHUD];
		lowQualityCheckbox.onClick = visibilityFilterUpdate;
		lowQualityCheckbox.checked = false;
		add(lowQualityCheckbox);

		highQualityCheckbox = new PsychUICheckBox(FlxG.width - 185, 24, Language.get('stage_editor_can_see_high_quality'), 160);
		highQualityCheckbox.cameras = [camHUD];
		highQualityCheckbox.onClick = visibilityFilterUpdate;
		highQualityCheckbox.checked = true;
		add(highQualityCheckbox);
		visibilityFilterUpdate();

		var tipTextMobile:FlxText = lbl(0, 20, 300, Language.get('stage_editor_press_f1_for_help', [(controls.mobileC) ? 'F' : 'F1']), 12);
		tipTextMobile.alignment = CENTER;
		tipTextMobile.cameras = [camHUD];
		tipTextMobile.scrollFactor.set();
		tipTextMobile.screenCenter(X);
		tipTextMobile.borderStyle = OUTLINE_FAST;
		tipTextMobile.borderColor = FlxColor.BLACK;
		tipTextMobile.borderSize = 2;
		tipTextMobile.active = false;
		add(tipTextMobile);
		#else
		var bg:FlxSprite = new FlxSprite(0, FlxG.height - 60).makeGraphic(1, 1, FlxColor.BLACK);
		bg.cameras = [camHUD];
		bg.alpha = 0.4;
		bg.scale.set(FlxG.width, FlxG.height - bg.y);
		bg.updateHitbox();
		add(bg);
		
		var tipText:FlxText = lbl(0, FlxG.height - 44, 300, Language.get('stage_editor_press_f1_for_help', [(controls.mobileC) ? 'F' : 'F1']), 20);
		tipText.alignment = CENTER;
		tipText.cameras = [camHUD];
		tipText.scrollFactor.set();
		tipText.screenCenter(X);
		tipText.active = false;
		add(tipText);

		var targetTxt:FlxText = lbl(30, FlxG.height - 52, 300, Language.get('stage_editor_camera_target'), 16);
		targetTxt.alignment = CENTER;
		targetTxt.cameras = [camHUD];
		targetTxt.scrollFactor.set();
		targetTxt.active = false;
		add(targetTxt);

		focusRadioGroup = new PsychUIRadioGroup(targetTxt.x, FlxG.height - 24, ['dad', 'boyfriend', 'gf'], 10, 0, true);
		focusRadioGroup.onClick = function() {
			//trace('Changed focus to $target');
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
			FlxG.camera.target = camFollow;
		}
		focusRadioGroup.radios[0].label = Language.get('stage_editor_opponent');
		focusRadioGroup.radios[1].label = Language.get('stage_editor_boyfriend');
		focusRadioGroup.radios[2].label = Language.get('stage_editor_girlfriend');

		for (radio in focusRadioGroup.radios)
			radio.text.size = 11;
		
		focusRadioGroup.cameras = [camHUD];
		add(focusRadioGroup);

		lowQualityCheckbox = new PsychUICheckBox(FlxG.width - 340, FlxG.height - 36, Language.get('stage_editor_can_see_low_quality'), 160);
		lowQualityCheckbox.cameras = [camHUD];
		lowQualityCheckbox.onClick = visibilityFilterUpdate;
		lowQualityCheckbox.checked = false;
		add(lowQualityCheckbox);

		highQualityCheckbox = new PsychUICheckBox(FlxG.width - 185, FlxG.height - 36, Language.get('stage_editor_can_see_high_quality'), 160);
		highQualityCheckbox.cameras = [camHUD];
		highQualityCheckbox.onClick = visibilityFilterUpdate;
		highQualityCheckbox.checked = true;
		add(highQualityCheckbox);
		visibilityFilterUpdate();
		#end

		posTxt = new FlxText(0, 50, 500, Language.get('stage_editor_pos_x_y', ['0', '0']), 24);
		posTxt.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		posTxt.borderSize = 2;
		posTxt.cameras = [camHUD];
		posTxt.screenCenter(X);
		posTxt.visible = false;
		add(posTxt);

		outputTxt = lbl(0, 0, 800, '', 24);
		outputTxt.alignment = CENTER;
		outputTxt.borderStyle = OUTLINE_FAST;
		outputTxt.borderSize = 1;
		outputTxt.cameras = [camHUD];
		#if mobile
		outputTxt.y = 68;
		outputTxt.screenCenter(X);
		#else
		outputTxt.screenCenter();
		#end
		outputTxt.alpha = 0;
		add(outputTxt);
	}

	function addSpriteListBox()
	{
		var tab_group = spriteList_box.getTab(Language.get('stage_editor_sprite_list')).menu;
		spriteListRadioGroup = new PsychUIRadioGroup(10, 10, [], 25, 18, false, 200);
		spriteListRadioGroup.cameras = [camHUD];
		spriteListRadioGroup.onClick = function() {
			trace('Selected sprite: ${spriteListRadioGroup.checkedRadio.label}');
			updateSelectedUI();
		}
		tab_group.add(spriteListRadioGroup);
		
		var buttonX = spriteList_box.x + spriteList_box.width - 10;
		var buttonY = spriteListRadioGroup.y - 30;
		var buttonMoveUp:PsychUIButton = new PsychUIButton(buttonX, buttonY, Language.get('stage_editor_move_up'), function()
		{
			var selected:Int = spriteListRadioGroup.checked;
			if(selected < 0) return;

			var selected:Int = spriteListRadioGroup.labels.length - selected - 1;
			var spr = stageSprites[selected];
			if(spr == null) return;

			var newSel:Int = Std.int(Math.min(stageSprites.length-1, selected + 1));
			stageSprites.remove(spr);
			stageSprites.insert(newSel, spr);

			updateSpriteListRadio();
		});
		buttonMoveUp.cameras = [camHUD];
		tab_group.add(buttonMoveUp);

		var buttonMoveDown:PsychUIButton = new PsychUIButton(buttonX, buttonY + 30, Language.get('stage_editor_move_down'), function()
		{
			var selected:Int = spriteListRadioGroup.checked;
			if(selected < 0) return;

			var selected:Int = spriteListRadioGroup.labels.length - selected - 1;
			var spr = stageSprites[selected];
			if(spr == null) return;

			var newSel:Int = Std.int(Math.max(0, selected - 1));
			stageSprites.remove(spr);
			stageSprites.insert(newSel, spr);

			updateSpriteListRadio();
		});
		buttonMoveDown.cameras = [camHUD];
		tab_group.add(buttonMoveDown);
		
		var buttonCreate:PsychUIButton = new PsychUIButton(buttonX, buttonY + 60, Language.get('stage_editor_new'), function() createPopup.visible = createPopup.active = true);
		buttonCreate.cameras = [camHUD];
		buttonCreate.normalStyle.bgColor = FlxColor.GREEN;
		buttonCreate.normalStyle.textColor = FlxColor.WHITE;
		tab_group.add(buttonCreate);

		var buttonDuplicate:PsychUIButton = new PsychUIButton(buttonX, buttonY + 90, Language.get('stage_editor_duplicate'), function()
		{
			var selected:Int = spriteListRadioGroup.checked;
			if(selected < 0) return;

			var selected:Int = spriteListRadioGroup.labels.length - selected - 1;
			var spr = stageSprites[selected];
			if(spr == null || StageData.reservedNames.contains(spr.type)) return;

			var copiedSpr = new ModchartSprite();
			var copiedMeta:StageEditorMetaSprite = new StageEditorMetaSprite(null, copiedSpr);
			for (field in Reflect.fields(spr))
			{
				if(field == 'sprite') continue; //do NOT copy sprite or it might get messy

				try
				{
					var fld:Dynamic = Reflect.getProperty(spr, field);
					if(fld is Array)
					{
						var arr:Array<Dynamic> = fld;
						arr = arr.copy();
						if(arr != null)
						{
							for (k => v in arr)
							{
								var indices:Array<Int> = v.indices;
								if(indices != null) indices = indices.copy();
	
								var offs:Array<Int> = v.offsets;
								if(offs != null) offs = offs.copy();

								fld[k] = {
									anim: v.anim,
									name: v.name,
									fps: v.fps,
									loop: v.loop,
									indices: indices,
									offsets: offs
								}
							}
						}
						fld = arr;
					}

					Reflect.setProperty(copiedMeta, field, fld);
					//trace('success? $field');
				}
				catch(e:Dynamic)
				{
					//trace('failed: $field');
				}
			}

			if(copiedMeta.animations != null)
			{
				for (num => anim in copiedMeta.animations)
				{
					if(anim == null || anim.anim == null) continue;
	
					if(anim.indices != null && anim.indices.length > 0)
						copiedSpr.animation.addByIndices(anim.anim, anim.name, anim.indices, '', anim.fps, anim.loop);
					else
						copiedSpr.animation.addByPrefix(anim.anim, anim.name, anim.fps, anim.loop);
	
					if(anim.offsets != null && anim.offsets.length > 1)
						copiedSpr.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
	
					if(copiedSpr.animation.curAnim == null || copiedMeta.firstAnimation == anim.anim)
						copiedSpr.playAnim(anim.anim, true);
				}
			}
			copiedMeta.setScale(copiedMeta.scale[0], copiedMeta.scale[1]);
			copiedMeta.setScrollFactor(copiedMeta.scroll[0], copiedMeta.scroll[1]);
			copiedMeta.name = findUnoccupiedName('${copiedMeta.name}_copy');
			insertMeta(copiedMeta, 1);
		});
		buttonDuplicate.cameras = [camHUD];
		buttonDuplicate.normalStyle.bgColor = FlxColor.BLUE;
		buttonDuplicate.normalStyle.textColor = FlxColor.WHITE;
		tab_group.add(buttonDuplicate);
	
		var buttonDelete:PsychUIButton = new PsychUIButton(buttonX, buttonY + 120, Language.get('stage_editor_delete'), function()
		{
			var selected:Int = spriteListRadioGroup.checked;
			if(selected < 0) return;

			var selected:Int = spriteListRadioGroup.labels.length - selected - 1;
			var spr = stageSprites[selected];
			if(spr == null || StageData.reservedNames.contains(spr.type)) return;

			stageSprites.remove(spr);
			spr.sprite = FlxDestroyUtil.destroy(spr.sprite);

			updateSpriteListRadio();
		});
		buttonDelete.cameras = [camHUD];
		buttonDelete.normalStyle.bgColor = FlxColor.RED;
		buttonDelete.normalStyle.textColor = FlxColor.WHITE;
		tab_group.add(buttonDelete);
	}

	function showOutput(txt:String, isError:Bool = false)
	{
		outputTxt.color = isError ? FlxColor.RED : FlxColor.WHITE;
		outputTxt.text = txt;
		outputTime = 3;
		
		if(isError) FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
		else FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	var createPopup:FlxSpriteGroup;
	var mobileSpritePopup:FlxSpriteGroup;
	var mobileSpriteInput:PsychUIInputText;
	var mobileSpriteAddBtn:PsychUIButton;
	var mobileSpriteType:String = null;
	var mobileSpriteLoadedKey:String = null;
	var mobileSpriteFormatTxt:FlxText;
	var mobileChangeImgPopup:FlxSpriteGroup;
	var mobileChangeImgInput:PsychUIInputText;
	var mobileChangeImgFormatTxt:FlxText;
	function findUnoccupiedName(prefix = 'sprite')
	{
		var num:Int = 1;
		var name:String = 'unnamed';
		while(true)
		{
			var cantUseName:Bool = false;
			
			name = prefix + num;
			for (basic in stageSprites)
			{
				if(basic.name == name)
				{
					cantUseName = true;
					break;
				}
			}
			
			if(cantUseName)
			{
				num++;
				continue;
			}
			break;
		}
		return name;
	}

	function insertMeta(meta, insertOffset:Int = 0)
	{
		var num:Int = Std.int(Math.max(0, Math.min(spriteListRadioGroup.labels.length, spriteListRadioGroup.labels.length - spriteListRadioGroup.checked - 1 + insertOffset)));
		stageSprites.insert(num, meta);
		updateSpriteListRadio();
		createPopup.visible = createPopup.active = false;
		spriteListRadioGroup.checked = spriteListRadioGroup.labels.length - num - 1;
		updateSelectedUI();
		unsavedProgress = true;
	}

	function spriteCreatePopup()
	{
		createPopup = new FlxSpriteGroup();
		createPopup.cameras = [camHUD];
		
		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.alpha = 0.6;
		bg.scale.set(300, 240);
		bg.updateHitbox();
		bg.screenCenter();
		createPopup.add(bg);

		var txt:FlxText = lbl(0, bg.y + 10, 180, Language.get('stage_editor_new_sprite'), 24);
		txt.screenCenter(X);
		txt.alignment = CENTER;
		createPopup.add(txt);

		var btnY = 320;
		#if mobile
		var btn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('stage_editor_no_animation'), function() openMobileSpriteInput('sprite'));
		#else
		var btn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('stage_editor_no_animation'), function() loadImage('sprite'));
		#end
		btn.screenCenter(X);
		createPopup.add(btn);

		btnY += 50;
		#if mobile
		var btn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('stage_editor_animated'), function() openMobileSpriteInput('animatedSprite'));
		#else
		var btn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('stage_editor_animated'), function() loadImage('animatedSprite'));
		#end
		btn.screenCenter(X);
		createPopup.add(btn);

		btnY += 50;
		var btn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('stage_editor_solid_color'), function() {
			var meta:StageEditorMetaSprite = new StageEditorMetaSprite({type: 'square', scale: [200, 200], name: findUnoccupiedName()}, new ModchartSprite());
			meta.sprite.makeGraphic(1, 1, FlxColor.WHITE);
			meta.sprite.scale.set(200, 200);
			meta.sprite.updateHitbox();
			meta.sprite.screenCenter();
			insertMeta(meta);
		});
		btn.screenCenter(X);
		createPopup.add(btn);
		add(createPopup);
		createPopup.visible = createPopup.active = false;

		#if mobile
		createMobileSpriteInput();
		createMobileChangeImagePopup();
		#end
	}

	#if mobile
	function createMobileSpriteInput()
	{
		mobileSpritePopup = new FlxSpriteGroup();
		mobileSpritePopup.cameras = [camHUD];

		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.alpha = 0.7;
		bg.scale.set(340, 280);
		bg.updateHitbox();
		bg.screenCenter();
		mobileSpritePopup.add(bg);

		var titleTxt:FlxText = lbl(0, bg.y + 10, 300, Language.get('stage_editor_new_sprite'), 20);
		titleTxt.screenCenter(X);
		titleTxt.alignment = CENTER;
		mobileSpritePopup.add(titleTxt);

		var yPos = bg.y + 45;

		var pathLbl:FlxText = lbl(bg.x + 10, yPos, 300, Language.get('stage_editor_mobile_sprite_path'), 14);
		mobileSpritePopup.add(pathLbl);

		yPos += 22;

		mobileSpriteInput = new PsychUIInputText(bg.x + 10, yPos, 310, '', 14);
		mobileSpriteInput.cameras = [camHUD];
		mobileSpritePopup.add(mobileSpriteInput);

		yPos += 36;

		mobileSpriteFormatTxt = lbl(bg.x + 10, yPos, 310, Language.get('stage_editor_mobile_sprite_format'), 12);
		mobileSpriteFormatTxt.color = 0xFFAAAAAA;
		mobileSpritePopup.add(mobileSpriteFormatTxt);

		yPos += 18;

		var hintTxt:FlxText = lbl(bg.x + 10, yPos, 310, Language.get('stage_editor_mobile_sprite_enter_hint'), 12);
		hintTxt.color = 0xFF666666;
		mobileSpritePopup.add(hintTxt);

		yPos += 46;

		mobileSpriteAddBtn = new PsychUIButton(0, yPos, Language.get('stage_editor_mobile_sprite_add'), function() tryAndAddMobileSprite());
		mobileSpriteAddBtn.screenCenter(X);
		mobileSpriteAddBtn.normalStyle.bgColor = FlxColor.GREEN;
		mobileSpriteAddBtn.normalStyle.textColor = FlxColor.WHITE;
		mobileSpritePopup.add(mobileSpriteAddBtn);

		yPos += 50;

		var cancelBtn:PsychUIButton = new PsychUIButton(0, yPos, Language.get('stage_editor_prompt_cancel'), function() {
			mobileSpritePopup.visible = mobileSpritePopup.active = false;
		});
		cancelBtn.screenCenter(X);
		mobileSpritePopup.add(cancelBtn);

		add(mobileSpritePopup);
		mobileSpritePopup.visible = mobileSpritePopup.active = false;
	}

	function openMobileSpriteInput(type:String)
	{
		mobileSpriteType = type;
		mobileSpriteLoadedKey = null;
		mobileSpriteInput.text = '';

		if (mobileSpriteFormatTxt != null)
		{
			mobileSpriteFormatTxt.text = Language.get(type == 'animatedSprite'
				? 'stage_editor_mobile_sprite_anim_required'
				: 'stage_editor_mobile_sprite_format');
		}

		createPopup.visible = createPopup.active = false;
		mobileSpritePopup.visible = mobileSpritePopup.active = true;
	}

	function tryAndAddMobileSprite()
	{
		var inputPath:String = mobileSpriteInput.text;
		if (inputPath == null || inputPath.trim().length == 0)
		{
			showOutput(Language.get('stage_editor_mobile_sprite_not_found', ['']), true);
			return;
		}

		var trimmedPath:String = inputPath.trim();
		if (trimmedPath.startsWith('images/'))
			trimmedPath = trimmedPath.substr('images/'.length);

		var lastDot:Int = trimmedPath.lastIndexOf('.');
		if (lastDot < 0)
		{
			showOutput(Language.get('stage_editor_mobile_sprite_invalid_ext'), true);
			return;
		}

		var ext:String = trimmedPath.substr(lastDot + 1).toLowerCase();
		var baseKey:String = trimmedPath.substr(0, lastDot);

		if (ext != 'png' && ext != 'xml' && ext != 'json' && ext != 'txt')
		{
			showOutput(Language.get('stage_editor_mobile_sprite_invalid_ext'), true);
			return;
		}

		var pngPath:String = 'images/$baseKey.png';
		if (!Paths.fileExists(pngPath, TEXT))
		{
			showOutput(Language.get('stage_editor_mobile_sprite_not_found', [pngPath]), true);
			return;
		}

		if (mobileSpriteType == 'animatedSprite')
		{
			var hasAnim:Bool = false;
			if (Paths.fileExists('images/$baseKey.xml', TEXT)) hasAnim = true;
			if (Paths.fileExists('images/$baseKey.json', TEXT)) hasAnim = true;
			if (Paths.fileExists('images/$baseKey.txt', TEXT)) hasAnim = true;

			if (!hasAnim)
			{
				showOutput(Language.get('stage_editor_mobile_sprite_anim_required'), true);
				return;
			}
		}

		insertMeta(new StageEditorMetaSprite({type: mobileSpriteType, name: findUnoccupiedName()}, new ModchartSprite()));

		var selected = getSelected();
		tryLoadImage(selected, baseKey);

		selected.sprite.x = Math.round(FlxG.camera.scroll.x + FlxG.width / 2 - selected.sprite.width / 2);
		selected.sprite.y = Math.round(FlxG.camera.scroll.y + FlxG.height / 2 - selected.sprite.height / 2);
		posTxt.visible = true;
		posTxt.text = Language.get('stage_editor_pos_x_y', [Std.string(selected.sprite.x), Std.string(selected.sprite.y)]);

		showOutput(Language.get('stage_editor_mobile_sprite_loaded', [baseKey]));

		mobileSpritePopup.visible = mobileSpritePopup.active = false;
	}

	function createMobileChangeImagePopup()
	{
		mobileChangeImgPopup = new FlxSpriteGroup();
		mobileChangeImgPopup.cameras = [camHUD];

		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.alpha = 0.7;
		bg.scale.set(340, 260);
		bg.updateHitbox();
		bg.screenCenter();
		mobileChangeImgPopup.add(bg);

		var titleTxt:FlxText = lbl(0, bg.y + 10, 300, Language.get('stage_editor_change_image'), 18);
		titleTxt.screenCenter(X);
		titleTxt.alignment = CENTER;
		mobileChangeImgPopup.add(titleTxt);

		var yPos = bg.y + 45;

		var pathLbl:FlxText = lbl(bg.x + 10, yPos, 300, Language.get('stage_editor_mobile_sprite_path'), 14);
		mobileChangeImgPopup.add(pathLbl);

		yPos += 22;

		mobileChangeImgInput = new PsychUIInputText(bg.x + 10, yPos, 310, '', 14);
		mobileChangeImgInput.cameras = [camHUD];
		mobileChangeImgPopup.add(mobileChangeImgInput);

		yPos += 36;

		mobileChangeImgFormatTxt = lbl(bg.x + 10, yPos, 310, Language.get('stage_editor_mobile_sprite_format'), 12);
		mobileChangeImgFormatTxt.color = 0xFFAAAAAA;
		mobileChangeImgPopup.add(mobileChangeImgFormatTxt);

		yPos += 40;

		var addBtn:PsychUIButton = new PsychUIButton(0, yPos, Language.get('stage_editor_mobile_sprite_add'), function() tryAndChangeMobileImage());
		addBtn.screenCenter(X);
		addBtn.normalStyle.bgColor = FlxColor.GREEN;
		addBtn.normalStyle.textColor = FlxColor.WHITE;
		mobileChangeImgPopup.add(addBtn);

		yPos += 50;

		var cancelBtn:PsychUIButton = new PsychUIButton(0, yPos, Language.get('stage_editor_prompt_cancel'), function() {
			mobileChangeImgPopup.visible = mobileChangeImgPopup.active = false;
		});
		cancelBtn.screenCenter(X);
		mobileChangeImgPopup.add(cancelBtn);

		add(mobileChangeImgPopup);
		mobileChangeImgPopup.visible = mobileChangeImgPopup.active = false;
	}

	function openMobileChangeImage()
	{
		var selected = getSelected();
		if (selected == null)
		{
			showOutput(Language.get('stage_editor_select_first'), true);
			return;
		}

		mobileChangeImgInput.text = '';
		if (mobileChangeImgFormatTxt != null)
		{
			mobileChangeImgFormatTxt.text = Language.get(selected.type == 'animatedSprite'
				? 'stage_editor_mobile_sprite_anim_required'
				: 'stage_editor_mobile_sprite_format');
		}

		mobileChangeImgPopup.visible = mobileChangeImgPopup.active = true;
	}

	function tryAndChangeMobileImage()
	{
		var selected = getSelected();
		if (selected == null)
		{
			showOutput(Language.get('stage_editor_select_first'), true);
			mobileChangeImgPopup.visible = mobileChangeImgPopup.active = false;
			return;
		}

		var inputPath:String = mobileChangeImgInput.text;
		if (inputPath == null || inputPath.trim().length == 0)
		{
			showOutput(Language.get('stage_editor_mobile_sprite_not_found', ['']), true);
			return;
		}

		var trimmedPath:String = inputPath.trim();
		if (trimmedPath.startsWith('images/'))
			trimmedPath = trimmedPath.substr('images/'.length);

		var lastDot:Int = trimmedPath.lastIndexOf('.');
		if (lastDot < 0)
		{
			showOutput(Language.get('stage_editor_mobile_sprite_invalid_ext'), true);
			return;
		}

		var ext:String = trimmedPath.substr(lastDot + 1).toLowerCase();
		var baseKey:String = trimmedPath.substr(0, lastDot);

		if (ext != 'png' && ext != 'xml' && ext != 'json' && ext != 'txt')
		{
			showOutput(Language.get('stage_editor_mobile_sprite_invalid_ext'), true);
			return;
		}

		var pngPath:String = 'images/$baseKey.png';
		if (!Paths.fileExists(pngPath, TEXT))
		{
			showOutput(Language.get('stage_editor_mobile_sprite_not_found', [pngPath]), true);
			return;
		}

		if (selected.type == 'animatedSprite')
		{
			var hasAnim:Bool = false;
			if (Paths.fileExists('images/$baseKey.xml', TEXT)) hasAnim = true;
			if (Paths.fileExists('images/$baseKey.json', TEXT)) hasAnim = true;
			if (Paths.fileExists('images/$baseKey.txt', TEXT)) hasAnim = true;

			if (!hasAnim)
			{
				showOutput(Language.get('stage_editor_mobile_sprite_anim_required'), true);
				return;
			}
		}

		tryLoadImage(selected, baseKey);

		posTxt.visible = true;
		posTxt.text = Language.get('stage_editor_pos_x_y', [Std.string(selected.sprite.x), Std.string(selected.sprite.y)]);

		showOutput(Language.get('stage_editor_mobile_sprite_loaded', [baseKey]));

		mobileChangeImgPopup.visible = mobileChangeImgPopup.active = false;
	}
	#end
	
	function updateSpriteListRadio()
	{
		var _sel:String = (spriteListRadioGroup.checkedRadio != null ? spriteListRadioGroup.checkedRadio.label : null);
		var nameList:Array<String> = [];
		for (spr in stageSprites)
		{
			if(spr == null) continue;

			switch(spr.type)
			{
				case 'gf':
					nameList.push(Language.get('stage_editor_sprite_list_gf'));
				case 'boyfriend':
					nameList.push(Language.get('stage_editor_sprite_list_bf'));
				case 'dad':
					nameList.push(Language.get('stage_editor_sprite_list_dad'));
				default:
					nameList.push(spr.name);
			}
		}
		nameList.reverse();
		
		spriteListRadioGroup.labels = nameList;
		for (radio in spriteListRadioGroup.radios)
		{
			if(radio.label == _sel)
			{
				spriteListRadioGroup.checkedRadio = radio;
				break;
			}
		}

		final maxNum:Int = 19;
		spriteList_box.resize(250, Std.int(Math.min(maxNum, spriteListRadioGroup.labels.length) * 25 + 35));

		#if mobile
		if (UI_stagebox != null)
		{
			UI_stagebox.y = spriteList_box.y + spriteList_box.height + 10;
		}
		#end
	}

	function editorUI()
	{
		#if mobile
		UI_stagebox = new PsychUIBox(25, spriteList_box.y + spriteList_box.height + 10, 250, 100, [Language.get('stage_editor_stage')]);
		UI_stagebox.cameras = [camHUD];
		UI_stagebox.scrollFactor.set();
		add(UI_stagebox);

		UI_box = new PsychUIBox(FlxG.width - 225, 70, 200, 400, [Language.get('stage_editor_meta'), Language.get('stage_editor_data'), Language.get('stage_editor_object')]);
		UI_box.cameras = [camHUD];
		UI_box.scrollFactor.set();
		add(UI_box);
		UI_box.selectedName = Language.get('stage_editor_data');
		#else
		UI_box = new PsychUIBox(FlxG.width - 225, 10, 200, 400, [Language.get('stage_editor_meta'), Language.get('stage_editor_data'), Language.get('stage_editor_object')]);
		UI_box.cameras = [camHUD];
		UI_box.scrollFactor.set();
		add(UI_box);
		UI_box.selectedName = Language.get('stage_editor_data');

		UI_stagebox = new PsychUIBox(FlxG.width - 275, 25, 250, 100, [Language.get('stage_editor_stage')]);
		UI_stagebox.cameras = [camHUD];
		UI_stagebox.scrollFactor.set();
		add(UI_stagebox);
		UI_box.y += UI_stagebox.y + UI_stagebox.height;
		#end

		addDataTab();
		addObjectTab();
		addMetaTab();
		addStageTab();
	}

	var directoryDropDown:PsychUIDropDownMenu;
	var uiInputText:PsychUIInputText;
	var hideGirlfriendCheckbox:PsychUICheckBox;
	var zoomStepper:PsychUINumericStepper;
	var cameraSpeedStepper:PsychUINumericStepper;
	var camDadStepperX:PsychUINumericStepper;
	var camDadStepperY:PsychUINumericStepper;
	var camGfStepperX:PsychUINumericStepper;
	var camGfStepperY:PsychUINumericStepper;
	var camBfStepperX:PsychUINumericStepper;
	var camBfStepperY:PsychUINumericStepper;

	function addDataTab()
	{
		var tab_group = UI_box.getTab(Language.get('stage_editor_data')).menu;

		var objX = 10;
		var objY = 20;
		tab_group.add(lbl(objX, objY - 18, 150, Language.get('stage_editor_compiled_assets')));

		var folderList:Array<String> = [''];
		#if sys
		for (folder in Paths.readDirectory('assets/'))
			if(FileSystem.isDirectory('assets/$folder') && folder != 'shared' && !Mods.ignoreModFolders.contains(folder))
				folderList.push(folder);
		#end

		var saveButton:PsychUIButton = new PsychUIButton(UI_box.width - 90, UI_box.height - 50, Language.get('stage_editor_save'), function() {
			saveData();
		});
		tab_group.add(saveButton);

		directoryDropDown = new PsychUIDropDownMenu(objX, objY, folderList, function(sel:Int, selected:String) {
			stageJson.directory = selected;
			saveObjectsToJson();
			FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new StageEditorState(lastLoadedStage, stageJson));
		});
		directoryDropDown.selectedLabel = stageJson.directory;

		objY += 50;
		tab_group.add(lbl(objX, objY - 18, 100, Language.get('stage_editor_ui_style')));
		uiInputText = new PsychUIInputText(objX, objY, 100, stageJson.stageUI != null ? stageJson.stageUI : '', 12);
		uiInputText.onChange = function(old:String, cur:String) stageJson.stageUI = uiInputText.text;

		objY += 30;
		hideGirlfriendCheckbox = new PsychUICheckBox(objX, objY, Language.get('stage_editor_hide_girlfriend'), 130);
		hideGirlfriendCheckbox.onClick = function()
		{
			stageJson.hide_girlfriend = hideGirlfriendCheckbox.checked;
			gf.visible = !hideGirlfriendCheckbox.checked;
			if(focusRadioGroup.checked > -1)
			{
				var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
				camFollow.setPosition(point.x, point.y);
			}
		};
		hideGirlfriendCheckbox.checked = !gf.visible;

		objY += 50;
		tab_group.add(lbl(objX, objY - 18, 100, Language.get('stage_editor_camera_offsets')));

		objY += 20;
		tab_group.add(lbl(objX, objY - 18, 100, Language.get('stage_editor_opponent')));

		var cx:Float = 0;
		var cy:Float = 0;
		if(stageJson.camera_opponent != null && stageJson.camera_opponent.length > 1)
		{
			cx = stageJson.camera_opponent[0];
			cy = stageJson.camera_opponent[1];
		}
		camDadStepperX = new PsychUINumericStepper(objX, objY, 50, cx, -10000, 10000, 0);
		camDadStepperY = new PsychUINumericStepper(objX + 80, objY, 50, cy, -10000, 10000, 0);
		camDadStepperX.onValueChange = camDadStepperY.onValueChange = function() {
			if(stageJson.camera_opponent == null) stageJson.camera_opponent = [0, 0];
			stageJson.camera_opponent[0] = camDadStepperX.value;
			stageJson.camera_opponent[1] = camDadStepperY.value;
			_updateCamera();
		};

		objY += 40;
		var cx:Float = 0;
		var cy:Float = 0;
		if(stageJson.camera_girlfriend != null && stageJson.camera_girlfriend.length > 1)
		{
			cx = stageJson.camera_girlfriend[0];
			cy = stageJson.camera_girlfriend[1];
		}
		tab_group.add(lbl(objX, objY - 18, 100, Language.get('stage_editor_girlfriend')));
		camGfStepperX = new PsychUINumericStepper(objX, objY, 50, cx, -10000, 10000, 0);
		camGfStepperY = new PsychUINumericStepper(objX + 80, objY, 50, cy, -10000, 10000, 0);
		camGfStepperX.onValueChange = camGfStepperY.onValueChange = function() {
			if(stageJson.camera_girlfriend == null) stageJson.camera_girlfriend = [0, 0];
			stageJson.camera_girlfriend[0] = camGfStepperX.value;
			stageJson.camera_girlfriend[1] = camGfStepperY.value;
			_updateCamera();
		};

		objY += 40;
		var cx:Float = 0;
		var cy:Float = 0;
		if(stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
		{
			cx = stageJson.camera_boyfriend[0];
			cy = stageJson.camera_boyfriend[1];
		}
		tab_group.add(lbl(objX, objY - 18, 100, Language.get('stage_editor_boyfriend')));
		camBfStepperX = new PsychUINumericStepper(objX, objY, 50, cx, -10000, 10000, 0);
		camBfStepperY = new PsychUINumericStepper(objX + 80, objY, 50, cy, -10000, 10000, 0);
		camBfStepperX.onValueChange = camBfStepperY.onValueChange = function() {
			if(stageJson.camera_boyfriend == null) stageJson.camera_boyfriend = [0, 0];
			stageJson.camera_boyfriend[0] = camBfStepperX.value;
			stageJson.camera_boyfriend[1] = camBfStepperY.value;
			_updateCamera();
		};

		objY += 50;
		tab_group.add(lbl(objX, objY - 18, 100, Language.get('stage_editor_camera_data')));
		objY += 20;
		tab_group.add(lbl(objX, objY - 18, 100, Language.get('stage_editor_zoom')));
		zoomStepper = new PsychUINumericStepper(objX, objY, 0.05, stageJson.defaultZoom, minZoom, maxZoom, 2);
		zoomStepper.onValueChange = function() {
			stageJson.defaultZoom = zoomStepper.value;
			FlxG.camera.zoom = stageJson.defaultZoom;
		};

		tab_group.add(lbl(objX + 80, objY - 18, 100, Language.get('stage_editor_speed')));
		cameraSpeedStepper = new PsychUINumericStepper(objX + 80, objY, 0.1, stageJson.camera_speed != null ? stageJson.camera_speed : 1, 0, 10, 2);
		cameraSpeedStepper.onValueChange = function() {
			stageJson.camera_speed = cameraSpeedStepper.value;
			FlxG.camera.followLerp = 0.04 * stageJson.camera_speed;
		};
		FlxG.camera.followLerp = 0.04 * cameraSpeedStepper.value;

		tab_group.add(hideGirlfriendCheckbox);
		tab_group.add(camDadStepperX);
		tab_group.add(camDadStepperY);
		tab_group.add(camGfStepperX);
		tab_group.add(camGfStepperY);
		tab_group.add(camBfStepperX);
		tab_group.add(camBfStepperY);
		tab_group.add(zoomStepper);
		tab_group.add(cameraSpeedStepper);
		
		tab_group.add(uiInputText);
		tab_group.add(directoryDropDown);
	}
	
	function _updateCamera()
	{
		if(focusRadioGroup.checked > -1)
		{
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
		}
	}

	var colorInputText:PsychUIInputText;
	var nameInputText:PsychUIInputText;
	var imgTxt:FlxText;

	var scaleStepperX:PsychUINumericStepper;
	var scaleStepperY:PsychUINumericStepper;
	var scrollStepperX:PsychUINumericStepper;
	var scrollStepperY:PsychUINumericStepper;
	var angleStepper:PsychUINumericStepper;
	var alphaStepper:PsychUINumericStepper;

	var antialiasingCheckbox:PsychUICheckBox;
	var flipXCheckBox:PsychUICheckBox;
	var flipYCheckBox:PsychUICheckBox;
	var lowQualityCheckbox:PsychUICheckBox;
	var highQualityCheckbox:PsychUICheckBox;

	function getSelected(blockReserved:Bool = true)
	{
		var selected:Int = spriteListRadioGroup.checked;
		if(selected >= 0)
		{
			var spr = stageSprites[spriteListRadioGroup.labels.length - selected - 1];
			if(spr != null && (!blockReserved || !StageData.reservedNames.contains(spr.type)))
				return spr;
		}
		return null;
	}

	function addObjectTab()
	{
		var tab_group = UI_box.getTab(Language.get('stage_editor_object')).menu;

		var objX = 10;
		var objY = 30;
		tab_group.add(lbl(objX, objY - 18, 280, Language.get('stage_editor_lua_hscript_name')));
		nameInputText = new PsychUIInputText(objX, objY, 120, '', 12);
		nameInputText.customFilterPattern = ~/[^a-zA-Z0-9_\-]*/g;
		nameInputText.onChange = function(old:String, cur:String) {
			// change name
			var selected = getSelected();
			if(selected != null)
			{
				var changedName:String = nameInputText.text;
				if(changedName.length < 1)
				{
					showOutput(Language.get('stage_editor_sprite_name_cannot_be_empty'), true);
					return;
				}
				
				if(StageData.reservedNames.contains(changedName))
				{
					showOutput(Language.get('stage_editor_name_cannot_be_used'), true);
					return;
				}

				for (basic in stageSprites)
				{
					if (selected != basic && basic.name == changedName)
					{
						showOutput(Language.get('stage_editor_name_already_in_use', [changedName]), true);
						return;
					}
				}

				selected.name = changedName;
				spriteListRadioGroup.checkedRadio.label = selected.name;
				outputTime = 0;
				outputTxt.alpha = 0;
			}
		};
		tab_group.add(nameInputText);

		objY += 35;
		imgTxt = lbl(objX, objY - 15, 140, Language.get('stage_editor_image'));
		var imgButton:PsychUIButton = new PsychUIButton(objX, objY, Language.get('stage_editor_change_image'), function() {
			#if mobile
			openMobileChangeImage();
			#else
			trace('attempt to load image');
			loadImage();
			#end
		});
		tab_group.add(imgButton);
		tab_group.add(imgTxt);
		
		var animationsButton:PsychUIButton = new PsychUIButton(objX + 90, objY, Language.get('stage_editor_animations'), function() {
			var selected = getSelected();
			if(selected == null)
			{
				showOutput(Language.get('stage_editor_select_first'), true);
				return;
			}

			if(selected.type != 'animatedSprite')
			{
				showOutput(Language.get('stage_editor_only_animated_can_hold_anim'), true);
				return;
			}

			destroySubStates = persistentUpdate = persistentDraw = false;
			animationEditor.target = selected;
			unsavedProgress = true;
			removeTouchPad();
			openSubState(animationEditor);
		});
		tab_group.add(animationsButton);
		
		objY += 45;
		tab_group.add(lbl(objX, objY - 18, 80, Language.get('stage_editor_color')));
		colorInputText = new PsychUIInputText(objX, objY, 80, 'FFFFFF', 12);
		colorInputText.filterMode = ONLY_ALPHANUMERIC;
		colorInputText.onChange = function(old:String, cur:String) {
			// change color
			var selected = getSelected();
			if(selected != null)
				selected.color = colorInputText.text;
		};
		tab_group.add(colorInputText);

		function updateScale()
		{
			// scale
			var selected = getSelected();
			if(selected != null)
				selected.setScale(scaleStepperX.value, scaleStepperY.value);
		}
		
		objY += 45;
		tab_group.add(lbl(objX, objY - 18, 100, Language.get('stage_editor_scale')));
		scaleStepperX = new PsychUINumericStepper(objX, objY, 0.05, 1, 0.05, 10, 2);
		scaleStepperY = new PsychUINumericStepper(objX + 70, objY, 0.05, 1, 0.05, 10, 2);
		scaleStepperX.onValueChange = scaleStepperY.onValueChange = updateScale;
		tab_group.add(scaleStepperX);
		tab_group.add(scaleStepperY);

		function updateScroll()
		{
			// scroll factor
			var selected = getSelected();
			if(selected != null)
				selected.setScrollFactor(scrollStepperX.value, scrollStepperY.value);
		}

		objY += 40;
		tab_group.add(lbl(objX, objY - 18, 150, Language.get('stage_editor_scroll_factor')));
		scrollStepperX = new PsychUINumericStepper(objX, objY, 0.05, 1, 0, 10, 2);
		scrollStepperY = new PsychUINumericStepper(objX + 70, objY, 0.05, 1, 0, 10, 2);
		scrollStepperX.onValueChange = scrollStepperY.onValueChange = updateScroll;
		tab_group.add(scrollStepperX);
		tab_group.add(scrollStepperY);
		
		objY += 40;
		tab_group.add(lbl(objX, objY - 18, 80, Language.get('stage_editor_opacity')));
		alphaStepper = new PsychUINumericStepper(objX, objY, 0.1, 1, 0, 1, 2, true);
		alphaStepper.onValueChange = function() {
			// alpha/opacity
			var selected = getSelected();
			if(selected != null)
				selected.alpha = alphaStepper.value;
		};
		tab_group.add(alphaStepper);

		antialiasingCheckbox = new PsychUICheckBox(objX + 90, objY, Language.get('stage_editor_anti_aliasing'), 100);
		antialiasingCheckbox.onClick = function()
		{
			// antialiasing
			var selected = getSelected();
			if(selected != null)
			{
				if(selected.type != 'square')
					selected.antialiasing = antialiasingCheckbox.checked;
				else
				{
					antialiasingCheckbox.checked = false;
					selected.antialiasing = false;
				}
			}
		};
		tab_group.add(antialiasingCheckbox);

		objY += 40;
		tab_group.add(lbl(objX, objY - 18, 80, Language.get('stage_editor_angle')));
		angleStepper = new PsychUINumericStepper(objX, objY, 10, 0, 0, 360, 0);
		angleStepper.onValueChange = function() {
			// alpha/opacity
			var selected = getSelected();
			if(selected != null)
				selected.angle = angleStepper.value;
		};
		tab_group.add(angleStepper);

		function updateFlip()
		{
			//flip X and flip Y
			var selected = getSelected();
			if(selected != null)
			{
				if(selected.type != 'square')
				{
					selected.flipX = flipXCheckBox.checked;
					selected.flipY = flipYCheckBox.checked;
				}
				else
				{
					flipXCheckBox.checked = flipYCheckBox.checked = false;
					selected.flipX = selected.flipY = false;
				}
			}
		}

		objY += 25;
		flipXCheckBox = new PsychUICheckBox(objX, objY, Language.get('stage_editor_flip_x'), 80);
		flipXCheckBox.onClick = updateFlip;
		flipYCheckBox = new PsychUICheckBox(objX + 100, objY, Language.get('stage_editor_flip_y'), 80);
		flipYCheckBox.onClick = updateFlip;
		tab_group.add(flipXCheckBox);
		tab_group.add(flipYCheckBox);

		objY += 45;
		function recalcFilter()
		{
			// low and/or high quality
			var selected = getSelected();
			if(selected != null)
			{
				var filt = 0;
				if(lowQualityCheckbox.checked) filt |= LOW_QUALITY;
				if(highQualityCheckbox.checked) filt |= HIGH_QUALITY;
				selected.filters = filt;
			}
		};
		tab_group.add(lbl(objX, objY - 18, 100, Language.get('stage_editor_visible_in')));
		lowQualityCheckbox = new PsychUICheckBox(objX, objY, Language.get('stage_editor_low_quality'), 100);
		highQualityCheckbox = new PsychUICheckBox(objX + 110, objY, Language.get('stage_editor_high_quality'), 100);
		lowQualityCheckbox.onClick = recalcFilter;
		highQualityCheckbox.onClick = recalcFilter;
		tab_group.add(lowQualityCheckbox);
		tab_group.add(highQualityCheckbox);
	}

	var oppDropdown:PsychUIDropDownMenu;
	var gfDropdown:PsychUIDropDownMenu;
	var plDropdown:PsychUIDropDownMenu;
	function addMetaTab()
	{
		var tab_group = UI_box.getTab(Language.get('stage_editor_meta')).menu;

		var characterList = Mods.mergeAllTextsNamed('data/characterList.txt');
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'characters/');
		for (folder in foldersToCheck)
			for (file in Paths.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
				{
					var charToCheck:String = file.substr(0, file.length - 5);
					if(!characterList.contains(charToCheck))
						characterList.push(charToCheck);
				}

		if(characterList.length < 1) characterList.push(''); //Prevents crash
		
		var objX = 10;
		var objY = 20;

		var openPreloadButton:PsychUIButton = new PsychUIButton(objX, objY, Language.get('stage_editor_preload_list'), function() {
			var lockedList:Array<String> = [];
			var currentMap:Map<String, LoadFilters> = [];
			for (spr in stageSprites)
			{
				if(spr == null || StageData.reservedNames.contains(spr.type)) continue;

				switch(spr.type)
				{
					case 'sprite', 'animatedSprite':
						if(spr.image != null && spr.image.length > 0 && !lockedList.contains(spr.image))
							lockedList.push(spr.image);
				}
			}

			if(stageJson.preload != null)
			{
				for (field in Reflect.fields(stageJson.preload))
				{
					if(!currentMap.exists(field) && !lockedList.contains(field))
						currentMap.set(field, Reflect.field(stageJson.preload, field));
				}
			}

			destroySubStates = true;
			openSubState(new PreloadListSubState(function(newSave:Map<String, LoadFilters>)
			{
				var len:Int = 0;
				for (name in newSave.keys())
					len++;

				stageJson.preload = {};
				for (key => value in newSave)
				{
					Reflect.setField(stageJson.preload, key, value);
				}
				unsavedProgress = true;
				showOutput(Language.get('stage_editor_saved_preload_list', [Std.string(len)]));
			}, lockedList, currentMap));
		});

		function setMetaData(data:String, char:String)
		{
			if(stageJson._editorMeta == null) stageJson._editorMeta = {dad: 'dad', gf: 'gf', boyfriend: 'bf'};
			Reflect.setField(stageJson._editorMeta, data, char);
		}

		objY += 60;
		oppDropdown = new PsychUIDropDownMenu(objX, objY, characterList, function(sel:Int, selected:String)
		{
			if(selected == null || selected.length < 1) return;
			dad.changeCharacter(selected);
			setMetaData('dad', selected);
			repositionDad();
		});
		oppDropdown.selectedLabel = dad.curCharacter;

		objY += 60;
		gfDropdown = new PsychUIDropDownMenu(objX, objY, characterList, function(sel:Int, selected:String)
		{
			if(selected == null || selected.length < 1) return;
			gf.changeCharacter(selected);
			setMetaData('gf', selected);
			repositionGirlfriend();
		});
		gfDropdown.selectedLabel = gf.curCharacter;

		objY += 60;
		plDropdown = new PsychUIDropDownMenu(objX, objY, characterList, function(sel:Int, selected:String)
		{
			if(selected == null || selected.length < 1) return;
			boyfriend.changeCharacter(selected);
			setMetaData('boyfriend', selected);
			repositionBoyfriend();
		});
		plDropdown.selectedLabel = boyfriend.curCharacter;

		tab_group.add(openPreloadButton);
		tab_group.add(lbl(plDropdown.x, plDropdown.y - 18, 100, Language.get('stage_editor_player')));
		tab_group.add(plDropdown);
		tab_group.add(lbl(gfDropdown.x, gfDropdown.y - 18, 100, Language.get('stage_editor_girlfriend')));
		tab_group.add(gfDropdown);
		tab_group.add(lbl(oppDropdown.x, oppDropdown.y - 18, 100, Language.get('stage_editor_opponent')));
		tab_group.add(oppDropdown);
	}

	var stageDropDown:PsychUIDropDownMenu;
	function addStageTab()
	{
		var tab_group = UI_stagebox.getTab(Language.get('stage_editor_stage')).menu;
		var reloadStage:PsychUIButton = new PsychUIButton(140, 10, Language.get('stage_editor_reload'), function()
		{
			#if DISCORD_ALLOWED
			DiscordClient.changePresence('Stage Editor', 'Stage: ' + lastLoadedStage);
			#end

			stageJson = StageData.getStageFile(lastLoadedStage);
			updateSpriteList();
			updateStageDataUI();
			reloadCharacters();
			reloadStageDropDown();
		});

		var dummyStage:PsychUIButton = new PsychUIButton(140, 40, Language.get('stage_editor_load_template'), function()
		{
			#if DISCORD_ALLOWED
			DiscordClient.changePresence('Stage Editor', 'New Stage');
			#end

			stageJson = StageData.dummy();
			updateSpriteList();
			updateStageDataUI();
			reloadCharacters();
		});
		dummyStage.normalStyle.bgColor = FlxColor.RED;
		dummyStage.normalStyle.textColor = FlxColor.WHITE;

		stageDropDown = new PsychUIDropDownMenu(10, 30, [''], function(sel:Int, selected:String)
		{			var characterPath:String = 'stages/$selected.json';
			var path:String = Paths.getPath(characterPath, TEXT, null, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(path))
			#else
			if (Assets.exists(path))
			#end
			{
				stageJson = StageData.getStageFile(selected);
				lastLoadedStage = selected;
				#if DISCORD_ALLOWED
				DiscordClient.changePresence('Stage Editor', 'Stage: ' + lastLoadedStage);
				#end
				updateSpriteList();
				updateStageDataUI();
				reloadCharacters();
				reloadStageDropDown();
			}
			else
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadStageDropDown();
			}
		});
		reloadStageDropDown();

		tab_group.add(lbl(stageDropDown.x, stageDropDown.y - 18, 60, Language.get('stage_editor_stage')));
		tab_group.add(reloadStage);
		tab_group.add(dummyStage);
		tab_group.add(stageDropDown);
	}
	
	function updateStageDataUI()
	{
		//input texts
		uiInputText.text = (stageJson.stageUI != null ? stageJson.stageUI : '');
		//checkboxes
		hideGirlfriendCheckbox.checked = (stageJson.hide_girlfriend);
		gf.visible = !hideGirlfriendCheckbox.checked;
		//steppers
		zoomStepper.value = FlxG.camera.zoom = stageJson.defaultZoom;
		
		if(stageJson.camera_speed != null) cameraSpeedStepper.value = stageJson.camera_speed;
		else cameraSpeedStepper.value = 1;
		FlxG.camera.followLerp = 0.04 * cameraSpeedStepper.value;

		if(stageJson.camera_opponent != null && stageJson.camera_opponent.length > 1)
		{
			camDadStepperX.value = stageJson.camera_opponent[0];
			camDadStepperY.value = stageJson.camera_opponent[1];
		}
		else camDadStepperX.value = camDadStepperY.value = 0;

		if(stageJson.camera_girlfriend != null && stageJson.camera_girlfriend.length > 1)
		{
			camGfStepperX.value = stageJson.camera_girlfriend[0];
			camGfStepperY.value = stageJson.camera_girlfriend[1];
		}
		else camGfStepperX.value = camGfStepperY.value = 0;

		if(stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
		{
			camBfStepperX.value = stageJson.camera_boyfriend[0];
			camBfStepperY.value = stageJson.camera_boyfriend[1];
		}
		else camBfStepperX.value = camBfStepperY.value = 0;

		if(focusRadioGroup.checked > -1)
		{
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
		}
		loadJsonAssetDirectory();
	}

	function updateSelectedUI()
	{
		posTxt.visible = false;
		var selected = getSelected(false);
		if(selected == null) return;

		var displayX:Float = Math.round(selected.x);
		var displayY:Float = Math.round(selected.y);
		
		var char:Character = cast selected.sprite;
		if(char != null)
		{
			displayX -= char.positionArray[0];
			displayY -= char.positionArray[1];
		}

		posTxt.text = Language.get('stage_editor_pos_x_y', [Std.string(displayX), Std.string(displayY)]);
		posTxt.visible = true;

		var selected = getSelected();
		if(selected == null) return;

		// Texts/Input Texts
		colorInputText.text = selected.color;
		nameInputText.text = selected.name;
		imgTxt.text = 'Image: ' + selected.image;
		// Auto-expand imgTxt to prevent wrapping for long image paths
		var lineH:Float = 12 * 1.3; // Estimate line height (font size 12)
		var w:Int = 140;
		while (imgTxt.height > lineH && w < 2000)
		{
			w += 20;
			imgTxt.fieldWidth = w;
		}

		// Steppers
		if (selected.type != 'square')
		{
			scaleStepperX.decimals = scaleStepperY.decimals = 2;
			scaleStepperX.max = scaleStepperY.max = 10;
			scaleStepperX.min = scaleStepperY.min = 0.05;
			scaleStepperX.step = scaleStepperY.step = 0.05;
		}
		else
		{
			scaleStepperX.decimals = scaleStepperY.decimals = 0;
			scaleStepperX.max = scaleStepperY.max = 10000;
			scaleStepperX.min = scaleStepperY.min = 50;
			scaleStepperX.step = scaleStepperY.step = 50;
		}
		scaleStepperX.value = selected.scale[0];
		scaleStepperY.value = selected.scale[1];
		scrollStepperX.value = selected.scroll[0];
		scrollStepperY.value = selected.scroll[1];
		angleStepper.value = selected.angle;
		alphaStepper.value = selected.alpha;

		// Checkboxes
		antialiasingCheckbox.checked = selected.antialiasing;
		flipXCheckBox.checked = selected.flipX;
		flipYCheckBox.checked = selected.flipY;
		lowQualityCheckbox.checked = (selected.filters & LOW_QUALITY) == LOW_QUALITY;
		highQualityCheckbox.checked = (selected.filters & HIGH_QUALITY) == HIGH_QUALITY;
	}

	function reloadCharacters()
	{
		if(stageJson._editorMeta != null)
		{
			gf.changeCharacter(stageJson._editorMeta.gf);
			dad.changeCharacter(stageJson._editorMeta.dad);
			boyfriend.changeCharacter(stageJson._editorMeta.boyfriend);
		}
		repositionGirlfriend();
		repositionDad();
		repositionBoyfriend();

		focusRadioGroup.checked = -1;
		FlxG.camera.target = null;
		var point = focusOnTarget('boyfriend');
		FlxG.camera.scroll.set(point.x - FlxG.width/2, point.y - FlxG.height/2);
		FlxG.camera.zoom = stageJson.defaultZoom;
		oppDropdown.selectedLabel = dad.curCharacter;
		gfDropdown.selectedLabel = gf.curCharacter;
		plDropdown.selectedLabel = boyfriend.curCharacter;
	}
	
	function reloadStageDropDown()
	{
		var stageList:Array<String> = [];
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'stages/');
		for (folder in foldersToCheck)
			for (file in Paths.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
				{
					var stageToCheck:String = file.substr(0, file.length - '.json'.length);
					if(!stageList.contains(stageToCheck))
						stageList.push(stageToCheck);
				}

		if(stageList.length < 1) stageList.push('');
		stageDropDown.list = stageList;
		stageDropDown.selectedLabel = lastLoadedStage;
		directoryDropDown.selectedLabel = stageJson.directory;
	}

	function checkUIOnObject()
	{
		if(UI_box.selectedName == Language.get('stage_editor_object'))
		{
			var selected:Int = spriteListRadioGroup.checked;
			if(selected >= 0)
			{
				var spr = stageSprites[spriteListRadioGroup.labels.length - selected - 1];
				if(spr != null && StageData.reservedNames.contains(spr.type))
					UI_box.selectedName = Language.get('stage_editor_data');
			}
			else UI_box.selectedName = Language.get('stage_editor_data');
		}
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		switch(id)
		{
			case PsychUIRadioGroup.CLICK_EVENT, PsychUIBox.CLICK_EVENT:
				if(sender == spriteListRadioGroup || sender == UI_box)
					checkUIOnObject();
				
			case PsychUICheckBox.CLICK_EVENT:
				unsavedProgress = true;

			case PsychUIInputText.CHANGE_EVENT, PsychUINumericStepper.CHANGE_EVENT:
				unsavedProgress = true;
		}
	}

	override function closeSubState()
	{
		super.closeSubState();
		controls.isInSubstate = false;
		removeTouchPad();
		addTouchPad('LEFT_FULL', 'CHARACTER_EDITOR');
		addTouchPadCamera();
		persistentUpdate = true;
	}

	var outputTime:Float = 0;
	override function update(elapsed:Float)
	{
		if(createPopup.visible && (FlxG.mouse.justPressedRight || (FlxG.mouse.justPressed && !FlxG.mouse.overlaps(createPopup, camHUD))))
			createPopup.visible = createPopup.active = false;

		for (basic in stageSprites)
			basic.update(curFilters, elapsed);

		super.update(elapsed);
		
		outputTime = Math.max(0, outputTime - elapsed);
		outputTxt.alpha = outputTime;

		if(PsychUIInputText.focusOn != null) return;

		var tp:TouchPad = touchPad;
		var hasTouch:Bool = (tp != null);

		if(FlxG.keys.justPressed.ESCAPE || (hasTouch && tp.buttonB.justPressed))
		{
			if(!unsavedProgress)
			{
				MusicBeatState.switchState(new states.editors.MasterEditorMenu());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
			}
			else openSubState(new ExitConfirmationPrompt());
			return;
		}

		if(FlxG.keys.justPressed.W || (hasTouch && tp.buttonV.justPressed))
		{
			spriteListRadioGroup.checked = FlxMath.wrap(spriteListRadioGroup.checked - 1, 0, spriteListRadioGroup.labels.length-1);
			trace(spriteListRadioGroup.checked);
			checkUIOnObject();
			updateSelectedUI();
		}
		else if(FlxG.keys.justPressed.S || (hasTouch && tp.buttonD.justPressed))
		{
			spriteListRadioGroup.checked = FlxMath.wrap(spriteListRadioGroup.checked + 1, 0, spriteListRadioGroup.labels.length-1);
			trace(spriteListRadioGroup.checked);
			checkUIOnObject();
			updateSelectedUI();
		}

		if((FlxG.keys.justPressed.F1 || (hasTouch && tp.buttonF.justPressed)) || (helpBg.visible && FlxG.keys.justPressed.ESCAPE))
		{
			if (controls.mobileC && hasTouch)
			{
				tp.forEachAlive(function(button:TouchButton)
				{
					if(button.tag != 'F')
						button.visible = !button.visible;
				});
			}
			helpBg.visible = !helpBg.visible;
			helpTexts.visible = helpBg.visible;
		}

		if(#if FLX_DEBUG FlxG.keys.justPressed.F3 #else FlxG.keys.justPressed.F2 #end || (hasTouch && tp.buttonS.justPressed && !tp.buttonF.justPressed))
		{
			UI_box.visible = !UI_box.visible;
			UI_box.active = !UI_box.active;

			if (controls.mobileC && hasTouch)
			{
				tp.forEachAlive(function(button:TouchButton)
				{
					if(button.tag != 'S')
						button.visible = !button.visible;
				});
			}

			var objs = [UI_stagebox, spriteListRadioGroup, spriteList_box];
			for (obj in objs)
			{
				obj.visible = UI_box.visible;
				if(!(obj is FlxText)) obj.active = UI_box.active;
			}
			spriteListRadioGroup.updateRadioItems();
		}
		
		if(FlxG.keys.justPressed.F12 || (hasTouch && tp.buttonS.justPressed && !tp.buttonG.justPressed))
			showSelectionQuad = !showSelectionQuad;
		
		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		if(FlxG.keys.pressed.SHIFT || (hasTouch && tp.buttonC.pressed)) shiftMult = 4;
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		// CAMERA CONTROLS
		var camX:Float = 0;
		var camY:Float = 0;
		var camMove:Float = elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.J || (hasTouch && tp.buttonLeft.pressed && tp.buttonG.pressed)) camX -= camMove;
		if (FlxG.keys.pressed.K || (hasTouch && tp.buttonDown.pressed && tp.buttonG.pressed)) camY += camMove;
		if (FlxG.keys.pressed.L || (hasTouch && tp.buttonRight.pressed && tp.buttonG.pressed)) camX += camMove;
		if (FlxG.keys.pressed.I || (hasTouch && tp.buttonUp.pressed && tp.buttonG.pressed)) camY -= camMove;

		if(camX != 0 || camY != 0)
		{
			FlxG.camera.scroll.x += camX;
			FlxG.camera.scroll.y += camY;
			if(FlxG.camera.target != null) FlxG.camera.target = null;
			if(focusRadioGroup.checked > -1) focusRadioGroup.checked = -1;
		}

		var lastZoom = FlxG.camera.zoom;
		if(FlxG.keys.justPressed.R || (hasTouch && tp.buttonZ.justPressed && !FlxG.keys.pressed.CONTROL))
			FlxG.camera.zoom = stageJson.defaultZoom;
		else if (FlxG.keys.pressed.E || (hasTouch && tp.buttonX.pressed && FlxG.camera.zoom < maxZoom))
			FlxG.camera.zoom = Math.min(maxZoom, FlxG.camera.zoom + elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
		else if (FlxG.keys.pressed.Q || (hasTouch && tp.buttonY.pressed && FlxG.camera.zoom > minZoom))
			FlxG.camera.zoom = Math.max(minZoom, FlxG.camera.zoom - elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
		
		// SPRITE X/Y
		shiftMult = 1;
		ctrlMult = 1;
		if(FlxG.keys.pressed.SHIFT || (hasTouch && tp.buttonC.pressed)) shiftMult = 4;
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.2;

		var moveX:Float = 0;
		var moveY:Float = 0;
		if (!hasTouch || !tp.buttonG.pressed) {
		if (FlxG.keys.justPressed.LEFT || (hasTouch && tp.buttonLeft.justPressed)) moveX -= 5 * shiftMult * ctrlMult;
		if (FlxG.keys.justPressed.RIGHT || (hasTouch && tp.buttonRight.justPressed)) moveX += 5 * shiftMult * ctrlMult;
		if (FlxG.keys.justPressed.UP || (hasTouch && tp.buttonUp.justPressed)) moveY -= 5 * shiftMult * ctrlMult;
		if (FlxG.keys.justPressed.DOWN || (hasTouch && tp.buttonDown.justPressed)) moveY += 5 * shiftMult * ctrlMult;
		}

		if(FlxG.mouse.pressedRight && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0))
		{
			moveX += FlxG.mouse.deltaScreenX * ctrlMult;
			moveY += FlxG.mouse.deltaScreenY * ctrlMult;
			_updateCamera();
		}

		if(moveX != 0 || moveY != 0)
		{
			var selected:Int = spriteListRadioGroup.checked;
			if(selected < 0) return;

			var spr = stageSprites[spriteListRadioGroup.labels.length - selected - 1];
			if(spr != null)
			{
				var displayX:Float, displayY:Float;
				spr.x = displayX = Math.round(spr.x + moveX);
				spr.y = displayY = Math.round(spr.y + moveY);
				var char:Character = cast spr.sprite;
				switch(spr.type)
				{
					case 'boyfriend':
						stageJson.boyfriend[0] = displayX = spr.x - char.positionArray[0];
						stageJson.boyfriend[1] = displayY = spr.y - char.positionArray[1];
					case 'gf':
						stageJson.girlfriend[0] = displayX = spr.x - char.positionArray[0];
						stageJson.girlfriend[1] = displayY = spr.y - char.positionArray[1];
					case 'dad':
						stageJson.opponent[0] = displayX = spr.x - char.positionArray[0];
						stageJson.opponent[1] = displayY = spr.y - char.positionArray[1];
				}
				posTxt.text = Language.get('stage_editor_pos_x_y', [Std.string(displayX), Std.string(displayY)]);
			}
		}
	}

	var curFilters:LoadFilters = (LOW_QUALITY)|(HIGH_QUALITY);
	override function draw()
	{
		if(persistentDraw || subState == null)
		{

			for (basic in stageSprites)
				if(basic.visible)
					basic.draw(curFilters);
	
			if(showSelectionQuad && spriteListRadioGroup.checkedRadio != null)
			{
				var spr = stageSprites[spriteListRadioGroup.labels.length - spriteListRadioGroup.checked - 1];
				if(spr != null) drawDebugOnCamera(spr.sprite);
			}
		}

		super.draw();
	}

	function focusOnTarget(target:String)
	{
		var focusPoint:FlxPoint = FlxPoint.weak(0, 0);
		switch(target)
		{
			case 'boyfriend':
				focusPoint.x += boyfriend.getMidpoint().x - boyfriend.cameraPosition[0] - 100;
				focusPoint.y += boyfriend.getMidpoint().y + boyfriend.cameraPosition[1] - 100;
				if(stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
				{
					focusPoint.x += stageJson.camera_boyfriend[0];
					focusPoint.y += stageJson.camera_boyfriend[1];
				}
			case 'dad':
				focusPoint.x += dad.getMidpoint().x + dad.cameraPosition[0] + 150;
				focusPoint.y += dad.getMidpoint().y + dad.cameraPosition[1] - 100;
				if(stageJson.camera_opponent != null && stageJson.camera_opponent.length > 1)
				{
					focusPoint.x += stageJson.camera_opponent[0];
					focusPoint.y += stageJson.camera_opponent[1];
				}
			case 'gf':
				if(gf.visible)
				{
					focusPoint.x += gf.getMidpoint().x + gf.cameraPosition[0];
					focusPoint.y += gf.getMidpoint().y + gf.cameraPosition[1];
				}

				if(stageJson.camera_girlfriend != null && stageJson.camera_girlfriend.length > 1)
				{
					focusPoint.x += stageJson.camera_girlfriend[0];
					focusPoint.y += stageJson.camera_girlfriend[1];
				}
		}
		return focusPoint;
	}

	function repositionGirlfriend()
	{
		gf.setPosition(stageJson.girlfriend[0], stageJson.girlfriend[1]);
		gf.x += gf.positionArray[0];
		gf.y += gf.positionArray[1];
	}
	function repositionDad()
	{
		dad.setPosition(stageJson.opponent[0], stageJson.opponent[1]);
		dad.x += dad.positionArray[0];
		dad.y += dad.positionArray[1];
	}
	function repositionBoyfriend()
	{
		boyfriend.setPosition(stageJson.boyfriend[0], stageJson.boyfriend[1]);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
	}
	
	public function drawDebugOnCamera(spr:FlxSprite):Void
	{
		if (spr == null || !spr.isOnScreen(FlxG.camera))
			return;

		@:privateAccess
		var lineSize:Int = Std.int(Math.max(2, Math.floor(3 / FlxG.camera.zoom)));

		var sprX:Float = spr.x - spr.offset.x;
		var sprY:Float = spr.y - spr.offset.y;
		var sprWidth:Int = Std.int(spr.frameWidth * spr.scale.x);
		var sprHeight:Int = Std.int(spr.frameHeight * spr.scale.y);
		for (num => sel in selectionSprites.members)
		{
			sel.x = sprX;
			sel.y = sprY;
			switch(num)
			{
				case 0: //Top
					sel.setGraphicSize(sprWidth, lineSize);
				case 1: //Bottom
					sel.setGraphicSize(sprWidth, lineSize);
					sel.y += sprHeight - lineSize;
				case 2: //Left
					sel.setGraphicSize(lineSize, sprHeight);
				case 3: //Right
					sel.setGraphicSize(lineSize, sprHeight);
					sel.x += sprWidth - lineSize;
			}
			sel.updateHitbox();
			sel.scrollFactor.set(spr.scrollFactor.x, spr.scrollFactor.y);
		}
		selectionSprites.draw();
	}

	// save

	function saveObjectsToJson()
	{
		stageJson.objects = [];
		for (basic in stageSprites)
			stageJson.objects.push(basic.formatToJson());
	}

	function saveData()
	{
		if(_file != null) return;

		saveObjectsToJson();
		var data = haxe.Json.stringify(stageJson, '\t');
		#if mobile
		unsavedProgress = false;
		StorageUtil.saveContent('$lastLoadedStage.json', data);
		#else
		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, '$lastLoadedStage.json');
		}
		#end
	}

	var _file:FileReference;
	function onSaveComplete(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice('Successfully saved file.');
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	function onSaveCancel(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	function onSaveError(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error('Problem saving file');
	}

	var _makeNewSprite = null;
	public function loadImage(onNewSprite:String = null) {
		if(_file != null) return;

		_makeNewSprite = onNewSprite;
		_file = new FileReference();
		_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		final filters = [new FileFilter('PNG (Image)', '*.png'), new FileFilter('XML (Sparrow)', '*.xml'), new FileFilter('JSON (Aseprite)', '*.json'), new FileFilter('TXT (Packer)', '*.txt')];
		_file.browse(#if !mac filters #else [] #end);
	}
	
	private function onLoadComplete(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		#if sys
		var fullPath:String = null;
		@:privateAccess
		if(_file.__path != null) fullPath = _file.__path;
		var fileName:String = _file.name;
		#if mobile
		var fileData:ByteArray = _file.data;
		#end
		_file = null;

		function loadSprite(imageToLoad:String)
		{
			if(_makeNewSprite != null)
			{
				if(_makeNewSprite == 'animatedSprite' && !Paths.fileExists('images/$imageToLoad.xml', TEXT) &&
					!Paths.fileExists('images/$imageToLoad.json', TEXT) && !Paths.fileExists('images/$imageToLoad.txt', TEXT))
				{
					showOutput(Language.get('stage_editor_preload_no_anim_file'), true);
					_makeNewSprite = null;
					return;
				}
				insertMeta(new StageEditorMetaSprite({type: _makeNewSprite, name: findUnoccupiedName()}, new ModchartSprite()));
			}
			var selected = getSelected();
			tryLoadImage(selected, imageToLoad);
			
			if(_makeNewSprite != null)
			{
				selected.sprite.x = Math.round(FlxG.camera.scroll.x + FlxG.width/2 - selected.sprite.width/2);
				selected.sprite.y = Math.round(FlxG.camera.scroll.y + FlxG.height/2 - selected.sprite.height/2);
				posTxt.visible = true;
				posTxt.text = Language.get('stage_editor_pos_x_y', [Std.string(selected.sprite.x), Std.string(selected.sprite.y)]);
			}
			_makeNewSprite = null;
		}

		#if mobile
		// Mobile: use ByteArray data from file picker (content URI compatible)
		if(fileData != null && fileData.length > 0 && fileName != null && fileName.length > 0)
		{
			var baseName:String = fileName.substring(0, fileName.lastIndexOf('.'));
			var ext:String = fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase();

			#if MODS_ALLOWED
			var modFolder:String = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
				? Paths.mods('${Mods.currentModDirectory}/images/')
				: Paths.mods('images/');
			FileSystem.createDirectory(modFolder);
			File.saveBytes('$modFolder$baseName.$ext', fileData);
			#else
			var assetsFolder:String = 'assets/images/';
			if (!FileSystem.exists(assetsFolder))
				FileSystem.createDirectory(assetsFolder);
			File.saveBytes('$assetsFolder$baseName.$ext', fileData);
			#end

			showOutput(Language.get('stage_editor_preload_imported', [fileName]));
			loadSprite(baseName);
			return;
		}
		#end

		// Desktop path-based logic
		if(fullPath != null)
		{
			fullPath = fullPath.replace('\\', '/');
			var exePath = Sys.getCwd().replace('\\', '/');
			#if android
			var externalPath = StorageUtil.getExternalStorageDirectory();
			#end
			if(fullPath.startsWith(exePath))
			{
				fullPath = fullPath.substr(exePath.length);
				if((fullPath.startsWith('assets/') #if MODS_ALLOWED || fullPath.startsWith('mods/') #end) && fullPath.contains('/images/'))
				{
					loadSprite(fullPath.substring(fullPath.indexOf('/images/') + '/images/'.length, fullPath.lastIndexOf('.')));
					//trace('Inside Psych Engine Folder');
					return;
				}
			}
			#if android
			else if(fullPath.startsWith(externalPath))
			{
				fullPath = fullPath.substr(externalPath.length);
				if((fullPath.startsWith('assets/') #if MODS_ALLOWED || fullPath.startsWith('mods/') #end) && fullPath.contains('/images/'))
				{
					loadSprite(fullPath.substring(fullPath.indexOf('/images/') + '/images/'.length, fullPath.lastIndexOf('.')));
					//trace('Inside Psych Engine Folder');
					return;
				}
			}
			#end

			createPopup.visible = createPopup.active = false;
			#if MODS_ALLOWED
			var modFolder:String = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) ? Paths.mods('${Mods.currentModDirectory}/images/') : Paths.mods('images/');
			openSubState(new BasePrompt(480, 160, Language.get('stage_editor_prompt_stage_not_inside'), function(state:BasePrompt)
			{
				var txt:FlxText = lbl(0, state.bg.y + 60, 460, Language.get('stage_editor_prompt_copy_to_mods', [modFolder]), 12);
				txt.alignment = CENTER;
				txt.screenCenter(X);
				txt.cameras = state.cameras;
				state.add(txt);
				
				var btnY = 390;
				var btn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('stage_editor_prompt_yes'), function() {
					var fileName:String = fullPath.substring(fullPath.lastIndexOf('/') + 1, fullPath.lastIndexOf('.'));
					var pathNoExt:String = fullPath.substring(0, fullPath.lastIndexOf('.'));
					function saveFile(ext:String)
					{
						var p1:String = '$pathNoExt.$ext';
						var p2:String = modFolder + '$fileName.$ext';
						trace(p1, p2);
						if(FileSystem.exists(p1))
							File.saveBytes(p2, File.getBytes(p1));
					}

					FileSystem.createDirectory(modFolder);
					saveFile('png');
					saveFile('xml');
					saveFile('txt');
					saveFile('json');
					loadSprite(fileName);
					state.close();
				});
				btn.normalStyle.bgColor = FlxColor.GREEN;
				btn.normalStyle.textColor = FlxColor.WHITE;
				btn.screenCenter(X);
				btn.x -= 100;
				btn.cameras = state.cameras;
				state.add(btn);

				var btn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('stage_editor_prompt_cancel'), function()
				{
					_makeNewSprite = null;
					state.close();
				});
				btn.screenCenter(X);
				btn.x += 100;
				btn.cameras = state.cameras;
				state.add(btn);
			}));
			#else
			showOutput(Language.get('stage_editor_preload_cannot_be_used'), true);
			#end
		}
		#if mobile
		else
		{
			showOutput(Language.get('stage_editor_preload_could_not_load'), true);
		}
		#end
		#else
		_file = null;
		trace('File couldn\'t be loaded! You aren\'t on Desktop, are you?');
		#end
	}

	function tryLoadImage(spr:StageEditorMetaSprite, imgPath:String)
	{
		if(spr == null || StageData.reservedNames.contains(spr.type) || spr.type == 'square' || imgPath == null) return;

		spr.image = imgPath;
		updateSelectedUI();
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	private function onLoadCancel(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		
		if(_makeNewSprite != null)
		{
			createPopup.visible = createPopup.active = false;
			_makeNewSprite = null;
		}
		trace('Cancelled file loading.');
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private function onLoadError(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;

		if(_makeNewSprite != null)
		{
			createPopup.visible = createPopup.active = false;
			_makeNewSprite = null;
		}
		trace('Problem loading file');
	}

	override function destroy()
	{
		destroySubStates = true;
		animationEditor.destroy();
		super.destroy();
	}
}

class StageEditorMetaSprite
{
	public var sprite:FlxSprite;
	public var visible(get, set):Bool;
	function get_visible() return sprite.visible;
	function set_visible(v:Bool) return (sprite.visible = v);

	// basic variables for all types
	public var type:String;

	// variables for all types that aren't Character
	public var name:String;
	public var filters:LoadFilters = (LOW_QUALITY)|(HIGH_QUALITY);
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var alpha(get, set):Float;
	public var angle(get, set):Float;
	function get_x() return sprite.x;
	function set_x(v:Float) return (sprite.x = v);
	function get_y() return sprite.y;
	function set_y(v:Float) return (sprite.y = v);
	function get_alpha() return sprite.alpha;
	function set_alpha(v:Float) return (sprite.alpha = v);
	function get_angle() return sprite.angle;
	function set_angle(v:Float) return (sprite.angle = v);

	public var color(default, set):String = 'FFFFFF';
	function set_color(v:String)
	{
		sprite.color = CoolUtil.colorFromString(v);
		return (color = v);
	}
	public var image(default, set):String = 'unknown';
	function set_image(v:String)
	{
		try
		{
			switch(type)
			{
				case 'sprite':
					sprite.loadGraphic(Paths.image(v));
				case 'animatedSprite':
					sprite.frames = Paths.getAtlas(v);
			}
		}
		catch (e:Dynamic) {}
		sprite.updateHitbox();
		return (image = v);
	}

	public var scroll:Array<Float> = [1, 1];
	public function setScrollFactor(scrX:Null<Float> = null, scrY:Null<Float> = null)
	{
		scroll[0] = (scrX != null ? scrX : scroll[0]);
		scroll[1] = (scrY != null ? scrY : scroll[1]);
		sprite.scrollFactor.set(scroll[0], scroll[1]);
	}

	public var scale:Array<Float> = [1, 1];
	public var antialiasing(default, set):Bool = true;
	function set_antialiasing(v:Bool)
	{
		sprite.antialiasing = (v && ClientPrefs.data.antialiasing);
		return (antialiasing = v);
	}

	public function setScale(wid:Null<Float> = null, hei:Null<Float> = null)
	{
		scale[0] = (wid != null ? wid : scale[0]);
		scale[1] = (hei != null ? hei : scale[1]);
		sprite.scale.set(scale[0], scale[1]);
		sprite.updateHitbox();
	}
	
	public var flipX(get, set):Bool;
	public var flipY(get, set):Bool;
	function get_flipX() return sprite.flipX;
	function set_flipX(v:Bool) return (sprite.flipX = (v && type != 'square'));
	function get_flipY() return sprite.flipY;
	function set_flipY(v:Bool) return (sprite.flipY = (v && type != 'square'));

	// "animatedSprite" only variables
	public var firstAnimation:String;
	public var animations:Array<AnimArray>;

	public function new(data:Dynamic, spr:FlxSprite)
	{
		this.sprite = spr;
		if(data == null) return;

		this.type = data.type;
		switch(this.type)
		{
			case 'sprite', 'square', 'animatedSprite':
				for (v in ['name', 'image', 'scale', 'scroll', 'color', 'filters', 'antialiasing'])
				{
					var dat:Dynamic = Reflect.field(data, v);
					if(dat != null) Reflect.setField(this, v, dat);
				}

				if(this.type == 'animatedSprite')
				{
					this.animations = data.animations;
					this.firstAnimation = data.firstAnimation;
				}
		}
	}

	public function formatToJson()
	{
		var obj:Dynamic = {type: type};
		switch(type)
		{
			case 'square', 'sprite', 'animatedSprite':
				obj.name = name;
				obj.x = x;
				obj.y = y;
				obj.scale = scale;
				obj.scroll = scroll;
				obj.alpha = alpha;
				obj.angle = angle;
				obj.color = color;
				obj.filters = filters;

				if(type != 'square')
				{
					obj.flipX = flipX;
					obj.flipY = flipY;
					obj.image = image;
					obj.antialiasing = antialiasing;
					if(type == 'animatedSprite')
					{
						obj.animations = animations;
						obj.firstAnimation = firstAnimation;
					}
				}
		}
		return obj;
	}

	public function update(curFilters:LoadFilters, elapsed:Float)
	{
		if((curFilters & filters) != 0 || StageData.reservedNames.contains(type))
			sprite.update(elapsed);
	}

	public function draw(curFilters:LoadFilters)
	{
		if((curFilters & filters) != 0 || StageData.reservedNames.contains(type))
			sprite.draw();
	}
}

class StageEditorAnimationSubstate extends MusicBeatSubstate {
	var bg:FlxSprite;
	var originalZoom:Float;
	var originalCamPoint:FlxPoint;
	var originalPosition:FlxPoint;
	var originalCamTarget:FlxObject;
	var originalAlpha:Float = 1;
	public var target:StageEditorMetaSprite;
	
	var curAnim:Int = 0;
	var animsTxtGroup:FlxTypedGroup<FlxText>;

	var UI_animationbox:PsychUIBox;
	var camHUD:FlxCamera = cast(FlxG.state, StageEditorState).camHUD;
	public function new()
	{
		controls.isInSubstate = true;
		super();

		var grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(50, 50, 100, 100, true, 0xFFAAAAAA, 0xFF666666));
		add(grid);
		
		animsTxtGroup = new FlxTypedGroup<FlxText>();
		animsTxtGroup.cameras = [camHUD];
		add(animsTxtGroup);
		
		#if mobile
		UI_animationbox = new PsychUIBox(FlxG.width - 320, 75, 300, 250, [Language.get('stage_editor_animations_tab')]);
		#else
		UI_animationbox = new PsychUIBox(FlxG.width - 320, 20, 300, 250, [Language.get('stage_editor_animations_tab')]);
		#end
		UI_animationbox.cameras = [camHUD];
		UI_animationbox.scrollFactor.set();
		add(UI_animationbox);
		addAnimationsUI();

		openCallback = function()
		{
			if(target == null || target.sprite == null) return;
			curAnim = 0;
			originalZoom = FlxG.camera.zoom;
			originalCamPoint = FlxPoint.weak(FlxG.camera.scroll.x, FlxG.camera.scroll.y);
			originalPosition = FlxPoint.weak(target.x, target.y);
			originalCamTarget = FlxG.camera.target;
			originalAlpha = target.alpha;
			FlxG.camera.zoom = 0.5;
			FlxG.camera.scroll.set(0, 0);
			FlxG.camera.target = null; // Stop camera from following any target

			target.alpha = 1;
			target.sprite.screenCenter();
			add(target.sprite);
			reloadAnimList();
			trace('Opened substate');
		};

		closeCallback = function()
		{
			if(target == null) return;
			FlxG.camera.zoom = originalZoom;
			FlxG.camera.scroll.set(originalCamPoint.x, originalCamPoint.y);
			FlxG.camera.target = originalCamTarget;

			target.x = originalPosition.x;
			target.y = originalPosition.y;
			target.alpha = originalAlpha;
			if(target.sprite != null) remove(target.sprite);

			if(target.animations != null && target.animations.length > 0)
			{
				if(target.firstAnimation == null) target.firstAnimation = target.animations[0].anim;
				if(target.firstAnimation != null) playAnim(target.firstAnimation);
			}
		};

		addTouchPad('LEFT_FULL', 'CHARACTER_EDITOR');
		addTouchPadCamera();
	}

	var animationDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var animationNameInputText:PsychUIInputText;
	var animationIndicesInputText:PsychUIInputText;
	var animationFramerate:PsychUINumericStepper;
	var animationLoopCheckBox:PsychUICheckBox;
	var mainAnimTxt:FlxText;
	function addAnimationsUI()
	{
		var tab_group = UI_animationbox.getTab(Language.get('stage_editor_animations_tab')).menu;

		var animSize:Int = 12;

		animationInputText = new PsychUIInputText(15, 85, 120, '', animSize);
		animationNameInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', animSize);
		animationIndicesInputText = new PsychUIInputText(animationNameInputText.x, animationNameInputText.y + 40, 250, '', animSize);
		animationFramerate = new PsychUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new PsychUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, Language.get('stage_editor_animation_should_loop'), 120);

		animationDropDown = new PsychUIDropDownMenu(15, animationInputText.y - 55, [''], function(selectedAnimation:Int, pressed:String) {
			if(target.animations == null || selectedAnimation < 0 || selectedAnimation >= target.animations.length) return;
			var anim:AnimArray = target.animations[selectedAnimation];
			if(anim == null) return;

			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationFramerate.value = anim.fps;

			if(anim.indices != null)
			{
				var indicesStr:String = anim.indices.toString();
				animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);
			}
			else
				animationIndicesInputText.text = '';
		});

		mainAnimTxt = new FlxText(160, animationDropDown.y - 18, 0, Language.get('stage_editor_animation_main_label').replace('{0}', '')).setFormat(Paths.font(Language.get('uitab_font')), 12);
		var initAnimButton:PsychUIButton = new PsychUIButton(160, animationDropDown.y, Language.get('stage_editor_animation_main'), function() {
			if(target.animations == null || curAnim < 0 || curAnim >= target.animations.length) return;
			var anim:AnimArray = target.animations[curAnim];
			if(anim == null) return;

			mainAnimTxt.text = Language.get('stage_editor_animation_main_label').replace('{0}', anim.anim);
			target.firstAnimation = anim.anim;
		});
		tab_group.add(mainAnimTxt);
		tab_group.add(initAnimButton);

		var addUpdateButton:PsychUIButton = new PsychUIButton(40, animationIndicesInputText.y + 35, Language.get('stage_editor_animation_add_update'), function() {
			if(animationInputText.text == '') return;

			var indices:Array<Int> = [];
			var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');
			if(indicesStr.length > 1) {
				for (i in 0...indicesStr.length) {
					var index:Int = Std.parseInt(indicesStr[i]);
					if(indicesStr[i] != null && indicesStr[i] != '' && !Math.isNaN(index) && index > -1) {
						indices.push(index);
					}
				}
			}

			var lastAnim:String = (target.animations[curAnim] != null) ? target.animations[curAnim].anim : '';
			var lastOffsets:Array<Int> = null;
			var targetSprite:ModchartSprite = cast (target.sprite, ModchartSprite);
			for (anim in target.animations)
				if(animationInputText.text == anim.anim)
				{
					lastOffsets = anim.offsets;
					if(targetSprite != null)
					{
						targetSprite.animOffsets.remove(animationInputText.text);
						if(targetSprite.animation != null)
							targetSprite.animation.remove(animationInputText.text);
					}
					target.animations.remove(anim);
				}

			var addedAnim:AnimArray = {
				anim: animationInputText.text,
				name: animationNameInputText.text,
				fps: Math.round(animationFramerate.value),
				loop: animationLoopCheckBox.checked,
				indices: indices,
				offsets: lastOffsets
			};

			if(targetSprite != null && targetSprite.animation != null)
			{
				if(addedAnim.indices != null && addedAnim.indices.length > 0)
					targetSprite.animation.addByIndices(addedAnim.anim, addedAnim.name, addedAnim.indices, '', addedAnim.fps, addedAnim.loop);
				else
					targetSprite.animation.addByPrefix(addedAnim.anim, addedAnim.name, addedAnim.fps, addedAnim.loop);
			}

			target.animations.push(addedAnim);
			reloadAnimList();
			if(targetSprite != null) playAnim(addedAnim.anim, true);

			curAnim = target.animations.length - 1;
			updateTextColors();
			trace('Added/Updated animation: ' + animationInputText.text);
		});

		var removeButton:PsychUIButton = new PsychUIButton(160, animationIndicesInputText.y + 35, Language.get('stage_editor_remove'), function()
		{
			for (anim in target.animations)
			{
				if(anim == null) continue;
				if(animationInputText.text == anim.anim)
				{
					var targetSprite:ModchartSprite = cast (target.sprite, ModchartSprite);
					var resetAnim:Bool = false;
					if(targetSprite != null && targetSprite.animation != null && targetSprite.animation.curAnim != null && anim.anim == targetSprite.animation.curAnim.name) resetAnim = true;

					if(targetSprite != null && targetSprite.animOffsets.exists(anim.anim))
						targetSprite.animOffsets.remove(anim.anim);

					target.animations.remove(anim);

					if(targetSprite != null && targetSprite.animation != null)
						targetSprite.animation.remove(anim.anim);

					if(resetAnim && target.animations.length > 0)
					{
						curAnim = FlxMath.wrap(curAnim, 0, target.animations.length-1);
						playAnim(target.animations[curAnim].anim, true);
						updateTextColors();
					}
					else if(target.animations.length < 1 && target.sprite != null && target.sprite.animation != null)
						target.sprite.animation.curAnim = null;

					trace('Removed animation: ' + animationInputText.text);
					reloadAnimList();
					break;
				}
			}
		});

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, Language.get('stage_editor_animations_list')).setFormat(Paths.font(Language.get('uitab_font')), 12));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, Language.get('stage_editor_animation_name')).setFormat(Paths.font(Language.get('uitab_font')), 12));
		tab_group.add(new FlxText(animationFramerate.x, animationFramerate.y - 18, 0, Language.get('stage_editor_animation_framerate')).setFormat(Paths.font(Language.get('uitab_font')), 12));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 0, Language.get('stage_editor_animation_symbol_tag')).setFormat(Paths.font(Language.get('uitab_font')), 12));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 0, Language.get('stage_editor_animation_indices')).setFormat(Paths.font(Language.get('uitab_font')), 12));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(animationDropDown);
	}

	function reloadAnimList()
	{
		if(target.animations == null) target.animations = [];
		else if(target.animations.length > 0 && target.sprite != null && target.sprite.animation != null)
			playAnim(target.animations[0].anim, true);
		curAnim = 0;

		// Properly remove ALL old text objects from the group using splice=true
		while(animsTxtGroup.members.length > 0)
		{
			var oldText:FlxText = animsTxtGroup.members[0];
			if(oldText == null)
			{
				// All remaining members are likely null or corrupted; clear the group
				animsTxtGroup.clear();
				break;
			}
			animsTxtGroup.remove(oldText, true);
			oldText.destroy();
		}

		var spr:ModchartSprite = cast (target.sprite, ModchartSprite);
		if(spr == null) return;

		if(target.animations.length > 0)
		{
			if(target.firstAnimation == null || target.sprite == null || target.sprite.animation == null || !target.sprite.animation.exists(target.firstAnimation))
			{
				if(target.animations[0] != null)
					target.firstAnimation = target.animations[0].anim;
			}

			mainAnimTxt.text = Language.get('stage_editor_animation_main_label').replace('{0}', target.firstAnimation);
		}
		else
		{
			target.firstAnimation = null;
			mainAnimTxt.text = Language.get('stage_editor_animation_no_main');
		}

		for (num => anim in target.animations)
		{
			var text:FlxText = animsTxtGroup.recycle(FlxText);
			text.x = 10;
			text.y = 32 + (24 * num);
			text.fieldWidth = 400;
			text.fieldHeight = 24;
			var animName:String = (anim != null) ? anim.anim : 'null';
			if(anim != null && anim.offsets != null)
				text.text = '${animName}: ${spr.animOffsets.get(animName)}';
			else
				text.text = '${animName}: ' + Language.get('stage_editor_animation_no_offsets');

			text.setFormat(Paths.font(Language.get('uitab_font')), 14, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 1;
		}
		updateTextColors();
		reloadAnimationDropDown();
	}
	
	function reloadAnimationDropDown() {
		var animList:Array<String> = [];
		for (anim in target.animations) animList.push(anim.anim);
		if(animList.length < 1) animList.push(Language.get('stage_editor_animation_no_animations')); //Prevents crash

		animationDropDown.list = animList;
	}

	inline function updateTextColors()
	{
		for (num => text in animsTxtGroup)
		{
			text.color = FlxColor.WHITE;
			if(num == curAnim) text.color = FlxColor.LIME;
		}
	}

	function playAnim(name:String, force:Bool = false)
	{
		var spr:ModchartSprite = cast (target.sprite, ModchartSprite);
		if(spr == null) return;
		spr.playAnim(name, force);
		if(!spr.animOffsets.exists(name)) spr.updateHitbox();
	}
	
	final minZoom = 0.25;
	final maxZoom = 2;
	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if(PsychUIInputText.focusOn != null) return;
		if(target == null) return;
		if(target.animations == null) target.animations = [];
		
		var tp:TouchPad = touchPad;
		var hasTouch:Bool = (tp != null);

		// ANIMATION SCROLLING
		if(target.animations.length > 0)
		{
			var changedAnim:Bool = false;
			if(FlxG.keys.justPressed.W || (hasTouch && tp.buttonUp != null && tp.buttonUp.justPressed))
			{
				curAnim--;
				changedAnim = true;
			}
			else if(FlxG.keys.justPressed.S || (hasTouch && tp.buttonDown != null && tp.buttonDown.justPressed))
			{
				curAnim++;
				changedAnim = true;
			}
			else if(FlxG.keys.justPressed.SPACE) changedAnim = true;

			if(changedAnim)
			{
				curAnim = FlxMath.wrap(curAnim, 0, target.animations.length-1);
				if(target.animations[curAnim] != null)
				{
					var animName:String = target.animations[curAnim].anim;
					var spr:ModchartSprite = cast (target.sprite, ModchartSprite);
					if(spr != null)
					{
						// Force restart: stop first, then play — ensures replay even with 1 animation
						if(spr.animation.curAnim != null && spr.animation.curAnim.name == animName)
							spr.animation.stop();
						spr.playAnim(animName, true);
					}
				}
				updateTextColors();
			}
		}

		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		var shiftMultBig:Float = 1;
		var hasBtnC:Bool = hasTouch && tp.buttonC != null;
		var hasBtnG:Bool = hasTouch && tp.buttonG != null;
		var hasBtnZ:Bool = hasTouch && tp.buttonZ != null;
		var hasBtnB:Bool = hasTouch && tp.buttonB != null;
		var hasBtnLeft:Bool = hasTouch && tp.buttonLeft != null;
		var hasBtnRight:Bool = hasTouch && tp.buttonRight != null;
		var hasBtnUp:Bool = hasTouch && tp.buttonUp != null;
		var hasBtnDown:Bool = hasTouch && tp.buttonDown != null;
		var hasBtnX:Bool = hasTouch && tp.buttonX != null;
		var hasBtnY:Bool = hasTouch && tp.buttonY != null;
		
		if(FlxG.keys.pressed.SHIFT || (hasBtnC && tp.buttonC.pressed))
		{
			shiftMult = 4;
			shiftMultBig = 10;
		}
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		// OFFSET
		if(target.sprite != null && target.sprite.animation != null && target.sprite.animation.curAnim != null)
		{
			var spr:ModchartSprite = cast (target.sprite, ModchartSprite);
			if(spr == null) return;
			var anim:String = spr.animation.curAnim.name;
			var changedOffset = false;
			var useTouch:Bool = controls.mobileC && hasTouch;
			var moveKeysP = useTouch ? [hasBtnLeft && tp.buttonLeft.justPressed, hasBtnRight && tp.buttonRight.justPressed, hasBtnUp && tp.buttonUp.justPressed, hasBtnDown && tp.buttonDown.justPressed] : [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
			var moveKeys = useTouch ? [hasBtnLeft && tp.buttonLeft.pressed, hasBtnRight && tp.buttonRight.pressed, hasBtnUp && tp.buttonUp.pressed, hasBtnDown && tp.buttonDown.pressed] : [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
			var btnGPressed:Bool = hasBtnG && tp.buttonG.pressed;
			if(moveKeysP.contains(true) && !btnGPressed)
			{
				if(spr.animOffsets.get(anim) != null)
				{
					spr.offset.x += ((moveKeysP[0] ? 1 : 0) - (moveKeysP[1] ? 1 : 0)) * shiftMultBig;
					spr.offset.y += ((moveKeysP[2] ? 1 : 0) - (moveKeysP[3] ? 1 : 0)) * shiftMultBig;
				}
				else spr.offset.x = spr.offset.y = 0;
				changedOffset = true;
			}
	
			if(moveKeys.contains(true) && !btnGPressed)
			{
				holdingArrowsTime += elapsed;
				if(holdingArrowsTime > 0.6)
				{
					holdingArrowsElapsed += elapsed;
					while(holdingArrowsElapsed > (1/60))
					{
						if(spr.animOffsets.get(anim) != null)
						{
							spr.offset.x += ((moveKeys[0] ? 1 : 0) - (moveKeys[1] ? 1 : 0)) * shiftMultBig;
							spr.offset.y += ((moveKeys[2] ? 1 : 0) - (moveKeys[3] ? 1 : 0)) * shiftMultBig;
						}
						else spr.offset.x = spr.offset.y = 0;
						holdingArrowsElapsed -= (1/60);
						changedOffset = true;
					}
				}
			}
			else holdingArrowsTime = 0;
	
			if(FlxG.mouse.pressedRight && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0))
			{
				spr.offset.x -= FlxG.mouse.deltaScreenX;
				spr.offset.y -= FlxG.mouse.deltaScreenY;
				changedOffset = true;
			}

			if ((FlxG.keys.justPressed.R || (hasBtnZ && tp.buttonZ.justPressed)) && (FlxG.keys.pressed.CONTROL || (hasBtnC && tp.buttonC.pressed)))
			{
				if(curAnim >= 0 && curAnim < target.animations.length && target.animations[curAnim] != null)
				{
					target.animations[curAnim].offsets = null;
					spr.animOffsets.remove(anim);
					spr.updateHitbox();
					if(curAnim < animsTxtGroup.members.length && animsTxtGroup.members[curAnim] != null)
						animsTxtGroup.members[curAnim].text = '${anim}: No offsets';
				}
			}
			
			if(changedOffset)
			{
				var offX = Math.round(spr.offset.x);
				var offY = Math.round(spr.offset.y);

				spr.addOffset(anim, offX, offY);
				if(curAnim >= 0 && curAnim < target.animations.length && target.animations[curAnim] != null)
				{
					target.animations[curAnim].offsets = [offX, offY];
				}
				if(curAnim < animsTxtGroup.members.length && animsTxtGroup.members[curAnim] != null)
					animsTxtGroup.members[curAnim].text = '${anim}: ${spr.animOffsets.get(anim)}';
			}
		}
		else
		{
			holdingArrowsTime = 0;
			holdingArrowsElapsed = 0;
		}

		// CAMERA CONTROLS
		var camX:Float = 0;
		var camY:Float = 0;
		var camMove:Float = elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.J || (hasBtnLeft && hasBtnG && tp.buttonLeft.pressed && tp.buttonG.pressed)) camX -= camMove;
		if (FlxG.keys.pressed.K || (hasBtnDown && hasBtnG && tp.buttonDown.pressed && tp.buttonG.pressed)) camY += camMove;
		if (FlxG.keys.pressed.L || (hasBtnRight && hasBtnG && tp.buttonRight.pressed && tp.buttonG.pressed)) camX += camMove;
		if (FlxG.keys.pressed.I || (hasBtnUp && hasBtnG && tp.buttonUp.pressed && tp.buttonG.pressed)) camY -= camMove;

		if(camX != 0 || camY != 0)
		{
			FlxG.camera.scroll.x += camX;
			FlxG.camera.scroll.y += camY;
		}

		var lastZoom = FlxG.camera.zoom;
		if(FlxG.keys.justPressed.R || (hasBtnZ && tp.buttonZ.justPressed && !FlxG.keys.pressed.CONTROL))
			FlxG.camera.zoom = 0.5;
		else if ((FlxG.keys.pressed.E || (hasBtnX && tp.buttonX.pressed)) && FlxG.camera.zoom < maxZoom)
			FlxG.camera.zoom = Math.min(maxZoom, FlxG.camera.zoom + elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
		else if ((FlxG.keys.pressed.Q || (hasBtnY && tp.buttonY.pressed)) && FlxG.camera.zoom > minZoom)
			FlxG.camera.zoom = Math.max(minZoom, FlxG.camera.zoom - elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);

		if(FlxG.keys.justPressed.ESCAPE #if android || FlxG.android.justReleased.BACK #end || (hasBtnB && tp.buttonB.justPressed))
		{
			persistentDraw = true;
			controls.isInSubstate = false;
			close();
		}
	}
}
