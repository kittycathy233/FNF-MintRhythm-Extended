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
import states.editors.content.FileDialogHandler;
import spineflixel.SpineViewerTextureLoader;

import spine.SkeletonData;
import spine.SkeletonJson;
import spine.SkeletonBinary;
import spine.atlas.TextureAtlas;
import spine.attachments.AtlasAttachmentLoader;
import spine.animation.AnimationStateData;
import spine.flixel.SkeletonSprite;
import spine.flixel.NoCullSkeletonSprite;

#if desktop
import lime.app.Application;
#end

/**
 * Spine Viewer — a toolbox editor that displays a Spine character (state)
 * loaded directly from disk, with free camera controls (pan / zoom) and
 * buttons to pick the `.atlas`, `.skel` and `.json` files.
 *
 * Controls:
 *   - Drag on the canvas to pan the camera.
 *   - Mouse wheel / [ ] or +/- keys / on-screen buttons to zoom.
 *   - Arrow keys / WASD to pan, R to reset the camera.
 *   - Click an animation name on the right to play it.
 */
class SpineViewerState extends MusicBeatState
{
	// Layout constants
	static final TOP_BAR_H:Int = 40;
	static final PANEL_W:Int = 240;
	static final INPUT_W:Int = 175;

	var uiCam:FlxCamera;

	var charGroup:FlxGroup;

	var skeletonSprite:SkeletonSprite;

	var atlasInput:PsychUIInputText;
	var skeletonInput:PsychUIInputText; // accepts either .skel or .json

	var fileHandler:FileDialogHandler;
	var pendingPicker:String = null; // 'atlas' | 'skel' | 'json'

	#if desktop
	var dropHandler:(String)->Void = null;
	#end

	var animTexts:Array<FlxText> = [];
	var animScroll:Float = 0;
	var animPanel:FlxSprite;
	var animScrollBar:FlxSprite;
	var animList:Array<String> = [];
	var currentAnim:String = '';

	var skinNames:Array<String> = [];
	var curSkin:Int = 0;

	var skinBtn:FlxButton;
	var loopBtn:FlxButton;
	var infoText:FlxText;
	var hintText:FlxText;

	var dragging:Bool = false;
	var dragStartSkeletonX:Float = 0;
	var dragStartSkeletonY:Float = 0;
	var dragStartMouseX:Float = 0;
	var dragStartMouseY:Float = 0;

	var looping:Bool = true;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Spine Viewer", null);
		#end

		// super.create() initializes the psych camera and RESETS FlxG.cameras,
		// which would destroy any camera added before it. So initialize first.
		super.create();

		FlxG.camera.bgColor = 0xFF1a1a24;

		// Reset main camera (used for the Spine character only)
		FlxG.camera.zoom = 1;
		FlxG.camera.scroll.set(0, 0);

		// Single shared camera. We no longer zoom/pan the flixel camera (the
		// Spine character is scaled/translated via its own transform instead),
		// so the UI can safely share the main camera. Layering is therefore
		// controlled by FlxGroup order, not by camera stacking (which was
		// unreliable: the separately-added uiCam ended up rendered *behind* the
		// default camera, putting the character on top of the UI).
		uiCam = FlxG.camera;

		// Group that holds the Spine character. Added before the UI so it always
		// renders behind it.
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
			showHint("已通过拖拽填入路径，点击 Load 加载。");
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
		super.destroy();
	}

	function buildUI():Void
	{
		var gameFont:String = Paths.font("vcr.ttf");
		var y:Float = 6.0;

		// --- Atlas row ---
		var atlasBtn:FlxButton = makeButton(10, y, 70, "Atlas", () -> openPicker("atlas"));
		atlasInput = makeInput(85, y, INPUT_W, "path/to/char.atlas");

		// --- Skeleton row (selective: .skel OR .json, user picks either) ---
		var skelJsonBtn:FlxButton = makeButton(265, y, 80, "Skel/JSON", () -> openPicker("skeleton"));
		skeletonInput = makeInput(350, y, INPUT_W, "path/to/char.skel or .json");

		// --- Action buttons ---
		var loadBtn:FlxButton = makeButton(545, y, 80, "Load", loadSpine);
		var resetBtn:FlxButton = makeButton(630, y, 80, "Reset Cam", resetCamera);
		var zoomOutBtn:FlxButton = makeButton(715, y, 60, "Zoom-", () -> zoomAt(0.9, FlxG.width / 2, FlxG.height / 2));
		var zoomInBtn:FlxButton = makeButton(780, y, 60, "Zoom+", () -> zoomAt(1.1, FlxG.width / 2, FlxG.height / 2));
		var backBtn:FlxButton = makeButton(FlxG.width - 80, y, 70, "Back", onBack);

		// --- Right panel: animation list ---
		var panelX:Float = FlxG.width - PANEL_W;

		// Semi-transparent panel background. The Spine character lives on the
		// main camera (which renders first), so it always stays behind this
		// uiCam panel.
		animPanel = new FlxSprite(panelX, TOP_BAR_H);
		animPanel.makeGraphic(PANEL_W, Math.floor(FlxG.height - TOP_BAR_H), FlxColor.BLACK);
		animPanel.alpha = 0.45;
		animPanel.cameras = [uiCam];
		add(animPanel);

		// Scrollbar for the animation list (hidden when the list fits).
		animScrollBar = new FlxSprite(panelX + PANEL_W - 4, TOP_BAR_H + 94);
		animScrollBar.makeGraphic(4, 20, FlxColor.GRAY);
		animScrollBar.alpha = 0.8;
		animScrollBar.cameras = [uiCam];
		animScrollBar.visible = false;
		add(animScrollBar);

		var title:FlxText = new FlxText(panelX + 8, TOP_BAR_H + 8, PANEL_W - 16, "Animations", 18);
		title.setFormat(gameFont, 18, FlxColor.YELLOW, LEFT, OUTLINE, FlxColor.BLACK);
		title.cameras = [uiCam];
		add(title);

		skinBtn = makeButton(panelX + 8, TOP_BAR_H + 34, PANEL_W - 16, "Skin: —", cycleSkin);
		loopBtn = makeButton(panelX + 8, TOP_BAR_H + 64, PANEL_W - 16, "Loop: ON", toggleLoop);

		animTexts = [];

		// --- Bottom info / hint ---
		infoText = new FlxText(10, FlxG.height - 58, FlxG.width - PANEL_W - 20, "", 14);
		infoText.setFormat(gameFont, 14, FlxColor.LIME, LEFT, OUTLINE, FlxColor.BLACK);
		infoText.cameras = [uiCam];
		add(infoText);

		hintText = new FlxText(10, TOP_BAR_H + 8, FlxG.width - PANEL_W - 20,
			"选择 Atlas 与骨架文件（Skel/JSON 二选一，也可直接填写路径），然后点击 Load。\n"
			+ "拖拽平移视角，滚轮 / [ ] 缩放，方向键 / WASD 平移，R 重置。", 16);
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
		showHint("当前平台不支持系统文件选择，请直接在输入框填写完整路径后点击 Load，或把文件放到可访问目录。");
		#end
	}

	function onPickerComplete():Void
	{
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
		pendingPicker = null;
	}

	// ------------------------------------------------------------------
	// Loading the Spine character
	// ------------------------------------------------------------------
	function loadSpine():Void
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

			// Remove the previous character
			if (skeletonSprite != null)
			{
				charGroup.remove(skeletonSprite);
				skeletonSprite.destroy();
				skeletonSprite = null;
			}

			var stateData:AnimationStateData = new AnimationStateData(skeletonData);
			skeletonSprite = new NoCullSkeletonSprite(skeletonData, stateData);
			skeletonSprite.x = FlxG.width / 2;
			skeletonSprite.y = FlxG.height * 0.55;
			skeletonSprite.scaleX = 1;
			skeletonSprite.scaleY = 1;
			skeletonSprite.antialiasing = ClientPrefs.data.antialiasing;
			skeletonSprite.active = true;
			skeletonSprite.cameras = [FlxG.camera];
			charGroup.add(skeletonSprite);

			// Build animation + skin lists
			animList = [];
			for (anim in skeletonData.animations)
				animList.push(anim.name);
			buildAnimList();

			skinNames = [];
			for (skin in skeletonData.skins)
				skinNames.push(skin.name);
			curSkin = 0;
			if (skinBtn != null)
				skinBtn.label.text = skinNames.length > 0 ? "Skin: " + skinNames[0] : "Skin: —";

			currentAnim = '';
			if (animList.length > 0)
				playAnimation(animList[0]);

			hintText.visible = false;
			resetCamera();
			updateInfo();
		}
		catch (e:Dynamic)
		{
			showHint("加载失败: " + Std.string(e));
			trace("SpineViewerState.loadSpine error: " + Std.string(e));
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

		var gameFont:String = Paths.font("vcr.ttf");
		var panelX:Float = FlxG.width - PANEL_W + 8;
		var startY:Float = TOP_BAR_H + 94;
		for (i in 0...animList.length)
		{
			var name:String = animList[i];
			var txt:FlxText = new FlxText(panelX, startY + i * 22, PANEL_W - 16, name, 14);
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
		var panelX:Float = FlxG.width - PANEL_W;
		var panelTop:Float = TOP_BAR_H + 94;
		var panelBottom:Float = FlxG.height - 10;
		var visibleHeight:Float = panelBottom - panelTop;
		var totalHeight:Float = animList.length * 22;
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
			animScrollBar.setPosition(panelX + PANEL_W - 4, barY);
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
		if (skeletonSprite == null)
			return;
		var anim = skeletonSprite.skeleton.data.findAnimation(name);
		if (anim == null)
			return;
		currentAnim = name;
		skeletonSprite.state.setAnimation(0, anim, looping);
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
		if (skeletonSprite == null || skinNames.length == 0)
			return;
		curSkin = (curSkin + 1) % skinNames.length;
		var name:String = skinNames[curSkin];
		skeletonSprite.skeleton.skinName = name;
		skeletonSprite.skeleton.setSlotsToSetupPose();
		skinBtn.label.text = "Skin: " + name;
	}

	function toggleLoop():Void
	{
		looping = !looping;
		loopBtn.label.text = looping ? "Loop: ON" : "Loop: OFF";
		if (skeletonSprite != null && currentAnim.length > 0)
		{
			var anim = skeletonSprite.skeleton.data.findAnimation(currentAnim);
			if (anim != null)
				skeletonSprite.state.setAnimation(0, anim, looping);
		}
	}

	// ------------------------------------------------------------------
	// Camera controls
	// ------------------------------------------------------------------
	function resetCamera():Void
	{
		// The Spine character is panned/zoomed via its OWN transform (not the
		// camera), because spine-haxe does not apply camera zoom to the mesh
		// vertices. Keep the camera at identity and reset the skeleton instead.
		FlxG.camera.zoom = 1;
		FlxG.camera.scroll.set(0, 0);
		if (skeletonSprite != null)
		{
			skeletonSprite.scaleX = 1;
			skeletonSprite.scaleY = 1;
			skeletonSprite.x = FlxG.width / 2;
			skeletonSprite.y = FlxG.height * 0.55;
		}
		updateInfo();
	}

	// Zoom the skeleton around the screen point (sx, sy) so that the world
	// point currently under the cursor stays under the cursor after zooming.
	// (Camera stays at zoom = 1; scaling is done on the skeleton, which
	// spine-haxe bakes correctly into the mesh vertices.)
	function zoomAt(factor:Float, sx:Float, sy:Float):Void
	{
		if (skeletonSprite == null)
			return;

		var s0:Float = skeletonSprite.scaleX;
		var s1:Float = FlxMath.bound(s0 * factor, 0.05, 20);
		var f:Float = s1 / s0;

		// W = skeleton-local vertex value currently under the cursor.
		// Keep W fixed at (sx, sy): x1 = sx - offsetX - f * (sx - x0 - offsetX)
		var ox:Float = skeletonSprite.offsetX;
		var oy:Float = skeletonSprite.offsetY;
		skeletonSprite.x = sx - ox - f * (sx - skeletonSprite.x - ox);
		skeletonSprite.y = sy - oy - f * (sy - skeletonSprite.y - oy);
		skeletonSprite.scaleX = s1;
		skeletonSprite.scaleY = s1;
		updateInfo();
	}

	function isOverUI(px:Float, py:Float):Bool
	{
		// Top bar and right panel are reserved for UI; canvas is the rest.
		return (py <= TOP_BAR_H) || (px >= FlxG.width - PANEL_W);
	}

	function updateCamera(elapsed:Float):Void
	{
		// Keyboard pan (skip while typing in an input field)
		var typing:Bool = (PsychUIInputText.focusOn != null);
		var panSpeed:Float = 600 * elapsed; // screen pixels; camera stays at zoom 1
		if (!typing && skeletonSprite != null)
		{
			if (controls.UI_LEFT || FlxG.keys.pressed.A) skeletonSprite.x -= panSpeed;
			if (controls.UI_RIGHT || FlxG.keys.pressed.D) skeletonSprite.x += panSpeed;
			if (controls.UI_UP || FlxG.keys.pressed.W) skeletonSprite.y -= panSpeed;
			if (controls.UI_DOWN || FlxG.keys.pressed.S) skeletonSprite.y += panSpeed;

			if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.LBRACKET)
				zoomAt(0.9, FlxG.width / 2, FlxG.height / 2);
			if (FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.RBRACKET)
				zoomAt(1.1, FlxG.width / 2, FlxG.height / 2);
			if (FlxG.keys.justPressed.R)
				resetCamera();
		}

		// TouchPad pan (mobile)
		if (touchPad != null && skeletonSprite != null)
		{
			if (touchPad.buttonLeft.pressed) skeletonSprite.x -= panSpeed;
			if (touchPad.buttonRight.pressed) skeletonSprite.x += panSpeed;
			if (touchPad.buttonUp.pressed) skeletonSprite.y -= panSpeed;
			if (touchPad.buttonDown.pressed) skeletonSprite.y += panSpeed;
			if (touchPad.buttonA.justPressed) zoomAt(1.1, FlxG.width / 2, FlxG.height / 2);
			if (touchPad.buttonB.justPressed) zoomAt(0.9, FlxG.width / 2, FlxG.height / 2);
		}

		// Mouse wheel: scroll the animation list when over the right panel,
		// otherwise zoom the character (around the cursor).
		if (FlxG.mouse.wheel != 0)
		{
			if (FlxG.mouse.overlaps(animPanel, uiCam))
				scrollAnimList(FlxG.mouse.wheel);
			else if (skeletonSprite != null)
				zoomAt(Math.pow(1.1, FlxG.mouse.wheel), FlxG.mouse.x, FlxG.mouse.y);
		}

		// Drag to pan (only on the canvas, not over UI)
		var mx:Float = FlxG.mouse.x;
		var my:Float = FlxG.mouse.y;
		if (FlxG.mouse.pressed && !isOverUI(mx, my) && skeletonSprite != null)
		{
			if (!dragging)
			{
				dragging = true;
				dragStartSkeletonX = skeletonSprite.x;
				dragStartSkeletonY = skeletonSprite.y;
				dragStartMouseX = mx;
				dragStartMouseY = my;
			}
			else
			{
				// 1:1 screen pixels (camera is at zoom 1, so world delta == screen delta)
				skeletonSprite.x = dragStartSkeletonX - (mx - dragStartMouseX);
				skeletonSprite.y = dragStartSkeletonY - (my - dragStartMouseY);
			}
		}
		else
			dragging = false;
	}

	override function update(elapsed:Float)
	{
		// Click an animation entry to play it
		if (FlxG.mouse.justPressed && skeletonSprite != null)
		{
			for (txt in animTexts)
			{
				if (FlxG.mouse.overlaps(txt, uiCam))
				{
					playAnimation(txt.text);
					break;
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
		var zoomPct:Int = Math.round((skeletonSprite != null ? skeletonSprite.scaleX : 1) * 100);
		var skin:String = (skeletonSprite != null && skinNames.length > 0) ? skinNames[curSkin] : "—";
		infoText.text = 'Zoom: ${zoomPct}%   Anim: ${currentAnim == "" ? "—" : currentAnim}   Skin: ${skin}';
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
