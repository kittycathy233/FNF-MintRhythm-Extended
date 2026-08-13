package psychlua;

import spine.SkeletonData;
import spine.SkeletonJson;
import spine.SkeletonBinary;
import spine.animation.Animation;
import spine.animation.AnimationStateData;
import spine.animation.MixBlend;
import spine.animation.MixDirection;
import spine.atlas.TextureAtlas;
import spine.atlas.TextureAtlasPage;
import spine.atlas.TextureLoader;
import spine.attachments.AtlasAttachmentLoader;
import spine.flixel.SkeletonSprite;
import spine.flixel.NoCullSkeletonSprite;
import spine.Physics;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxDestroyUtil;
import backend.Paths;
import states.PlayState;
import substates.GameOverSubstate;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
import haxe.io.Bytes;
#end

#if LUA_ALLOWED

class ModSpineTextureLoader implements TextureLoader
{
	private var baseDir:String;
	private var fromFileSystem:Bool;

	public function new(baseDir:String, ?fromFileSystem:Bool = true) {
		this.baseDir = baseDir;
		this.fromFileSystem = fromFileSystem;
	}

	public function loadPage(page:TextureAtlasPage, path:String):Void
	{
		var fullPath:String = baseDir + "/" + path;
		var bitmapData:openfl.display.BitmapData = null;

		#if MODS_ALLOWED
		if(fromFileSystem && baseDir.length > 0) {
			try {
				if(FileSystem.exists(fullPath)) {
					bitmapData = openfl.display.BitmapData.fromFile(fullPath);
				}
			} catch(e:Dynamic) {
				FunkinLua.luaTrace('ModSpineTextureLoader: Failed to load from file: ' + fullPath, false, false, FlxColor.RED);
			}
		}

		if(bitmapData == null) {
			try {
				var imageKey:String = path;
				if(baseDir.length > 0) {
					var idx = baseDir.indexOf("/images/");
					if(idx != -1) {
						imageKey = baseDir.substring(idx + 1) + "/" + path;
					} else if(baseDir.endsWith("/")) {
						imageKey = baseDir + path;
					} else {
						imageKey = baseDir + "/" + path;
					}
				}

				var modded = Paths.modFolders(imageKey);
				if(FileSystem.exists(modded)) {
					bitmapData = openfl.display.BitmapData.fromFile(modded);
				}
			} catch(e:Dynamic) {
			}
		}
		#end

		if(bitmapData == null) {
			try {
				bitmapData = openfl.utils.Assets.getBitmapData(fullPath);
			} catch(e:Dynamic) {
			}
		}

		if(bitmapData == null) {
			try {
				bitmapData = openfl.utils.Assets.getBitmapData(path);
			} catch(e:Dynamic) {
			}
		}

		if(bitmapData == null) {
			FunkinLua.luaTrace('ModSpineTextureLoader: Could not load: ' + fullPath + ' (tried: ' + path + ')', false, false, FlxColor.RED);
			throw new spine.SpineException("Could not load atlas page texture " + fullPath);
		}

		FunkinLua.luaTrace('ModSpineTextureLoader: Loaded texture: ' + fullPath);
		var texture:FlxGraphic = spine.flixel.SpineTexture.from(bitmapData);
		texture.destroyOnNoUse = false;
		page.texture = texture;
	}

	public function loadRegion(region:spine.atlas.TextureAtlasRegion):Void {
		region.texture = region.page.texture;
	}

	public function unloadPage(page:TextureAtlasPage):Void
	{
		FlxG.bitmap.remove(cast page.texture);
	}
}

class SpineFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;
		
		Lua_helper.add_callback(lua, "makeSpineSprite", function(tag:String, skeletonPath:String, atlasPath:String, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');

			var existingSprite = MusicBeatState.getVariables().get(tag);
			if(existingSprite != null)
			{
				existingSprite.destroy();
				MusicBeatState.getVariables().remove(tag);
			}

			try {
				var skeletonData = loadSkeletonData(funk, skeletonPath, atlasPath);
				if(skeletonData != null) {
					var stateData = new AnimationStateData(skeletonData);
					var sprite = new NoCullSkeletonSprite(skeletonData, stateData);
					sprite.x = x;
					sprite.y = y;
					sprite.active = true;

					if(skeletonData.animations != null && skeletonData.animations.length > 0) {
						try {
							sprite.setBoundingBox(skeletonData.animations[0], false);
						} catch(e:Dynamic) {}
					}

					MusicBeatState.getVariables().set(tag, sprite);
					return true;
				}
			} catch(e:Dynamic) {
				FunkinLua.luaTrace('makeSpineSprite: Error: ' + Std.string(e), false, false, FlxColor.RED);
			}
			return false;
		});

		Lua_helper.add_callback(lua, "spineSpriteExists", function(tag:String) {
			var obj = MusicBeatState.getVariables().get(tag);
			return (obj != null && Std.isOfType(obj, SkeletonSprite) || Std.isOfType(obj, NoCullSkeletonSprite));
		});

		Lua_helper.add_callback(lua, "addSpineSprite", function(tag:String, ?inFront:Bool = false) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var ps:PlayState = PlayState.instance;
			if(ps == null) return;

			// 若 sprite 尚未加入任何相机 group，先为其创建一个默认 camGame 组
			var grpKey = '_spcam_' + tag;
			if(MusicBeatState.getVariables().get(grpKey) == null)
				getSpineCameraGroup(tag, ps.camGame);

			var group:FlxTypedGroup<SkeletonSprite> = cast MusicBeatState.getVariables().get(grpKey);
			if(group == null) return;

			var instance = LuaUtils.getTargetInstance();
			if(inFront)
				instance.add(group);
			else
			{
				if(ps.isDead)
				{
					if(GameOverSubstate.instance != null)
						GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), group);
				}
				else
					instance.insert(instance.members.indexOf(LuaUtils.getLowestCharacterGroup()), group);
			}
		});

		Lua_helper.add_callback(lua, "removeSpineSprite", function(tag:String, destroy:Bool = true) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var instance = LuaUtils.getTargetInstance();
			instance.remove(sprite, true);
			
			if(destroy)
			{
				MusicBeatState.getVariables().remove(tag);
				sprite.destroy();
			}
		});

		Lua_helper.add_callback(lua, "spineSetAnimation", function(tag:String, trackIndex:Int, animationName:String, loop:Bool = true) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return false;

			try {
				var animation = sprite.skeleton.data.findAnimation(animationName);
				if(animation != null) {
					sprite.state.setAnimation(trackIndex, animation, loop);
					return true;
				}
				return false;
			} catch(e:Dynamic) {
				return false;
			}
		});

		Lua_helper.add_callback(lua, "spineAddAnimation", function(tag:String, trackIndex:Int, animationName:String, loop:Bool = true, delay:Float = 0) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return false;

			try {
				var animation = sprite.skeleton.data.findAnimation(animationName);
				if(animation != null) {
					sprite.state.addAnimation(trackIndex, animation, loop, delay);
					return true;
				}
				return false;
			} catch(e:Dynamic) {
				return false;
			}
		});

		Lua_helper.add_callback(lua, "spineClearTrack", function(tag:String, trackIndex:Int) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.state.clearTrack(trackIndex);
		});

		Lua_helper.add_callback(lua, "spineClearTracks", function(tag:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.state.clearTracks();
		});

		Lua_helper.add_callback(lua, "spineSetMix", function(tag:String, fromAnimation:String, toAnimation:String, duration:Float) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var fromAnim = sprite.skeleton.data.findAnimation(fromAnimation);
			var toAnim = sprite.skeleton.data.findAnimation(toAnimation);
			if(fromAnim != null && toAnim != null) {
				sprite.stateData.setMix(fromAnim, toAnim, duration);
			}
		});

		Lua_helper.add_callback(lua, "spineSetPosition", function(tag:String, x:Float, y:Float) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.x = x;
			sprite.y = y;
		});

		Lua_helper.add_callback(lua, "spineSetScale", function(tag:String, scaleX:Float, scaleY:Float) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.scaleX = scaleX;
			sprite.scaleY = scaleY;
		});

		Lua_helper.add_callback(lua, "spineSetAlpha", function(tag:String, alpha:Float) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.alpha = alpha;
		});

		Lua_helper.add_callback(lua, "spineSetColor", function(tag:String, color:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.color = FlxColor.fromString(color);
		});

		Lua_helper.add_callback(lua, "spineSetAngle", function(tag:String, angle:Float) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.angle = angle;
		});

		Lua_helper.add_callback(lua, "spineSetFlip", function(tag:String, flipX:Bool, flipY:Bool) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.flipX = flipX;
			sprite.flipY = flipY;
		});

		Lua_helper.add_callback(lua, "spineSetAntialiasing", function(tag:String, enabled:Bool) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.antialiasing = enabled;
		});

		Lua_helper.add_callback(lua, "spineSetBoundingBox", function(tag:String, ?animationName:String, clip:Bool = false) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			if(animationName != null && animationName.length > 0) {
				var animation = sprite.skeleton.data.findAnimation(animationName);
				if(animation != null) {
					sprite.setBoundingBox(animation, clip);
					return;
				}
			}
			sprite.setBoundingBox(null, clip);
		});

		Lua_helper.add_callback(lua, "spineGetBonePosition", function(tag:String, boneName:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return null;

			var bone = sprite.skeleton.findBone(boneName);
			if(bone == null) return null;

			return [bone.worldX, bone.worldY];
		});

		Lua_helper.add_callback(lua, "spineSetBonePosition", function(tag:String, boneName:String, x:Float, y:Float) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return false;

			var bone = sprite.skeleton.findBone(boneName);
			if(bone == null) return false;

			bone.x = x;
			bone.y = y;
			sprite.skeleton.updateWorldTransform(Physics.update);
			return true;
		});

		Lua_helper.add_callback(lua, "spineGetAttachmentPosition", function(tag:String, slotName:String, attachmentName:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return null;

			var slot = sprite.skeleton.findSlot(slotName);
			if(slot == null) return null;

			return [slot.bone.worldX, slot.bone.worldY];
		});

		Lua_helper.add_callback(lua, "spineGetAnimations", function(tag:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return [];

			var animations = sprite.skeleton.data.animations;
			var names:Array<String> = [];
			for(anim in animations) {
				names.push(anim.name);
			}
			return names;
		});

		Lua_helper.add_callback(lua, "spineSetAnimationSpeed", function(tag:String, trackIndex:Int, speed:Float) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var entry = sprite.state.getCurrent(trackIndex);
			if(entry != null) {
				entry.timeScale = speed;
			}
		});

		Lua_helper.add_callback(lua, "spineScreenCenter", function(tag:String, pos:String = 'xy') {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			switch(pos.trim().toLowerCase())
			{
				case 'x':
					sprite.screenCenter(X);
				case 'y':
					sprite.screenCenter(Y);
				default:
					sprite.screenCenter(XY);
			}
		});

		Lua_helper.add_callback(lua, "spineComputeFullBounds", function(tag:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var skeletonData = sprite.skeleton.data;
			if(skeletonData.animations == null || skeletonData.animations.length == 0) return;

			var minX = 100000000.0;
			var maxX = -100000000.0;
			var minY = 100000000.0;
			var maxY = -100000000.0;

			var foundValid = false;
			var steps = 100;

			for(anim in skeletonData.animations) {
				try {
					var stepTime = anim.duration != 0 ? anim.duration / steps : 0;
					var time = 0.0;

					for(i in 0...steps) {
						sprite.skeleton.setToSetupPose();
						anim.apply(sprite.skeleton, time, time, false, [], 1, MixBlend.setup, MixDirection.mixIn);
						sprite.skeleton.updateWorldTransform(Physics.update);
						var boundsSkel = sprite.skeleton.getBounds();

						if(!Math.isNaN(boundsSkel.x) && !Math.isNaN(boundsSkel.y) && !Math.isNaN(boundsSkel.width) && !Math.isNaN(boundsSkel.height)) {
							minX = Math.min(boundsSkel.x, minX);
							minY = Math.min(boundsSkel.y, minY);
							maxX = Math.max(boundsSkel.x + boundsSkel.width, maxX);
							maxY = Math.max(boundsSkel.y + boundsSkel.height, maxY);
							foundValid = true;
						}
						time += stepTime;
					}
				} catch(e:Dynamic) {}
			}

			if(foundValid) {
				sprite.width = maxX - minX;
				sprite.height = maxY - minY;
				sprite.offsetX = -minX;
				sprite.offsetY = -minY;
			}
		});

		Lua_helper.add_callback(lua, "spineSetOriginOffset", function(tag:String, offsetX:Float, offsetY:Float) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.offsetX = offsetX;
			sprite.offsetY = offsetY;
		});

		Lua_helper.add_callback(lua, "spineSetSize", function(tag:String, width:Float, height:Float) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.width = width;
			sprite.height = height;
		});

		Lua_helper.add_callback(lua, "spineGetInfo", function(tag:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return null;

			return {
				width: sprite.width,
				height: sprite.height,
				offsetX: sprite.offsetX,
				offsetY: sprite.offsetY,
				x: sprite.x,
				y: sprite.y,
				scaleX: sprite.scaleX,
				scaleY: sprite.scaleY,
				alpha: sprite.alpha,
				angle: sprite.angle,
				flipX: sprite.flipX,
				flipY: sprite.flipY,
				antialiasing: sprite.antialiasing
			};
		});

		Lua_helper.add_callback(lua, "spineSetVisible", function(tag:String, visible:Bool) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			sprite.visible = visible;
		});

		// ------------------------------------------------------------------
		// 兼容性层：图层位置 / 相机控制
		// ------------------------------------------------------------------

		/**
		 * 把 spine 角色分配到指定相机（camGame / camArchived / camHUD 等）。
		 * cameraName 不区分大小写，未识别时保留原相机不变并打印警告。
		 *
		 * 原理：Spine sprite 继承自 FlxObject，无 cameras 属性。
		 * 我们通过一个专用的 FlxTypedGroup（存于 $__spcam_{tag}）控制相机，
		 * 该 group 加入 PlayState 后由 cameras 决定渲染在哪个相机上。
		 */
		Lua_helper.add_callback(lua, "spineSetCamera", function(tag:String, cameraName:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var ps:PlayState = PlayState.instance;
			if(ps == null) return;

			var camNameLower:String = cameraName.toLowerCase();
			var targetCam:FlxCamera = null;
			switch(camNameLower)
			{
				case 'game':      targetCam = ps.camGame;
				case 'archived':  targetCam = ps.camArchived;
				case 'hud':       targetCam = ps.camHUD;
				default:
					FunkinLua.luaTrace('spineSetCamera: 未知相机名 "' + cameraName + '"，保留原相机', false, false, FlxColor.YELLOW);
					return;
			}
			if(targetCam != null) {
				var group:FlxTypedGroup<SkeletonSprite> = getSpineCameraGroup(tag, targetCam);
				// 若 group 已加入某个 state，先将其移入目标 state 以更新 cameras
				var instance = LuaUtils.getTargetInstance();
				instance.add(group);
			}
		});

		/**
		 * 返回 spine 角色在当前 state members 数组中的索引（图层位置）。
		 * 值越大越靠前（渲染顺序）。找不到时返回 -1。
		 */
		Lua_helper.add_callback(lua, "spineGetLayer", function(tag:String):Int {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return -1;

			// 优先在相机 group 中查找；若不在 group 中则退回 state members
			var grpKey = '_spcam_' + tag;
			var group:FlxTypedGroup<SkeletonSprite> = cast MusicBeatState.getVariables().get(grpKey);
			if(group != null)
				return group.members.indexOf(sprite);

			var instance = LuaUtils.getTargetInstance();
			return instance.members.indexOf(sprite);
		});

		/**
		 * 把 spine 角色移动到指定图层索引。
		 * layerIndex 越大越靠前；传入 -1 等价于 bringToFront。
		 */
		Lua_helper.add_callback(lua, "spineSetLayer", function(tag:String, layerIndex:Int) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var instance = LuaUtils.getTargetInstance();
			var currentIdx:Int = instance.members.indexOf(sprite);
			if(currentIdx < 0) return;

			var targetIdx:Int = (layerIndex == -1) ? instance.members.length : layerIndex;
			instance.remove(sprite, false);
			instance.insert(Std.int(Math.max(0, Math.min(targetIdx, instance.members.length))), sprite);
		});

		/** 把 spine 角色移到最前面（最高图层）。 */
		Lua_helper.add_callback(lua, "spineBringToFront", function(tag:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var instance = LuaUtils.getTargetInstance();
			var idx:Int = instance.members.indexOf(sprite);
			if(idx < 0) return;

			instance.remove(sprite, false);
			instance.insert(instance.members.length, sprite);
		});

		/** 把 spine 角色移到最后面（最低图层）。 */
		Lua_helper.add_callback(lua, "spineSendToBack", function(tag:String) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var instance = LuaUtils.getTargetInstance();
			var idx:Int = instance.members.indexOf(sprite);
			if(idx < 0) return;

			instance.remove(sprite, false);
			instance.insert(0, sprite);
		});

		/**
		 * 交换两个 spine 角色的图层位置（不销毁对象）。
		 * 若任一 tag 不存在则忽略并打印警告。
		 */
		Lua_helper.add_callback(lua, "spineSwapLayers", function(tag1:String, tag2:String) {
			var sprite1:SkeletonSprite = cast MusicBeatState.getVariables().get(tag1);
			var sprite2:SkeletonSprite = cast MusicBeatState.getVariables().get(tag2);
			if(sprite1 == null || sprite2 == null)
			{
				FunkinLua.luaTrace('spineSwapLayers: 找不到角色 "' + (sprite1 == null ? tag1 : tag2) + '"', false, false, FlxColor.YELLOW);
				return;
			}

			var instance = LuaUtils.getTargetInstance();
			var idx1:Int = instance.members.indexOf(sprite1);
			var idx2:Int = instance.members.indexOf(sprite2);
			if(idx1 < 0 || idx2 < 0) return;

			instance.remove(sprite1, false);
			instance.remove(sprite2, false);
			instance.insert(idx2, sprite1);
			instance.insert(idx1, sprite2);
		});

		/** 按偏移量移动 spine 角色的图层位置（正数上移，负数下移）。 */
		Lua_helper.add_callback(lua, "spineMoveLayer", function(tag:String, delta:Int) {
			var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
			if(sprite == null) return;

			var instance = LuaUtils.getTargetInstance();
			var currentIdx:Int = instance.members.indexOf(sprite);
			if(currentIdx < 0) return;

			var targetIdx:Int = currentIdx + delta;
			instance.remove(sprite, false);
			instance.insert(Std.int(Math.max(0, Math.min(targetIdx, instance.members.length))), sprite);
		});
	}

	/**
	 * 获取或创建指定 tag 对应的相机 group。
	 * 若 group 已存在则直接返回；否则新建并注册到 MusicBeatState 变量表中。
	 */
	private static function getSpineCameraGroup(tag:String, ?defaultCam:FlxCamera):FlxTypedGroup<SkeletonSprite> {
		var grpKey = '_spcam_' + tag;
		var existing = MusicBeatState.getVariables().get(grpKey);
		if(existing != null) return cast existing;

		var group = new FlxTypedGroup<SkeletonSprite>();
		group.cameras = (defaultCam != null) ? [defaultCam] : [];

		var sprite:SkeletonSprite = cast MusicBeatState.getVariables().get(tag);
		if(sprite != null)
			group.add(sprite);

		MusicBeatState.getVariables().set(grpKey, group);
		return group;
	}

	private static function getScriptDirectory(funk:FunkinLua):String {
		var scriptName = funk.scriptName;
		var slashIndex = scriptName.lastIndexOf("/");
		if(slashIndex != -1) {
			return scriptName.substring(0, slashIndex);
		}
		return "";
	}

	private static function resolveSpinePath(funk:FunkinLua, filePath:String):String {
		if(filePath == null || filePath.length == 0) return "";

		var imagePath:String = filePath;
		if(!filePath.toLowerCase().startsWith("images/") && !filePath.toLowerCase().startsWith("assets/")) {
			imagePath = "images/" + filePath;
		}

		#if MODS_ALLOWED
		var moddedImage = Paths.modFolders(imagePath);
		if(FileSystem.exists(moddedImage)) {
			return moddedImage;
		}

		var moddedRoot = Paths.modFolders(filePath);
		if(FileSystem.exists(moddedRoot)) {
			return moddedRoot;
		}

		var scriptDir = getScriptDirectory(funk);
		if(scriptDir.length > 0) {
			var scriptPath = scriptDir + "/" + filePath;
			if(FileSystem.exists(scriptPath)) {
				return scriptPath;
			}
			var scriptImagePath = scriptDir + "/" + imagePath;
			if(FileSystem.exists(scriptImagePath)) {
				return scriptImagePath;
			}
		}
		#end

		if(openfl.utils.Assets.exists(imagePath)) {
			return imagePath;
		}
		if(openfl.utils.Assets.exists(filePath)) {
			return filePath;
		}

		return filePath;
	}

	private static function loadSkeletonData(funk:FunkinLua, skeletonPath:String, atlasPath:String):Null<SkeletonData> {
		try {
			var resolvedAtlasPath = resolveSpinePath(funk, atlasPath);
			var atlasContent:String = "";
			var baseDir:String = "";
			var atlasFromFileSystem:Bool = false;

			#if MODS_ALLOWED
			if(FileSystem.exists(resolvedAtlasPath)) {
				atlasContent = File.getContent(resolvedAtlasPath);
				atlasFromFileSystem = true;
				var slashIdx = resolvedAtlasPath.lastIndexOf("/");
				if(slashIdx != -1) {
					baseDir = resolvedAtlasPath.substring(0, slashIdx);
				}
			} else
			#end
			{
				atlasContent = openfl.utils.Assets.getText(resolvedAtlasPath);
				var slashIdx = resolvedAtlasPath.lastIndexOf("/");
				if(slashIdx != -1) {
					baseDir = resolvedAtlasPath.substring(0, slashIdx);
				}
			}

			var textureLoader = new ModSpineTextureLoader(baseDir, atlasFromFileSystem);
			var atlas = new TextureAtlas(atlasContent, textureLoader);
			var attachmentLoader = new AtlasAttachmentLoader(atlas);

			var resolvedSkeletonPath = resolveSpinePath(funk, skeletonPath);
			var skeletonData:SkeletonData;

			if(skeletonPath.toLowerCase().endsWith(".skel")) {
				skeletonData = loadBinarySkeletonData(resolvedSkeletonPath, attachmentLoader);
			} else {
				skeletonData = loadJsonSkeletonData(resolvedSkeletonPath, attachmentLoader);
			}

			return skeletonData;
		} catch(e:Dynamic) {
			FunkinLua.luaTrace('loadSkeletonData: Error: ' + Std.string(e), false, false, FlxColor.RED);
			return null;
		}
	}

	private static function loadJsonSkeletonData(jsonPath:String, attachmentLoader:AtlasAttachmentLoader):SkeletonData {
		var jsonContent:String;
		#if MODS_ALLOWED
		if(FileSystem.exists(jsonPath)) {
			jsonContent = File.getContent(jsonPath);
		} else {
			jsonContent = openfl.utils.Assets.getText(jsonPath);
		}
		#else
		jsonContent = openfl.utils.Assets.getText(jsonPath);
		#end

		var skeletonJson = new SkeletonJson(attachmentLoader);
		skeletonJson.scale = 1;
		return skeletonJson.readSkeletonData(jsonContent);
	}

	private static function loadBinarySkeletonData(binaryPath:String, attachmentLoader:AtlasAttachmentLoader):SkeletonData {
		var bytes:Bytes;
		#if MODS_ALLOWED
		if(FileSystem.exists(binaryPath)) {
			bytes = File.getBytes(binaryPath);
		} else {
			var bytesData:haxe.io.BytesData = openfl.utils.Assets.getBytes(binaryPath);
			bytes = Bytes.ofData(bytesData);
		}
		#else
		var bytesData:haxe.io.BytesData = openfl.utils.Assets.getBytes(binaryPath);
		bytes = Bytes.ofData(bytesData);
		#end

		var skeletonBinary = new SkeletonBinary(attachmentLoader);
		skeletonBinary.scale = 1;
		return skeletonBinary.readSkeletonData(bytes);
	}
}
#end
