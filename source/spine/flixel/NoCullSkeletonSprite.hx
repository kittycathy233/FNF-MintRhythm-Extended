package spine.flixel;

import spine.SkeletonData;
import spine.animation.AnimationStateData;
import flixel.FlxCamera;

/**
 * A `SkeletonSprite` whose own on-screen bounding box is ignored, so the whole
 * character keeps rendering even when it is panned far off the default camera.
 *
 * Why this is needed:
 *   spine-haxe draws each attachment as an `FlxStrip` and computes its vertices
 *   in WORLD space. It does NOT apply the flixel camera's `zoom` to those
 *   vertices (only the mesh origin gets the camera transform). So when you
 *   pan/zoom the CAMERA, the per-mesh screen bounding box that flixel computes
 *   is wrong, which makes flixel wrongly cull individual attachments (parts of
 *   the character "disappear") and also scrambles where vertices land.
 *
 * The correct way to pan/zoom a Spine character is to move/scale the skeleton
 * itself (see `SpineViewerState`), keeping the camera at `zoom = 1`. At
 * `zoom = 1` flixel's per-mesh culling is correct, so we only need to make sure
 * the skeleton object itself is never culled as a whole.
 */
class NoCullSkeletonSprite extends SkeletonSprite
{
	public function new(skeletonData:SkeletonData, animationStateData:AnimationStateData = null)
	{
		super(skeletonData, animationStateData);
	}

	override public function isOnScreen(?camera:FlxCamera):Bool
	{
		return true;
	}
}
