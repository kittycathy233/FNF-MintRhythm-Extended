package states;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.zip.Reader;
import haxe.io.BytesInput;
import sys.io.File as SysFile;
import sys.FileSystem;
import backend.Paths;
import states.MainMenuState;
import haxe.ds.List;
import haxe.zip.Entry;
import backend.ui.PsychUIButton;
import haxe.io.Path;

class ModsImport extends MusicBeatState
{
	private var zipPath:String;
	private var zipName:String;
	private var confirmImport:Bool = false;
	private var hasJson:Bool = false;

	private var titleText:FlxText;
	private var zipNameText:FlxText;
	private var progressText:FlxText;
	private var confirmButton:PsychUIButton;
	private var cancelButton:PsychUIButton;
	private var importDoneText:FlxText;
	private var tipText:FlxText;
	
	// 用于存储解压过程中的状态
	private var adaptiveTargetDirectory:String = "";
	private var foundRootDir:String = "";

	public function new(zipPath:String, zipName:String)
	{
		super();
		this.zipPath = zipPath;
		// 确保只使用文件名，移除路径
		this.zipName = Path.withoutDirectory(zipName);
	}

	override function create()
	{
		super.create();

		titleText = new FlxText(0, 20, FlxG.width, Language.get("modsimport_detected"), 32);
		titleText.setFormat(Paths.font(Language.get('game_font')), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.screenCenter(X);
		add(titleText);

		zipNameText = new FlxText(0, 80, FlxG.width, Language.get("modsimport_zipname") + zipName, 24);
		zipNameText.setFormat(Paths.font(Language.get('game_font')), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		zipNameText.screenCenter(X);
		add(zipNameText);

		progressText = new FlxText(0, 120, FlxG.width, Language.get("modsimport_progress"), 24);
		progressText.setFormat(Paths.font(Language.get('game_font')), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		progressText.screenCenter(X);
		progressText.visible = false;
		add(progressText);

		confirmButton = new PsychUIButton(FlxG.width / 4, 400, "Confirm", startImport);
		confirmButton.screenCenter(Y);
		add(confirmButton);

		cancelButton = new PsychUIButton(FlxG.width * 3 / 4, 400, "Cancel", function() {
			FlxG.switchState(new MainMenuState());
		});
		cancelButton.screenCenter(Y);
		add(cancelButton);

		importDoneText = new FlxText(0, 200, FlxG.width, Language.get("modsimport_done"), 32);
		importDoneText.setFormat(Paths.font(Language.get('game_font')), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		importDoneText.screenCenter();
		importDoneText.visible = false;
		add(importDoneText);

		var tipsContent = CoolUtil.tipsShow();
		if(tipsContent != null && tipsContent.length > 0) {
			var tipsArray = tipsContent.split('\n');
			var randomTip = StringTools.replace(
				tipsArray[FlxG.random.int(0, tipsArray.length - 1)].trim(),
				"\\n",
				"\n"
			);
			
			tipText = new FlxText(30, 30, FlxG.width - 60, randomTip);
			tipText.scrollFactor.set();
			tipText.setFormat(
				Paths.font(Language.get('game_font')), 
				22, 
				FlxColor.WHITE, 
				RIGHT, 
				FlxTextBorderStyle.OUTLINE, 
				FlxColor.BLACK
			);
			tipText.height = tipText.textField.textHeight + 8;
			add(tipText);
		}

		checkZipContent();
	}

	private function checkZipContent():Void
	{
		try
		{
			var bytes = SysFile.getBytes(zipPath);
			var reader = new Reader(new BytesInput(bytes));
			var entries = reader.read();

			var hasWeeks = false;
			var hasJson = false;

			for (entry in entries)
			{
				var fileName = entry.fileName;
				trace('File Name: ' + fileName);

				if (fileName.contains("weeks/"))
				{
					hasWeeks = true;
					if (fileName.endsWith(".json"))
					{
						hasJson = true;
					}
				}
			}

			if (!hasWeeks)
			{
				confirmButton.visible = false;
				titleText.text = "No weeks/ directory found in ZIP file.";
				titleText.color = FlxColor.fromString("#FFA500");
			}
			else if (!hasJson)
			{
				confirmButton.visible = false;
				titleText.text = "No JSON files found in weeks/ directory.";
				titleText.color = FlxColor.fromString("#FFA500");
			}
			else
			{
				confirmButton.visible = true;
				titleText.text = Language.get("modsimport_detected");
				titleText.color = FlxColor.WHITE;
			}
		}
		catch (e)
		{
			trace('Zip解析失败: $e');
			titleText.text = "Error reading ZIP file.";
			titleText.color = FlxColor.RED;
			confirmButton.visible = false;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.BACK)
		{
			FlxG.switchState(new MainMenuState());
		}
	}

	private function startImport():Void
	{
		confirmButton.visible = false;
		cancelButton.visible = false;
		titleText.visible = false;
		zipNameText.visible = false;
		progressText.visible = true;

		new FlxTimer().start(0.1, function(tmr:FlxTimer)
		{
			try
			{
				var bytes = SysFile.getBytes(zipPath);
				var bytesInput = new BytesInput(bytes);
				var reader = new Reader(bytesInput);
				var entries:List<Entry> = reader.read();

				// 确定安全的目标目录名
				var safeZipName = Path.withoutExtension(zipName);
				adaptiveTargetDirectory = "mods/" + safeZipName;
				
				// 递归创建目录
				function createDir(path:String) {
					path = Path.normalize(path);
					var parts = path.split("/");
					var current = "";
					for (part in parts) {
						current = current == "" ? part : current + "/" + part;
						if (!FileSystem.exists(current)) {
							FileSystem.createDirectory(current);
						}
					}
				}
				
				createDir(adaptiveTargetDirectory);
				
				// 第一步：解压到临时目录
				var tempDir = adaptiveTargetDirectory + "/_temp";
				createDir(tempDir);
				
				for (entry in entries) {
					var entryName = entry.fileName;
					// 跳过不安全文件
					if (entryName.contains("..")) {
						trace('跳过不安全文件: $entryName');
						continue;
					}
					
					var targetPath = tempDir + "/" + entryName;
					
					if (entryName.endsWith("/")) {
						if (!FileSystem.exists(targetPath)) {
							createDir(targetPath);
						}
					} else {
						var dir = Path.directory(targetPath);
						if (!FileSystem.exists(dir)) {
							createDir(dir);
						}
						
						var entryBytes = haxe.zip.Reader.unzip(entry);
						var outputFile = try SysFile.write(targetPath, false) catch (e:Dynamic) {
							trace('写入文件失败: $targetPath - $e');
							null;
						}
						if (outputFile != null) {
							outputFile.writeBytes(entryBytes, 0, entryBytes.length);
							outputFile.close();
						}
					}
				}
				
				// 第二步：查找实际的内容根目录
				foundRootDir = findActualRootDirectory(tempDir);
				
				if (foundRootDir == null || foundRootDir == "") {
					throw "在ZIP文件中找不到有效的内容根目录";
				}
				
				// 第三步：将内容移动到正确位置
				moveContentsToTarget(foundRootDir, adaptiveTargetDirectory);
				
				// 第四步：清理临时文件
				cleanupTempFiles(tempDir);
				
				progressText.text = Language.get("modsimport_success");
				importDoneText.visible = true;

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					FlxG.switchState(new MainMenuState());
				});
			}
			catch (e)
			{
				trace('导入失败: $e');
				progressText.text = "Import failed: " + e;
				progressText.color = FlxColor.RED;
			}
		});
	}
	
	/**
	 * 递归查找实际的内容根目录
	 * 优先选择包含 weeks/ 目录的层级
	 */
	private function findActualRootDirectory(startPath:String):String
	{
		// 检查当前目录是否直接包含weeks目录
		if (FileSystem.exists('$startPath/weeks') && FileSystem.isDirectory('$startPath/weeks')) {
			return startPath;
		}
		
		// 检查当前目录是否包含多个有效的mod目录
		var files = FileSystem.readDirectory(startPath);
		var candidateDirs = [];
		
		for (file in files) {
			var path = '$startPath/$file';
			if (FileSystem.isDirectory(path)) {
				if (FileSystem.exists('$path/weeks') && FileSystem.isDirectory('$path/weeks')) {
					candidateDirs.push(path);
				}
			}
		}
		
		// 如果找到多个包含weeks目录的子目录，优先选择包含mod信息的
		if (candidateDirs.length > 0) {
			// 尝试查找包含 pack.json 或 mod.json 的目录
			for (dir in candidateDirs) {
				if (FileSystem.exists('$dir/pack.json') || FileSystem.exists('$dir/mod.json')) {
					return dir;
				}
			}
			// 没有找到元文件，返回第一个候选目录
			return candidateDirs[0];
		}
		
		// 如果当前目录只有一个子目录，且该子目录包含weeks，则返回它
		if (files.length == 1) {
			var singlePath = '$startPath/${files[0]}';
			if (FileSystem.isDirectory(singlePath)) {
				// 递归检查子目录
				return findActualRootDirectory(singlePath);
			}
		}
		
		// 没有找到，返回空
		return null;
	}
	
	/**
	 * 将内容从源目录移动到目标目录
	 */
	private function moveContentsToTarget(source:String, target:String):Void
	{
		var files = FileSystem.readDirectory(source);
		for (file in files) {
			var sourcePath = '$source/$file';
			var targetPath = '$target/$file';
			
			// 跳过临时文件
			if (file == "_temp") continue;
			
			if (FileSystem.isDirectory(sourcePath)) {
				// 创建目标目录
				if (!FileSystem.exists(targetPath)) {
					FileSystem.createDirectory(targetPath);
				}
				// 递归移动子目录内容
				moveContentsToTarget(sourcePath, targetPath);
				// 删除空目录
				try {
					FileSystem.deleteDirectory(sourcePath);
				} catch(e:Dynamic) {
					trace('无法删除目录 $sourcePath: $e');
				}
			} else {
				// 移动文件
				try {
					FileSystem.rename(sourcePath, targetPath);
				} catch(e:Dynamic) {
					// 如果重命名失败（跨设备），则复制文件
					trace('重命名失败，尝试复制文件: $sourcePath -> $targetPath');
					copyFile(sourcePath, targetPath);
					try {
						FileSystem.deleteFile(sourcePath);
					} catch(e:Dynamic) {
						trace('无法删除源文件 $sourcePath: $e');
					}
				}
			}
		}
	}
	
	/**
	 * 复制文件（用于跨设备移动）
	 */
	private function copyFile(source:String, target:String):Void
	{
		try {
			var bytes = SysFile.getBytes(source);
			var output = SysFile.write(target, false);
			output.writeBytes(bytes, 0, bytes.length);
			output.close();
		} catch(e:Dynamic) {
			throw '无法复制文件 $source 到 $target: $e';
		}
	}
	
	/**
	 * 清理临时文件
	 */
	private function cleanupTempFiles(tempDir:String):Void
	{
		try {
			if (FileSystem.exists(tempDir)) {
				deleteDirectoryRecursive(tempDir);
			}
		} catch (e:Dynamic) {
			trace('清理临时文件失败: $e');
		}
	}
	
	/**
	 * 递归删除目录
	 */
	private function deleteDirectoryRecursive(path:String):Void
	{
		if (FileSystem.exists(path)) {
			var files = FileSystem.readDirectory(path);
			for (file in files) {
				var curPath = '$path/$file';
				if (FileSystem.isDirectory(curPath)) {
					deleteDirectoryRecursive(curPath);
				} else {
					try {
						FileSystem.deleteFile(curPath);
					} catch(e:Dynamic) {
						trace('无法删除文件 $curPath: $e');
					}
				}
			}
			try {
				FileSystem.deleteDirectory(path);
			} catch(e:Dynamic) {
				trace('无法删除目录 $path: $e');
			}
		}
	}

	override function destroy()
	{
		super.destroy();
		if (titleText != null) titleText.destroy();
		if (zipNameText != null) zipNameText.destroy();
		if (progressText != null) progressText.destroy();
		if (confirmButton != null) confirmButton.destroy();
		if (cancelButton != null) cancelButton.destroy();
		if (importDoneText != null) importDoneText.destroy();
	}
}