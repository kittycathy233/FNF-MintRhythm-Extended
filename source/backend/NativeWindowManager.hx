package backend;

#if (cpp && windows)
import backend.Native;

/**
 * 窗口数据类型定义
 */
typedef WindowData = {
	var id:Int;
	var width:Int;
	var height:Int;
	var handle:Dynamic;
}

/**
 * NativeWindowManager - 原生窗口管理器
 * 管理所有额外窗口的生命周期，与底层Native API交互
 */
class NativeWindowManager
{
	/**
	 * 创建新窗口
	 * @param width 窗口宽度（默认800）
	 * @param height 窗口高度（默认600）
	 * @return 窗口ID，失败返回-1
	 */
	public static function createWindow(width:Int = 800, height:Int = 600):Int
	{
		#if (cpp && windows)
		return Native.createWindow(width, height);
		#else
		return -1;
		#end
	}

	/**
	 * 关闭指定窗口
	 * @param windowId 窗口ID
	 * @return 是否成功关闭
	 */
	public static function closeWindow(windowId:Int):Bool
	{
		#if (cpp && windows)
		return Native.closeWindow(windowId);
		#else
		return false;
		#end
	}

	/**
	 * 获取所有活动窗口ID
	 * @return 窗口ID数组
	 */
	public static function getAllWindowIds():Array<Int>
	{
		#if (cpp && windows)
		return Native.getAllWindowIds();
		#else
		return [];
		#end
	}

	/**
	 * 获取窗口数量
	 * @return 当前窗口数量
	 */
	public static function getWindowCount():Int
	{
		#if (cpp && windows)
		return Native.getWindowCount();
		#else
		return 0;
		#end
	}

	/**
	 * 检查窗口是否仍然活动
	 * @param windowId 窗口ID
	 * @return 是否活动
	 */
	public static function isWindowActive(windowId:Int):Bool
	{
		#if (cpp && windows)
		return Native.isWindowActive(windowId);
		#else
		return false;
		#end
	}

	/**
	 * 获取窗口位置和尺寸信息
	 * @param windowId 窗口ID
	 * @return 位置信息对象 {x, y, width, height}
	 */
	public static function getWindowPosition(windowId:Int):WindowPosition
	{
		#if (cpp && windows)
		var pos:Dynamic = Native.getWindowPosition(windowId);
		return {
			x: pos.x,
			y: pos.y,
			width: pos.width,
			height: pos.height
		};
		#else
		return {x: 0, y: 0, width: 0, height: 0};
		#end
	}

	/**
	 * 关闭所有窗口
	 * @return 成功关闭的窗口数量
	 */
	public static function closeAllWindows():Int
	{
		var closedCount = 0;
		// 使用循环确保所有窗口都被关闭
		while (true)
		{
			var windows = getAllWindowIds();
			if (windows.length == 0)
			{
				break;
			}
			// 每次只关闭第一个窗口，然后重新获取列表
			if (closeWindow(windows[0]))
			{
				closedCount++;
			}
		}
		return closedCount;
	}

	/**
	 * 获取窗口统计信息
	 * @return 统计信息字符串
	 */
	public static function getStats():String
	{
		var count = getWindowCount();
		var windows = getAllWindowIds();

		if (count == 0)
		{
			return "当前无活动窗口";
		}

		var info = "窗口统计: $count 个\n";
		for (id in windows)
		{
			var pos = getWindowPosition(id);
			info += '  窗口 #$id (${pos.width}x${pos.height})\n';
		}
		return info;
	}
}

/**
 * 窗口位置信息类型
 */
typedef WindowPosition = {
	var x:Int;
	var y:Int;
	var width:Int;
	var height:Int;
}
#end
