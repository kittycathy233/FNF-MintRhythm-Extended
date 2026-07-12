package spineflixel;

import spine.SpineException;
import spine.atlas.TextureAtlasPage;
import spine.atlas.TextureAtlasRegion;
import spine.atlas.TextureLoader;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;

/**
 * TextureLoader that loads atlas page images from an absolute filesystem
 * directory (the directory that contains the chosen `.atlas` file).
 * Falls back to OpenFL `Assets` when the file can't be found on disk,
 * which lets it also resolve textures bundled inside the game/mods.
 *
 * Used by the Spine Viewer toolbox editor so it can render a Spine
 * character loaded straight from disk (atlas + skel/json + png).
 */
class SpineViewerTextureLoader implements TextureLoader
{
	private var baseDir:String;

	public function new(baseDir:String)
	{
		this.baseDir = baseDir;
	}

	public function loadPage(page:TextureAtlasPage, path:String):Void
	{
		var fullPath:String = baseDir + "/" + path;
		var bitmapData:openfl.display.BitmapData = null;

		#if sys
		try {
			if (sys.FileSystem.exists(fullPath))
				bitmapData = openfl.display.BitmapData.fromFile(fullPath);
		} catch (e:Dynamic) {}
		#end

		if (bitmapData == null) {
			try {
				bitmapData = openfl.utils.Assets.getBitmapData(fullPath);
			} catch (e:Dynamic) {}
		}
		if (bitmapData == null) {
			try {
				bitmapData = openfl.utils.Assets.getBitmapData(path);
			} catch (e:Dynamic) {}
		}

		if (bitmapData == null)
			throw new SpineException("Could not load atlas page texture: " + fullPath);

		var texture:FlxGraphic = spine.flixel.SpineTexture.from(bitmapData);
		texture.destroyOnNoUse = false;
		page.texture = texture;
	}

	public function loadRegion(region:TextureAtlasRegion):Void
	{
		region.texture = region.page.texture;
	}

	public function unloadPage(page:TextureAtlasPage):Void
	{
		FlxG.bitmap.remove(cast page.texture);
	}
}
