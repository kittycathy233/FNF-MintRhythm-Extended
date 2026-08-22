package backend;

import flixel.sound.FlxSound;
import flash.media.Sound;

/**
 * 打击音 FlxSound 对象池。
 * 复用固定数量的 FlxSound 实例播放短音效（hitsound / missnote 等），
 * 避免高密度谱每击 new FlxSound + 新建 OpenAL source 带来的分配与 GC 卡顿。
 * 池内实例全部加入 FlxG.sound.list，随 Flixel 统一管理（失焦暂停、静音、音量）。
 */
class HitSoundPool
{
	var pool:Array<FlxSound>;
	var size:Int;
	var cursor:Int = 0; // 环形复用指针，避免每次从头扫描找空闲

	public function new(size:Int = 50)
	{
		if (size < 1) size = 1;
		this.size = size;
		pool = [];
		for (i in 0...size)
		{
			var snd:FlxSound = new FlxSound();
			snd.persist = true;        // 防止 Flixel 状态切换时被 destroySounds 误清
			snd.autoDestroy = false;   // 播完不销毁，留待复用
			pool.push(snd);
			FlxG.sound.list.add(snd);
		}
	}

	/**
	 * 播放一个短音效。
	 * 先环形找一个空闲实例；若全部在响（极端高密度），则覆盖当前指针指向的（最早开始播的）实例，不丢音。
	 * @param sound  已解码好的 Sound（如 Paths.sound(...) 的返回值）
	 * @param volume 音量 0~1
	 * @param pitch  播放音高（可选，FLX_PITCH 下生效）
	 */
	public function play(sound:Sound, volume:Float = 1.0, ?pitch:Float):FlxSound
	{
		if (sound == null) return null;

		for (i in 0...size)
		{
			var snd:FlxSound = pool[cursor];
			cursor = (cursor + 1) % size;
			if (!snd.playing)
				return playOn(snd, sound, volume, pitch);
		}
		// 全部忙：覆盖当前指针（循环一圈回到原地 = 最久未用的实例）
		return playOn(pool[cursor], sound, volume, pitch);
	}

	function playOn(snd:FlxSound, sound:Sound, volume:Float, ?pitch:Float):FlxSound
	{
		snd.stop();
		snd.loadEmbedded(sound);
		snd.volume = volume;
		#if FLX_PITCH
		if (pitch != null) snd.pitch = pitch;
		#end
		snd.play();
		return snd;
	}

	public function destroy():Void
	{
		for (snd in pool)
		{
			snd.stop();
			snd.destroy(); // destroy 会自动从 FlxG.sound.list 移除
		}
		pool = null;
	}
}
