package states;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

import openfl.utils.Assets;

import spine.SkeletonData;
import spine.Physics;
import spine.SkeletonJson;
import spine.SkeletonBinary;
import spine.atlas.TextureAtlas;
import spine.attachments.AtlasAttachmentLoader;
import spine.animation.AnimationStateData;
import spine.flixel.NoCullSkeletonSprite;
import spineflixel.SpineViewerTextureLoader;

/**
 * Spine 角色加载与剧情资源打包的共享工具，供 StoryPlayerState 与 StoryEditorState 复用。
 */
typedef LoadedSpine =
{
	sprite:NoCullSkeletonSprite,
	skeletonData:SkeletonData,
	anims:Array<String>
}

class StorySpineTools
{
	public static function dirname(p:String):String
	{
		var idx:Int = -1;
		var i:Int = p.lastIndexOf("/"); if (i > idx) idx = i;
		var j:Int = p.lastIndexOf("\\"); if (j > idx) idx = j;
		return idx > -1 ? p.substring(0, idx) : "";
	}

	public static function basename(p:String):String
	{
		var s:String = p;
		var i:Int = s.lastIndexOf("/"); if (i >= 0) s = s.substring(i + 1);
		var j:Int = s.lastIndexOf("\\"); if (j >= 0) s = s.substring(j + 1);
		return s;
	}

	public static function baseNoExt(p:String):String
	{
		var n:String = basename(p);
		var i:Int = n.lastIndexOf(".");
		return (i > 0) ? n.substring(0, i) : n;
	}

	public static function extOf(p:String):String
	{
		var i:Int = p.lastIndexOf(".");
		return (i >= 0) ? p.substring(i) : "";
	}

	public static function readText(path:String):String
	{
		#if sys
		if (FileSystem.exists(path)) return File.getContent(path);
		#end
		return Assets.getText(path);
	}

	public static function readBytes(path:String):haxe.io.Bytes
	{
		#if sys
		if (FileSystem.exists(path)) return File.getBytes(path);
		#end
		var data = Assets.getBytes(path);
		return haxe.io.Bytes.ofData(data);
	}

	/**
	 * 加载一个 Spine 角色，返回 NoCullSkeletonSprite 与动画列表。
	 * atlasPath / skeletonPath 可以是绝对路径，也可以是相对于当前工作目录的相对路径。
	 */
	public static function loadSpine(atlasPath:String, skeletonPath:String, skin:String):LoadedSpine
	{
		var lower:String = skeletonPath.toLowerCase();
		var isBinary:Bool = lower.endsWith(".skel");

		#if sys
		if (!FileSystem.exists(atlasPath)) throw 'Atlas 文件不存在: ' + atlasPath;
		if (!FileSystem.exists(skeletonPath)) throw '骨架文件不存在: ' + skeletonPath;
		#end

		var baseDir:String = dirname(atlasPath);
		var atlasContent:String = readText(atlasPath);
		var loader = new SpineViewerTextureLoader(baseDir);
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

		if (skin != null && skin != '' && skeletonData.findSkin(skin) != null)
		{
			sprite.skeleton.skinName = skin;
			sprite.skeleton.setSlotsToSetupPose();
		}
		sprite.skeleton.updateWorldTransform(Physics.update);

		var anims:Array<String> = [];
		for (a in skeletonData.animations) anims.push(a.name);

		return {sprite: sprite, skeletonData: skeletonData, anims: anims};
	}

	/** 从 atlas 文本里收集引用的贴图文件名（png/webp...），用于打包拷贝。 */
	public static function collectAtlasImages(atlasPath:String):Array<String>
	{
		var out:Array<String> = [];
		var txt:String = readText(atlasPath);
		if (txt == null) return out;
		var lines:Array<String> = txt.split("\n");
		for (ln in lines)
		{
			var s:String = ln.trim();
			var l:String = s.toLowerCase();
			if (l.endsWith(".png") || l.endsWith(".webp") || l.endsWith(".jpg") || l.endsWith(".jpeg"))
				out.push(s);
		}
		return out;
	}

	#if sys
	public static function copyFile(src:String, dst:String):Void
	{
		try
		{
			if (FileSystem.exists(src))
			{
				var d:String = dirname(dst);
				if (d != "" && !FileSystem.exists(d)) FileSystem.createDirectory(d);
				File.copy(src, dst);
			}
		}
		catch (e:Dynamic)
		{
			trace("StorySpineTools.copyFile failed: " + e);
		}
	}
	#end
}
