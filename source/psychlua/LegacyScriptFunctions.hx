package psychlua;

//
// Legacy script-function compatibility layer for mods written against older
// Psych Engine versions (0.6.3 / 0.7.3).
//
// These global functions existed in old versions but were removed or renamed
// when the engine moved to the 1.0-based architecture. They are registered
// here (additive, zero-risk) so old mods keep working without edits.
//
// Out of scope (need a dedicated bridge, see research notes):
//   - runHaxeCode / addHaxeLibrary on the LUA side (only exist on HScript now)
//   - doTweenZoom semantic change (2nd arg is now a camera, not an object)
//

class LegacyScriptFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;
		var game:PlayState = PlayState.instance;

		// 0.6.3 used `changePresence`, current renamed it to `changeDiscordPresence`.
		// Both delegate to DiscordClient.changePresence with the same scatter params,
		// so the old name is just an alias.
		#if DISCORD_ALLOWED
		Lua_helper.add_callback(lua, "changePresence", function(details:String, ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) {
			DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
		});
		#end

		// 0.6.3 / 0.7.3 cross-script global read/write, removed in current.
		// Re-implemented by locating the target script in the running lua array.
		Lua_helper.add_callback(lua, "getGlobalFromScript", function(luaFile:String, global:String):Dynamic {
			if(game == null) return null;
			for (inst in game.luaArray) {
				if(inst.scriptName == luaFile || inst.scriptName.endsWith(luaFile)) {
					if(inst.lua == null) return null;
					Lua.getglobal(inst.lua, global);
					var result:Dynamic = Convert.fromLua(inst.lua, -1);
					Lua.pop(inst.lua, 1);
					return result;
				}
			}
			return null;
		});

		Lua_helper.add_callback(lua, "setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic) {
			if(game == null) return;
			for (inst in game.luaArray) {
				if(inst.scriptName == luaFile || inst.scriptName.endsWith(luaFile)) {
					inst.set(global, val);
				}
			}
		});
	}
}
