package states.editors;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;

import backend.ui.PsychUIInputText;
import backend.ui.PsychUISlider;
import states.editors.content.FileDialogHandler;
import spineflixel.SpineViewerTextureLoader;

import spine.SkeletonData;
import spine.SkeletonJson;
import spine.SkeletonBinary;
import spine.atlas.TextureAtlas;
import spine.attachments.AtlasAttachmentLoader;
import spine.animation.AnimationStateData;
import spine.flixel.NoCullSkeletonSprite;
import spine.attachments.RegionAttachment;
import spine.attachments.MeshAttachment;
import spine.atlas.TextureAtlasRegion;
import flixel.graphics.FlxGraphic;

#if desktop
import lime.app.Application;
#end

/**
 * Spine Viewer — a toolbox editor that displays one or more Spine characters
 * loaded directly from disk, with free controls (pan / zoom) and buttons to
 * pick the `.atlas`, `.skel` and `.json` files.
 *
 * Multi-character mode (each character is independently controlled):
 *   - "Add" loads another character (it is appended and becomes the active one).
 *   - Click a character on the canvas to select it (the right panel then shows
 *     THAT character's animations / skins).
 *   - Drag a character to move it; drag empty space to pan all characters.
 *   - Mouse wheel (or [ ] / +/- / on-screen buttons) zooms the character under
 *     the cursor, or the active one if none is under the cursor.
 *   - Right panel: play an animation / cycle skin / toggle loop for the active
 *     character. "◀ Char" / "Char ▶" switch the active character; "Del Char"
 *     removes it.
 *
 * Note: the flixel camera always stays at zoom = 1. Pan/zoom is done by moving
 * and scaling each skeleton itself, because spine-haxe does not apply the
 * camera zoom to the mesh vertices.
 */
class SpineViewerState extends MusicBeatState
{
	// Layout constants
	static final TOP_BAR_H:Int = 40;
	static final PANEL_W:Int = 240;
	static final INPUT_W:Int = 175;
	// Y where the animation list begins inside the right panel
	static final LIST_TOP:Int = TOP_BAR_H + 122;

	var uiCam:FlxCamera;

	var charGroup:FlxGroup;

	var characters:Array<SpineCharacter> = [];
	var activeChar:SpineCharacter;
	var dragTarget:SpineCharacter;

	var atlasInput:PsychUIInputText;
	var skeletonInput:PsychUIInputText; // accepts either .skel or .json

	var fileHandler:FileDialogHandler;
	var pendingPicker:String = null; // 'atlas' | 'skeleton'

	#if desktop
	var dropHandler:(String)->Void = null;
	#end

	var animTexts:Array<FlxText> = [];
	var animScroll:Float = 0;
	var animPanel:FlxSprite;
	var animScrollBar:FlxSprite;
	var animTitle:FlxText;
	var rSlider:PsychUISlider;
	var gSlider:PsychUISlider;
	var bSlider:PsychUISlider;
	var animListTop:Float = LIST_TOP;
	var topBar:FlxSprite;
	// Set true right after a native file dialog closes; we then wait for the
	// (stray) mouse press that "passes through" to be released before allowing a
	// new canvas drag, so it doesn't grab a character or overwrite the inputs.
	var awaitingMouseRelease:Bool = false;

	var skinBtn:FlxButton;
	var loopBtn:FlxButton;
	var infoText:FlxText;
	var hintText:FlxText;

	var dragging:Bool = false;
	var dragStartMouseX:Float = 0;
	var dragStartMouseY:Float = 0;
	// Frames during which canvas click/drag is ignored, so a click that
	// "passes through" when a native file dialog closes doesn't grab/drag a
	// character or overwrite the path inputs via selectChar().
	var inputLockFrames:Int = 0;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Spine Viewer", null);
		#end

		// super.create() initializes the psych camera and RESETS FlxG.cameras,
		// which would destroy any camera added before it. So initialize first.
		super.create();

		FlxG.camera.bgColor = 0xFF1a1a24;

		// Reset main camera (used for the Spine characters only)
		FlxG.camera.zoom = 1;
		FlxG.camera.scroll.set(0, 0);

		// Single shared camera. Layering is controlled by FlxGroup order, not by
		// camera stacking (a separately-added camera ended up rendered *behind*
		// the default camera, putting characters on top of the UI).
		uiCam = FlxG.camera;

		// Group that holds every Spine character. Added before the UI so all
		// characters always render behind the UI.
		charGroup = new FlxGroup();
		add(charGroup);

		FlxG.mouse.visible = true;

		buildUI();

		fileHandler = new FileDialogHandler();

		addTouchPad('LEFT_FULL', 'A_B_E');
		addTouchPadCamera();

		#if desktop
		// Drag & drop a .atlas / .skel / .json file onto the window as a
		// reliable alternative to the native file dialog.
		dropHandler = function(path:String)
		{
			path = path.replace('\\', '/');
			var lower:String = path.toLowerCase();
					if (lower.endsWith('.atlas'))
						atlasInput.text = path;
					else if (lower.endsWith('.skel') || lower.endsWith('.json'))
						skeletonInput.text = path;
			else
			{
				showHint("拖入的文件类型不支持，请拖入 .atlas / .skel / .json 文件。");
				return;
			}
			showHint("已通过拖拽填入路径，点击 Add 加载。");
		};
		Application.current.window.onDropFile.add(dropHandler);
		#end
	}

	override function destroy()
	{
		#if desktop
		if (dropHandler != null && Application.current != null && Application.current.window != null)
			Application.current.window.onDropFile.remove(dropHandler);
		dropHandler = null;
		#end
		if (fileHandler != null)
		{
			fileHandler.destroy();
			fileHandler = null;
		}
		characters = [];
		activeChar = null;
		super.destroy();
	}

	function buildUI():Void
	{
		var gameFont:String = Paths.font("vcr.ttf");

		// Top bar background. We hit-test against this sprite with
		// FlxG.mouse.overlaps(topBar, uiCam) (mirroring the right-panel check)
		// so clicks/drags on the top bar are never treated as canvas input.
		topBar = new FlxSprite(0, 0);
		topBar.makeGraphic(FlxG.width, TOP_BAR_H, FlxColor.BLACK);
		topBar.alpha = 0.4;
		topBar.cameras = [uiCam];
		add(topBar);

		var y:Float = 6.0;

		// --- Atlas row ---
		var atlasBtn:FlxButton = makeButton(10, y, 70, "Atlas", () -> openPicker("atlas"));
		atlasInput = makeInput(85, y, INPUT_W, "path/to/char.atlas");

		// --- Skeleton row (selective: .skel OR .json, user picks either) ---
		var skelJsonBtn:FlxButton = makeButton(265, y, 80, "Skel/JSON", () -> openPicker("skeleton"));
		skeletonInput = makeInput(350, y, INPUT_W, "path/to/char.skel or .json");

		// --- Action buttons ---
		var loadBtn:FlxButton = makeButton(545, y, 80, "Add", addCharacter);
		var delBtn:FlxButton = makeButton(845, y, 90, "Del Char", deleteActiveChar);
		var resetBtn:FlxButton = makeButton(940, y, 80, "Reset", resetCamera);
		var zoomOutBtn:FlxButton = makeButton(1025, y, 60, "Zoom-", () -> zoomChar(activeChar, 0.9, FlxG.width / 2, FlxG.height / 2));
		var zoomInBtn:FlxButton = makeButton(1090, y, 60, "Zoom+", () -> zoomChar(activeChar, 1.1, FlxG.width / 2, FlxG.height / 2));
		var backBtn:FlxButton = makeButton(FlxG.width - 80, y, 70, "Back", onBack);

		// --- Right panel: animation list ---
		var panelX:Float = FlxG.width - PANEL_W;
		// Y where the animation list begins. It sits below the RGB sliders and
		// the active-character navigation row.
		animListTop = TOP_BAR_H + 294;

		// Semi-transparent panel background. The Spine characters live on the
		// main camera (which renders first), so they always stay behind this
		// uiCam panel.
		animPanel = new FlxSprite(panelX, TOP_BAR_H);
		animPanel.makeGraphic(PANEL_W, Math.floor(FlxG.height - TOP_BAR_H), FlxColor.BLACK);
		animPanel.alpha = 0.45;
		animPanel.cameras = [uiCam];
		add(animPanel);

		// Scrollbar for the animation list (hidden when the list fits).
		animScrollBar = new FlxSprite(panelX + PANEL_W - 4, animListTop);
		animScrollBar.makeGraphic(4, 20, FlxColor.GRAY);
		animScrollBar.alpha = 0.8;
		animScrollBar.cameras = [uiCam];
		animScrollBar.visible = false;
		add(animScrollBar);

		animTitle = new FlxText(panelX + 8, TOP_BAR_H + 8, PANEL_W - 16, "No Character", 16);
		animTitle.setFormat(gameFont, 16, FlxColor.YELLOW, LEFT, OUTLINE, FlxColor.BLACK);
		animTitle.cameras = [uiCam];
		add(animTitle);

		skinBtn = makeButton(panelX + 8, TOP_BAR_H + 34, PANEL_W - 16, "Skin: —", cycleSkin);
		loopBtn = makeButton(panelX + 8, TOP_BAR_H + 64, PANEL_W - 16, "Loop: ON", toggleLoop);

		// Per-character RGB tint (0..1). Sliders live on the right panel, so
		// overlaps(topBar/animPanel) keeps them from grabbing the canvas.
		var rgbLabel:FlxText = new FlxText(panelX + 8, TOP_BAR_H + 94, PANEL_W - 16, "RGB Tint (active char)", 14);
		rgbLabel.setFormat(gameFont, 14, FlxColor.CYAN, LEFT, OUTLINE, FlxColor.BLACK);
		rgbLabel.cameras = [uiCam];
		add(rgbLabel);

		rSlider = new PsychUISlider(panelX + 8, TOP_BAR_H + 112, (_) -> applyActiveRGB(), 1, 0, 1, PANEL_W - 16, FlxColor.RED);
		gSlider = new PsychUISlider(panelX + 8, TOP_BAR_H + 162, (_) -> applyActiveRGB(), 1, 0, 1, PANEL_W - 16, FlxColor.LIME);
		bSlider = new PsychUISlider(panelX + 8, TOP_BAR_H + 212, (_) -> applyActiveRGB(), 1, 0, 1, PANEL_W - 16, FlxColor.BLUE);
		rSlider.label = "R";
		gSlider.label = "G";
		bSlider.label = "B";
		for (s in [rSlider, gSlider, bSlider])
		{
			s.cameras = [uiCam];
			add(s);
		}

		// Active character navigation
		var navY:Float = TOP_BAR_H + 262;
		var halfW:Int = Std.int((PANEL_W - 24) / 2);
		makeButton(panelX + 8, navY, halfW, "◀ Char", () -> cycleActiveChar(-1));
		makeButton(panelX + 8 + halfW + 8, navY, halfW, "Char ▶", () -> cycleActiveChar(1));

		animTexts = [];

		// --- Bottom info / hint ---
		infoText = new FlxText(10, FlxG.height - 58, FlxG.width - PANEL_W - 20, "", 14);
		infoText.setFormat(gameFont, 14, FlxColor.LIME, LEFT, OUTLINE, FlxColor.BLACK);
		infoText.cameras = [uiCam];
		add(infoText);

		hintText = new FlxText(10, TOP_BAR_H + 8, FlxG.width - PANEL_W - 20,
			"选择 Atlas 与骨架文件（Skel/JSON 二选一，也可直接填写路径），点击 Add 加载角色。\n"
			+ "可加载多个角色，点击角色选中它，右侧面板独立控制其动画/皮肤。\n"
			+ "拖拽角色移动；拖空白处平移全部；滚轮 / [ ] 缩放光标下角色；方向键 / WASD 移动当前角色，R 重置。", 16);
		hintText.setFormat(gameFont, 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		hintText.cameras = [uiCam];
		add(hintText);

		updateInfo();
	}

	function makeButton(x:Float, y:Float, w:Int, label:String, onClick:Void->Void):FlxButton
	{
		var btn:FlxButton = new FlxButton(x, y, label, onClick);
		btn.setGraphicSize(w, 28);
		btn.updateHitbox();
		btn.label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER);
		btn.cameras = [uiCam];
		add(btn);
		return btn;
	}

	function makeInput(x:Float, y:Float, w:Int, placeholder:String):PsychUIInputText
	{
		var input:PsychUIInputText = new PsychUIInputText(x, y, w, "", 14);
		input.cameras = [uiCam];
		input.text = placeholder;
		add(input);
		return input;
	}

	// ------------------------------------------------------------------
	// File picking
	// ------------------------------------------------------------------
	function openPicker(type:String):Void
	{
		if (fileHandler == null)
			return;

		if (!fileHandler.completed)
		{
			// A previous dialog may have failed to open; let the user try again.
			fileHandler.completed = true;
		}

		pendingPicker = type;

		#if (desktop || (js && html5))
		try
		{
			// IMPORTANT: pass null title and an empty filter (=> show all files).
			// The engine's FileDialogHandler passes these straight into lime's
			// native dialog, and a non-null title / custom filter was causing a
			// hard crash here. We validate the chosen file's extension ourselves
			// in onPickerComplete() instead.
			fileHandler.open(null, null, [], onPickerComplete, null, onPickerError);
		}
		catch (e:Dynamic)
		{
			fileHandler.completed = true;
			showHint("无法打开文件选择窗口: " + e + "\n你也可以直接把文件拖拽到窗口，或手动填写路径。");
		}
		#else
		// On targets without a system file dialog (e.g. Android), the user
		// must type the absolute path directly into the input field.
		pendingPicker = null;
		showHint("当前平台不支持系统文件选择，请直接在输入框填写完整路径后点击 Add，或把文件放到可访问目录。");
		#end
	}

	function onPickerComplete():Void
	{
		// The native dialog is closing; block the click that will "pass through"
		// to the game window for a few frames so it doesn't grab a character.
		inputLockFrames = 12;
		if (fileHandler == null || fileHandler.path == null)
		{
			pendingPicker = null;
			return;
		}
		var path:String = fileHandler.path.replace('\\', '/');
		var lower:String = path.toLowerCase();
		switch (pendingPicker)
		{
			case "atlas":
				if (!lower.endsWith(".atlas"))
					showHint("请选择 .atlas 文件。");
				else
					atlasInput.text = path;
			case "skeleton":
				if (lower.endsWith(".skel"))
					skeletonInput.text = path;
				else if (lower.endsWith(".json"))
					skeletonInput.text = path;
				else
					showHint("请选择 .skel 或 .json 骨架文件。");
		}
		pendingPicker = null;
	}

	function onPickerError():Void
	{
		// The native dialog is closing (error or cancel): block the pass-through
		// click just like a successful pick.
		inputLockFrames = 12;
		pendingPicker = null;
	}

	// ------------------------------------------------------------------
	// Loading a Spine character (appends to the list)
	// ------------------------------------------------------------------
	function addCharacter():Void
	{
		var atlasPath:String = atlasInput.text.trim();
		var skeletonPath:String = skeletonInput.text.trim();

		if (atlasPath.length == 0 || atlasPath == "path/to/char.atlas")
		{
			showHint("请先选择或填写 Atlas 文件路径。");
			return;
		}
		if (skeletonPath.length == 0 || skeletonPath == "path/to/char.skel or .json")
		{
			showHint("请选择或填写 Skel (.skel) 或 JSON (.json) 骨架文件路径。");
			return;
		}

		// If this exact atlas+skeleton was already loaded, just switch to it
		// instead of creating a duplicate (which would look like "the same
		// character" and make the ◀/▶ buttons appear to do nothing).
		for (ch in characters)
		{
			if (ch.atlasPath == atlasPath && ch.skeletonPath == skeletonPath)
			{
				selectChar(ch);
				showHint("该角色已加载，已切换到它。如需加载不同的角色，请选择其它的 Atlas / 骨架文件。");
				return;
			}
		}

		var lower:String = skeletonPath.toLowerCase();
		var isBinary:Bool = lower.endsWith(".skel");

		try
		{
			#if sys
			if (!sys.FileSystem.exists(atlasPath))
			{
				showHint("Atlas 文件不存在: " + atlasPath);
				return;
			}
			if (!sys.FileSystem.exists(skeletonPath))
			{
				showHint("骨架文件不存在: " + skeletonPath);
				return;
			}
			#end

			var baseDir:String = dirname(atlasPath);
			var atlasContent:String = readText(atlasPath);
			var loader = new spineflixel.SpineViewerTextureLoader(baseDir);
			var atlas:TextureAtlas = new TextureAtlas(atlasContent, loader);
			var attachmentLoader:AtlasAttachmentLoader = new AtlasAttachmentLoader(atlas);

			var skeletonData:SkeletonData;
			if (isBinary)
			{
				var bytes:haxe.io.Bytes = readBytes(skeletonPath);
				var bin:SkeletonBinary = new SkeletonBinary(attachmentLoader);
				bin.scale = 1;
				skeletonData = bin.readSkeletonData(bytes);
			}
			else
			{
				var json:String = readText(skeletonPath);
				var sj:SkeletonJson = new SkeletonJson(attachmentLoader);
				sj.scale = 1;
				skeletonData = sj.readSkeletonData(json);
			}

			var stateData:AnimationStateData = new AnimationStateData(skeletonData);
			var sprite:NoCullSkeletonSprite = new NoCullSkeletonSprite(skeletonData, stateData);
			// Place the new character offset from the center so several of them
			// don't fully overlap; the user can drag them apart afterwards.
			sprite.x = FlxG.width / 2 + characters.length * 180;
			sprite.y = FlxG.height * 0.55;
			sprite.scaleX = 1;
			sprite.scaleY = 1;
			sprite.antialiasing = ClientPrefs.data.antialiasing;
			sprite.active = true;
			sprite.cameras = [FlxG.camera];
			charGroup.add(sprite);

			// Derive a display name from the skeleton file name.
			var nm:String = skeletonPath;
			var slash:Int = nm.lastIndexOf("/");
			var back:Int = nm.lastIndexOf("\\");
			var d:Int = slash > back ? slash : back;
			if (d >= 0)
				nm = nm.substring(d + 1);
			var dot:Int = nm.lastIndexOf(".");
			if (dot > 0)
				nm = nm.substring(0, dot);

			var ch:SpineCharacter = new SpineCharacter(sprite, nm, atlasPath, skeletonPath);
			for (anim in skeletonData.animations)
				ch.animList.push(anim.name);
			for (skin in skeletonData.skins)
				ch.skinNames.push(skin.name);
			ch.curSkin = 0;
			ch.looping = true;
			ch.currentAnim = '';
			characters.push(ch);

			hintText.visible = false;
			selectChar(ch);
			if (ch.animList.length > 0)
				playAnimation(ch.animList[0]);
			updateInfo();
		}
		catch (e:Dynamic)
		{
			showHint("加载失败: " + Std.string(e));
			trace("SpineViewerState.addCharacter error: " + Std.string(e));
		}
	}

	function applyActiveRGB():Void
	{
		if (activeChar == null)
			return;
		var r:Float = rSlider.value;
		var g:Float = gSlider.value;
		var b:Float = bSlider.value;
		activeChar.r = r;
		activeChar.g = g;
		activeChar.b = b;
		var col = activeChar.sprite.skeleton.color;
		col.r = r;
		col.g = g;
		col.b = b;
	}

	function selectChar(c:SpineCharacter):Void
	{
		activeChar = c;
		atlasInput.text = c.atlasPath;
		skeletonInput.text = c.skeletonPath;
		// Reflect this character's stored RGB on the sliders, then apply it.
		if (rSlider != null) rSlider.value = c.r;
		if (gSlider != null) gSlider.value = c.g;
		if (bSlider != null) bSlider.value = c.b;
		applyActiveRGB();
		buildAnimList();
		if (skinBtn != null)
			skinBtn.label.text = c.skinNames.length > 0 ? "Skin: " + c.skinNames[c.curSkin] : "Skin: —";
		if (loopBtn != null)
			loopBtn.label.text = c.looping ? "Loop: ON" : "Loop: OFF";
		updateInfo();
	}

	function cycleActiveChar(dir:Int):Void
	{
		if (characters.length == 0)
			return;
		var idx:Int = characters.indexOf(activeChar);
		if (idx < 0)
			idx = 0;
		idx = (idx + dir + characters.length) % characters.length;
		selectChar(characters[idx]);
	}

	function deleteActiveChar():Void
	{
		if (activeChar == null)
			return;
		var idx:Int = characters.indexOf(activeChar);
		charGroup.remove(activeChar.sprite);
		activeChar.sprite.destroy();
		characters.remove(activeChar);
		if (characters.length > 0)
			selectChar(characters[Std.int(Math.max(0, idx - 1))]);
		else
		{
			activeChar = null;
			buildAnimList();
			updateInfo();
		}
	}

	function buildAnimList():Void
	{
		// Remove and destroy the previous entries
		for (txt in animTexts)
		{
			remove(txt);
			txt.destroy();
		}
		animTexts = [];
		animScroll = 0;

		if (animTitle != null)
		{
			if (activeChar != null)
			{
				var idx:Int = characters.indexOf(activeChar);
				animTitle.text = '${activeChar.name}  (${idx + 1}/${characters.length})';
			}
			else
				animTitle.text = "No Character";
		}

		if (activeChar == null)
		{
			layoutAnimList();
			return;
		}

		var gameFont:String = Paths.font("vcr.ttf");
		var panelX:Float = FlxG.width - PANEL_W + 8;
		for (i in 0...activeChar.animList.length)
		{
			var name:String = activeChar.animList[i];
			var txt:FlxText = new FlxText(panelX, animListTop + i * 22, PANEL_W - 16, name, 14);
			txt.setFormat(gameFont, 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			txt.cameras = [uiCam];
			add(txt);
			animTexts.push(txt);
		}

		layoutAnimList();
	}

	// Position the animation entries inside the right panel and clip any that
	// fall outside it, so a long list scrolls instead of overflowing.
	function layoutAnimList():Void
	{
		var panelTop:Float = animListTop;
		var panelBottom:Float = FlxG.height - 10;
		var visibleHeight:Float = panelBottom - panelTop;
		var totalHeight:Float = animTexts.length * 22;
		var maxScroll:Float = Math.max(0, totalHeight - visibleHeight);
		animScroll = FlxMath.bound(animScroll, 0, maxScroll);

		for (i in 0...animTexts.length)
		{
			var txt:FlxText = animTexts[i];
			var y:Float = panelTop + i * 22 - animScroll;
			txt.y = y;
			txt.visible = (y + 22 > panelTop) && (y < panelBottom);
		}

		// Scrollbar reflecting the current scroll position
		if (animScrollBar != null)
		{
			var barH:Float = maxScroll > 0 ? Math.max(20, visibleHeight * (visibleHeight / totalHeight)) : 20;
			var barY:Float = panelTop + (maxScroll > 0 ? (animScroll / maxScroll) * (visibleHeight - barH) : 0);
			animScrollBar.scale.y = barH / 20;
			animScrollBar.setPosition(FlxG.width - PANEL_W + PANEL_W - 4, barY);
			animScrollBar.visible = (maxScroll > 0);
		}
	}

	// Scroll the animation list with the mouse wheel (clamped + relaid out).
	function scrollAnimList(wheel:Int):Void
	{
		animScroll += wheel * 22;
		layoutAnimList();
	}

	function playAnimation(name:String):Void
	{
		if (activeChar == null)
			return;
		var anim = activeChar.sprite.skeleton.data.findAnimation(name);
		if (anim == null)
			return;
		activeChar.currentAnim = name;
		activeChar.sprite.state.setAnimation(0, anim, activeChar.looping);
		// Re-highlight the active animation in the list
		for (txt in animTexts)
		{
			if (txt.text == name)
				txt.color = FlxColor.YELLOW;
			else
				txt.color = FlxColor.WHITE;
		}
		updateInfo();
	}

	function cycleSkin():Void
	{
		if (activeChar == null || activeChar.skinNames.length == 0)
			return;
		activeChar.curSkin = (activeChar.curSkin + 1) % activeChar.skinNames.length;
		var name:String = activeChar.skinNames[activeChar.curSkin];
		activeChar.sprite.skeleton.skinName = name;
		activeChar.sprite.skeleton.setSlotsToSetupPose();
		skinBtn.label.text = "Skin: " + name;
	}

	function toggleLoop():Void
	{
		if (activeChar == null)
			return;
		activeChar.looping = !activeChar.looping;
		loopBtn.label.text = activeChar.looping ? "Loop: ON" : "Loop: OFF";
		if (activeChar.currentAnim.length > 0)
		{
			var anim = activeChar.sprite.skeleton.data.findAnimation(activeChar.currentAnim);
			if (anim != null)
				activeChar.sprite.state.setAnimation(0, anim, activeChar.looping);
		}
	}

	// ------------------------------------------------------------------
	// Camera / transform controls (per character)
	// ------------------------------------------------------------------
	function resetCamera():Void
	{
		// The Spine character is panned/zoomed via its OWN transform (not the
		// camera), because spine-haxe does not apply camera zoom to the mesh
		// vertices. Keep the camera at identity and reset the active skeleton.
		FlxG.camera.zoom = 1;
		FlxG.camera.scroll.set(0, 0);
		if (activeChar != null)
		{
			activeChar.sprite.scaleX = 1;
			activeChar.sprite.scaleY = 1;
			activeChar.sprite.x = FlxG.width / 2;
			activeChar.sprite.y = FlxG.height * 0.55;
			// Reset per-character RGB tint to white, and sync the sliders.
			activeChar.r = activeChar.g = activeChar.b = 1;
			var col = activeChar.sprite.skeleton.color;
			col.r = col.g = col.b = 1;
			if (rSlider != null) rSlider.value = 1;
			if (gSlider != null) gSlider.value = 1;
			if (bSlider != null) bSlider.value = 1;
		}
		updateInfo();
	}

	// Zoom a specific skeleton around the screen point (sx, sy) so the world
	// point under the cursor stays under the cursor after zooming. (Camera
	// stays at zoom = 1; scaling is done on the skeleton.)
	function zoomChar(c:SpineCharacter, factor:Float, sx:Float, sy:Float):Void
	{
		if (c == null)
			return;
		var s = c.sprite;
		var s0:Float = s.scaleX;
		var s1:Float = FlxMath.bound(s0 * factor, 0.05, 20);
		var f:Float = s1 / s0;

		// W = skeleton-local vertex value currently under the cursor.
		// Keep W fixed at (sx, sy): x1 = sx - offsetX - f * (sx - x0 - offsetX)
		var ox:Float = s.offsetX;
		var oy:Float = s.offsetY;
		s.x = sx - ox - f * (sx - s.x - ox);
		s.y = sy - oy - f * (sy - s.y - oy);
		s.scaleX = s1;
		s.scaleY = s1;
		updateInfo();
	}

	// Topmost character whose *opaque* (alpha != 0) pixel is under the mouse.
	// The bounding box (FlxG.mouse.overlaps) includes transparent margins, so we
	// test the actual drawn triangles and sample the atlas alpha — clicking the
	// transparent edge no longer selects/drags the character.
	function charUnderMouse():SpineCharacter
	{
		var mx:Float = FlxG.mouse.x;
		var my:Float = FlxG.mouse.y;
		var i:Int = characters.length - 1;
		while (i >= 0)
		{
			if (pixelHitTest(characters[i], mx, my))
				return characters[i];
			i--;
		}
		return null;
	}

	// Pixel-perfect hit test for one character. Returns true only if (mx,my)
	// lands inside a visible triangle whose sampled atlas texel is opaque.
	function pixelHitTest(c:SpineCharacter, mx:Float, my:Float):Bool
	{
		var s = c.sprite;
		var verts:Array<Float> = [];
		var drawOrder:Array<spine.Slot> = s.skeleton.drawOrder;
		var i:Int = drawOrder.length - 1;
		while (i >= 0)
		{
			var slot:spine.Slot = drawOrder[i];
			i--;
			var att = slot.attachment;
			var worldX:Array<Float> = null;
			var uvs:Array<Float> = null;
			var tris:Array<Int> = null;
			var tex:Dynamic = null;
			if (Std.isOfType(att, RegionAttachment))
			{
				var region:RegionAttachment = cast att;
				verts.resize(8);
				region.computeWorldVertices(slot, verts, 0, 2);
				worldX = toScreen(s, verts, 4);
				uvs = region.uvs;
				tris = [0, 1, 2, 2, 3, 0];
				tex = cast(region.region, TextureAtlasRegion).page.texture;
			}
			else if (Std.isOfType(att, MeshAttachment))
			{
				var mesh:MeshAttachment = cast att;
				verts.resize(mesh.worldVerticesLength);
				mesh.computeWorldVertices(slot, 0, mesh.worldVerticesLength, verts, 0, 2);
				worldX = toScreen(s, verts, mesh.worldVerticesLength >> 1);
				uvs = mesh.uvs;
				tris = mesh.triangles;
				tex = cast(mesh.region, TextureAtlasRegion).page.texture;
			}
			else
				continue;

			if (pointInTrisScreen(mx, my, worldX, uvs, tris, tex))
				return true;
		}
		return false;
	}

	// Map skeleton-local vertices to screen coordinates, reusing the sprite's
	// own transform (handles scale / angle / offset / position like render()).
	function toScreen(s:NoCullSkeletonSprite, verts:Array<Float>, vcount:Int):Array<Float>
	{
		var out:Array<Float> = [];
		out.resize(vcount * 2);
		var k:Int = 0;
		while (k < vcount)
		{
			var p:Array<Float> = [verts[k * 2], verts[k * 2 + 1]];
			s.skeletonToHaxeWorldCoordinates(p);
			out[k * 2] = p[0];
			out[k * 2 + 1] = p[1];
			k++;
		}
		return out;
	}

	// Barycentric point-in-triangle on screen-space verts. If the point is
	// inside, sample the atlas page at the interpolated UV; return true only
	// when that texel is opaque (alpha >= threshold). tex null -> treat the
	// geometry itself as opaque (safe fallback so a char is never ungrabbable).
	function pointInTrisScreen(px:Float, py:Float, verts:Array<Float>, uvs:Array<Float>,
		tris:Array<Int>, tex:Dynamic):Bool
	{
		var bmp = (tex != null) ? cast(tex, FlxGraphic).bitmap : null;
		var W:Int = (bmp != null) ? bmp.width : 0;
		var Hh:Int = (bmp != null) ? bmp.height : 0;
		var t:Int = 0;
		while (t < tris.length)
		{
			var ia:Int = tris[t], ib:Int = tris[t + 1], ic:Int = tris[t + 2];
			t += 3;
			var ax:Float = verts[ia * 2], ay:Float = verts[ia * 2 + 1];
			var bx:Float = verts[ib * 2], by:Float = verts[ib * 2 + 1];
			var cx:Float = verts[ic * 2], cy:Float = verts[ic * 2 + 1];
			var v0x:Float = bx - ax, v0y:Float = by - ay;
			var v1x:Float = cx - ax, v1y:Float = cy - ay;
			var v2x:Float = px - ax, v2y:Float = py - ay;
			var denom:Float = v0x * v1y - v1x * v0y;
			if (denom == 0)
				continue;
			var w1:Float = (v2x * v1y - v1x * v2y) / denom;
			var w2:Float = (v0x * v2y - v2x * v0y) / denom;
			var w0:Float = 1 - w1 - w2;
			if (w0 >= 0 && w1 >= 0 && w2 >= 0)
			{
				if (bmp == null)
					return true;
				var u:Float = w0 * uvs[ia * 2] + w1 * uvs[ib * 2] + w2 * uvs[ic * 2];
				var v:Float = w0 * uvs[ia * 2 + 1] + w1 * uvs[ib * 2 + 1] + w2 * uvs[ic * 2 + 1];
				var tx:Int = Std.int(u * W);
				var ty:Int = Std.int(v * Hh);
				if (tx >= 0 && tx < W && ty >= 0 && ty < Hh)
				{
					var a:Int = (bmp.getPixel32(tx, ty) >> 24) & 0xFF;
					if (a >= 8)
						return true;
				}
			}
		}
		return false;
	}

	function isOverUI(px:Float, py:Float):Bool
	{
		// Mirror the right-panel wheel check: hit-test against the actual UI
		// sprites so the top bar and right panel are never treated as canvas
		// (no accidental character grab / input overwrite while using the UI).
		if (topBar != null && FlxG.mouse.overlaps(topBar, uiCam))
			return true;
		if (animPanel != null && FlxG.mouse.overlaps(animPanel, uiCam))
			return true;
		return false;
	}

	function updateCamera(elapsed:Float):Void
	{
		// Keyboard pan (skip while typing in an input field) — moves the active char
		var typing:Bool = (PsychUIInputText.focusOn != null);
		var panSpeed:Float = 600 * elapsed; // screen pixels; camera stays at zoom 1
		if (!typing && activeChar != null)
		{
			var s = activeChar.sprite;
			if (controls.UI_LEFT || FlxG.keys.pressed.A) s.x -= panSpeed;
			if (controls.UI_RIGHT || FlxG.keys.pressed.D) s.x += panSpeed;
			if (controls.UI_UP || FlxG.keys.pressed.W) s.y -= panSpeed;
			if (controls.UI_DOWN || FlxG.keys.pressed.S) s.y += panSpeed;

			if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.LBRACKET)
				zoomChar(activeChar, 0.9, FlxG.width / 2, FlxG.height / 2);
			if (FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.RBRACKET)
				zoomChar(activeChar, 1.1, FlxG.width / 2, FlxG.height / 2);
			if (FlxG.keys.justPressed.R)
				resetCamera();
		}

		// TouchPad pan (mobile) — moves the active char
		if (touchPad != null && activeChar != null)
		{
			var s = activeChar.sprite;
			if (touchPad.buttonLeft.pressed) s.x -= panSpeed;
			if (touchPad.buttonRight.pressed) s.x += panSpeed;
			if (touchPad.buttonUp.pressed) s.y -= panSpeed;
			if (touchPad.buttonDown.pressed) s.y += panSpeed;
			if (touchPad.buttonA.justPressed) zoomChar(activeChar, 1.1, FlxG.width / 2, FlxG.height / 2);
			if (touchPad.buttonB.justPressed) zoomChar(activeChar, 0.9, FlxG.width / 2, FlxG.height / 2);
		}

		// Mouse wheel: scroll the animation list when over the right panel,
		// otherwise zoom the character under the cursor (or the active one).
		if (FlxG.mouse.wheel != 0)
		{
			if (FlxG.mouse.overlaps(animPanel, uiCam))
				scrollAnimList(FlxG.mouse.wheel);
			else
			{
				var c:SpineCharacter = charUnderMouse();
				if (c == null)
					c = activeChar;
				if (c != null)
					zoomChar(c, Math.pow(1.1, FlxG.mouse.wheel), FlxG.mouse.x, FlxG.mouse.y);
			}
		}

		// Drag to move: a specific character if one was grabbed, else pan all.
		var mx:Float = FlxG.mouse.x;
		var my:Float = FlxG.mouse.y;
		if (FlxG.mouse.pressed && !awaitingMouseRelease && !isOverUI(mx, my))
		{
			if (!dragging)
			{
				// Begin a drag only when an opaque pixel is grabbed. Clicking
				// the transparent gap starts nothing.
				var hit:SpineCharacter = charUnderMouse();
				if (hit != null)
				{
					dragging = true;
					dragStartMouseX = mx;
					dragStartMouseY = my;
					dragTarget = hit;
					hit.dragStartX = hit.sprite.x;
					hit.dragStartY = hit.sprite.y;
				}
			}
			else if (dragTarget != null)
			{
				var dx:Float = mx - dragStartMouseX;
				var dy:Float = my - dragStartMouseY;
				// Follow the mouse (character moves the same direction as the drag).
			dragTarget.sprite.x = dragTarget.dragStartX + dx;
			dragTarget.sprite.y = dragTarget.dragStartY + dy;
		}
	}
	else
		dragging = false;
}

	override function update(elapsed:Float)
	{
		// A click that "passes through" when a native file dialog closes can
		// instantly grab/drag a character and overwrite the path inputs. Ignore
		// the stray press for a few frames, and only re-arm once the button is
		// actually released.
		if (inputLockFrames > 0)
		{
			inputLockFrames--;
			dragging = false;
			if (FlxG.mouse.pressed)
				awaitingMouseRelease = true;
		}
		else if (awaitingMouseRelease && !FlxG.mouse.pressed)
		{
			awaitingMouseRelease = false;
		}

		if (FlxG.mouse.justPressed && !awaitingMouseRelease)
		{
			var mx:Float = FlxG.mouse.x;
			var my:Float = FlxG.mouse.y;
			if (!isOverUI(mx, my))
			{
				// Only an opaque-pixel hit selects and starts a drag. Clicking
				// the transparent gap does nothing (no drag, no pan).
				var c:SpineCharacter = charUnderMouse();
				if (c != null)
				{
					selectChar(c);
					dragging = true;
					dragStartMouseX = mx;
					dragStartMouseY = my;
					dragTarget = c;
					c.dragStartX = c.sprite.x;
					c.dragStartY = c.sprite.y;
				}
			}
			else if (activeChar != null)
			{
				// Clicked on the panel: play the clicked animation entry.
				for (txt in animTexts)
				{
					if (FlxG.mouse.overlaps(txt, uiCam))
					{
						playAnimation(txt.text);
						break;
					}
				}
			}
		}

		// Back / blur input
		if (controls.BACK)
		{
			if (PsychUIInputText.focusOn != null)
				PsychUIInputText.focusOn = null;
			else
			{
				onBack();
				return;
			}
		}
		if (touchPad != null && touchPad.buttonE.justPressed)
		{
			onBack();
			return;
		}

		updateCamera(elapsed);

		updateInfo();
		super.update(elapsed);
	}

	function onBack():Void
	{
		MusicBeatState.switchState(new MasterEditorMenu());
	}

	// ------------------------------------------------------------------
	// Helpers
	// ------------------------------------------------------------------
	function updateInfo():Void
	{
		if (infoText == null)
			return;
		var n:Int = characters.length;
		var idx:Int = activeChar != null ? characters.indexOf(activeChar) : -1;
		var charInfo:String = activeChar != null ? 'Char: ${activeChar.name} (${idx + 1}/${n})  ' : 'Char: —  ';
		var zoomPct:Int = activeChar != null ? Math.round(activeChar.sprite.scaleX * 100) : 100;
		var skin:String = (activeChar != null && activeChar.skinNames.length > 0) ? activeChar.skinNames[activeChar.curSkin] : "—";
		var anim:String = activeChar != null ? activeChar.currentAnim : "";
		infoText.text = charInfo + 'Zoom: ${zoomPct}%   Anim: ${anim == "" ? "—" : anim}   Skin: ${skin}';
	}

	function showHint(msg:String):Void
	{
		if (hintText != null)
		{
			hintText.text = msg;
			hintText.visible = true;
		}
	}

	function dirname(p:String):String
	{
		var idx:Int = -1;
		var i:Int = p.lastIndexOf("/"); if (i > idx) idx = i;
		var j:Int = p.lastIndexOf("\\"); if (j > idx) idx = j;
		return idx > -1 ? p.substring(0, idx) : "";
	}

	function readText(path:String):String
	{
		#if sys
		if (sys.FileSystem.exists(path))
			return sys.io.File.getContent(path);
		#end
		return openfl.utils.Assets.getText(path);
	}

	function readBytes(path:String):haxe.io.Bytes
	{
		#if sys
		if (sys.FileSystem.exists(path))
			return sys.io.File.getBytes(path);
		#end
		var data = openfl.utils.Assets.getBytes(path);
		return haxe.io.Bytes.ofData(data);
	}
}

/**
 * A single Spine character instance and all of its independently-controlled
 * state (animation list, current skin, loop flag, loaded file paths).
 */
private class SpineCharacter
{
	public var sprite:NoCullSkeletonSprite;
	public var name:String;
	public var atlasPath:String;
	public var skeletonPath:String;
	public var animList:Array<String>;
	public var currentAnim:String;
	public var skinNames:Array<String>;
	public var curSkin:Int;
	public var looping:Bool;
	// Per-character RGB tint (0..1) applied to skeleton.color.
	public var r:Float = 1;
	public var g:Float = 1;
	public var b:Float = 1;
	// Transient: character position captured when a drag starts.
	public var dragStartX:Float;
	public var dragStartY:Float;

	public function new(sprite:NoCullSkeletonSprite, name:String, atlasPath:String, skeletonPath:String)
	{
		this.sprite = sprite;
		this.name = name;
		this.atlasPath = atlasPath;
		this.skeletonPath = skeletonPath;
		this.animList = [];
		this.currentAnim = '';
		this.skinNames = [];
		this.curSkin = 0;
		this.looping = true;
		this.dragStartX = 0;
		this.dragStartY = 0;
	}
}
