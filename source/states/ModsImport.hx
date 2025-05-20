package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxState;
import haxe.zip.Reader;
import haxe.io.BytesInput;
import sys.io.File as SysFile;
import sys.FileSystem;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import StringTools;
import backend.ui.PsychUIButton;
import backend.Paths;
import backend.Language;
import flixel.util.FlxTimer;

class ModsImport extends MusicBeatState {
	var zipPath:String;
	var basePath:String;
	var progressBar:FlxSprite;
	var progressText:FlxText;
	var doneText:FlxText;
	var importBtn:PsychUIButton;
	var cancelBtn:PsychUIButton;
	var importing:Bool = false;
	var zipName:String;

	public function new(zipPath:String, basePath:String) {
		super();
		this.zipPath = zipPath;
		this.basePath = basePath;
	}

	override function create() {
		super.create();

		zipName = zipPath;
		zipName = StringTools.replace(zipName, "\\", "/");
		zipName = zipName.split("/").pop();

		var font = Paths.font("ResourceHanRoundedCN-Bold.ttf");

		var info = new FlxText(0, 80, FlxG.width, Language.get("modsimport_detected"), 28);
		info.setFormat(font, 28, FlxColor.WHITE, "center");
		add(info);

		var zipText = new FlxText(0, 120, FlxG.width, Language.get("modsimport_zipname") + zipName, 20);
		zipText.setFormat(font, 20, FlxColor.YELLOW, "center");
		add(zipText);

		importBtn = new PsychUIButton(FlxG.width/2 - 170, 200, Language.get("ok_text"), doImport, 140, 50);
		importBtn.text.setFormat(font, 22, FlxColor.WHITE, "center");
		add(importBtn);

		cancelBtn = new PsychUIButton(FlxG.width/2 + 30, 200, Language.get("cancel_text"), function() MusicBeatState.switchState(new MainMenuState()), 140, 50);
		cancelBtn.text.setFormat(font, 22, FlxColor.WHITE, "center");
		add(cancelBtn);

		progressBar = new FlxSprite(FlxG.width/2 - 150, 300).makeGraphic(300, 20, FlxColor.GRAY);
		progressBar.visible = false;
		add(progressBar);

		progressText = new FlxText(FlxG.width/2 - 150, 330, 300, "", 18);
		progressText.setFormat(font, 18, FlxColor.WHITE, "center");
		progressText.visible = false;
		add(progressText);

		doneText = new FlxText(0, 370, FlxG.width, "", 22);
		doneText.setFormat(font, 22, FlxColor.LIME, "center");
		add(doneText);
	}

	function doImport() {
		if (importing) return;
		importing = true;
		importBtn.visible = false;
		cancelBtn.visible = false;
		progressBar.visible = true;
		progressText.visible = true;
		doneText.text = "";

		var bytes = SysFile.getBytes(zipPath);
		var reader = new Reader(new BytesInput(bytes));
		var entries = reader.read();

		zipName = zipPath;
		zipName = StringTools.replace(zipName, "\\", "/");
		zipName = zipName.split("/").pop();
		if (zipName.endsWith('.zip')) zipName = zipName.substr(0, zipName.length - 4);
		var modsDir = 'mods/$zipName';
		if (!FileSystem.exists('mods')) FileSystem.createDirectory('mods');
		if (!FileSystem.exists(modsDir)) FileSystem.createDirectory(modsDir);

		// 自动检测最浅层的 weeks/data/songs 的上级目录
		var minBase:String = null;
		for (entry in entries) {
			var path = entry.fileName;
			var parts = path.split('/');
			for (i in 0...parts.length) {
				if (parts[i] == 'weeks' || parts[i] == 'data' || parts[i] == 'songs') {
					var candidate = parts.slice(0, i).join('/');
					if (minBase == null || candidate.length < minBase.length) minBase = candidate;
				}
			}
		}
		var base = (minBase != null && minBase != '') ? minBase + '/' : '';

		// 统计要导入的文件数量
		var total = 0;
		for (entry in entries) {
			if (base == '' || entry.fileName.indexOf(base) == 0) {
				total++;
			}
		}
		var done = 0;
		for (entry in entries) {
			if (base == '' || entry.fileName.indexOf(base) == 0) {
				var relPath = entry.fileName.substr(base.length);
				if (relPath == "") continue; // 跳过根目录
				var outPath = modsDir + '/' + relPath;
				if (entry.fileName.endsWith('/')) {
					if (!FileSystem.exists(outPath)) FileSystem.createDirectory(outPath);
				} else {
					var dir = outPath.split('/').slice(0, -1).join('/');
					if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
					SysFile.saveBytes(outPath, entry.data);
				}
				done++;
				progressBar.makeGraphic(Std.int(300 * done / total), 20, FlxColor.LIME);
				progressText.text = Language.get("modsimport_progress") + ' $done / $total';
			}
		}
		progressBar.makeGraphic(300, 20, FlxColor.LIME);
		progressText.text = Language.get("modsimport_done") + ' $done / $total';
		doneText.text = Language.get("modsimport_success");

		// 1秒后自动返回主菜单
		new FlxTimer().start(1, function(_) {
			MusicBeatState.switchState(new MainMenuState());
		});
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
	}
}

