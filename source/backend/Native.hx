package backend;

import lime.app.Application;
import lime.system.Display;
import lime.system.System;

import flixel.util.FlxColor;

#if (cpp && windows)
@:buildXml('
<target id="haxe">
	<lib name="dwmapi.lib" if="windows"/>
	<lib name="gdi32.lib" if="windows"/>
	<lib name="user32.lib" if="windows"/>
</target>
')
@:cppFileCode('
#include <windows.h>
#include <dwmapi.h>
#include <winuser.h>
#include <wingdi.h>
#include <map>
#include <vector>
#include <string>

#define attributeDarkMode 20
#define attributeDarkModeFallback 19

#define attributeCaptionColor 34
#define attributeTextColor 35
#define attributeBorderColor 36

struct HandleData {
	DWORD pid = 0;
	HWND handle = 0;
};

// 窗口数据结构
struct ExtraWindowData {
	int id;
	HWND handle;
	HDC hdc;
	int width;
	int height;
	int x;
	int y;
};

// 窗口存储
static std::map<int, ExtraWindowData> windowMap;
static int nextWindowId = 1;

BOOL CALLBACK findByPID(HWND handle, LPARAM lParam) {
	DWORD targetPID = ((HandleData*)lParam)->pid;
	DWORD curPID = 0;

	GetWindowThreadProcessId(handle, &curPID);
	if (targetPID != curPID || GetWindow(handle, GW_OWNER) != (HWND)0 || !IsWindowVisible(handle)) {
		return TRUE;
	}

	((HandleData*)lParam)->handle = handle;
	return FALSE;
}

HWND curHandle = 0;
WNDPROC originalWndProc = NULL;
bool isClosingRequested = false;
bool isCallbackInitialized = false;

LRESULT CALLBACK CustomWndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	// 只在初始化完成后才拦截关闭消息
	if (isCallbackInitialized && uMsg == WM_CLOSE) {
		isClosingRequested = true;
		return 0; // 阻止默认的关闭行为
	}
	return CallWindowProc(originalWndProc, hWnd, uMsg, wParam, lParam);
}

// 额外窗口的消息处理
LRESULT CALLBACK ExtraWindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	switch(uMsg) {
		case WM_CLOSE:
			DestroyWindow(hWnd);
			return 0;
		case WM_DESTROY: {
			// 从 windowMap 中移除已关闭的窗口
			for (auto it = windowMap.begin(); it != windowMap.end(); ++it) {
				if (it->second.handle == hWnd) {
					windowMap.erase(it);
					break;
				}
			}
			PostQuitMessage(0);
			return 0;
		}
		case WM_PAINT: {
			PAINTSTRUCT ps;
			HDC hdc = BeginPaint(hWnd, &ps);
			// 填充黑色背景
			RECT rect;
			GetClientRect(hWnd, &rect);
			HBRUSH blackBrush = CreateSolidBrush(RGB(0, 0, 0));
			FillRect(hdc, &rect, blackBrush);
			DeleteObject(blackBrush);
			// 绘制标题
			SetBkMode(hdc, TRANSPARENT);
			SetTextColor(hdc, RGB(255, 255, 255));
			DrawTextW(hdc, L"Extra Window", -1, &rect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
			EndPaint(hWnd, &ps);
			return 0;
		}
		default:
			return DefWindowProc(hWnd, uMsg, wParam, lParam);
	}
}

void getHandle() {
	if (curHandle == (HWND)0) {
		HandleData data;
		data.pid = GetCurrentProcessId();
		EnumWindows(findByPID, (LPARAM)&data);
		curHandle = data.handle;
	}
}

void initCloseCallback() {
	if (isCallbackInitialized) return;

	if (curHandle == (HWND)0) {
		getHandle();
	}

	if (curHandle != (HWND)0 && originalWndProc == NULL) {
		originalWndProc = (WNDPROC)SetWindowLongPtr(curHandle, GWLP_WNDPROC, (LONG_PTR)CustomWndProc);
		if (originalWndProc != NULL) {
			isCallbackInitialized = true;
		}
	}
}

bool cpp_isClosingRequested() {
	return isClosingRequested;
}

void cpp_resetClosingRequested() {
	isClosingRequested = false;
}

void setWindowAlpha(BYTE alpha) {
	if (curHandle != (HWND)0) {
		DWORD exStyle = GetWindowLong(curHandle, GWL_EXSTYLE);
		if (!(exStyle & WS_EX_LAYERED)) {
			SetWindowLong(curHandle, GWL_EXSTYLE, exStyle | WS_EX_LAYERED);
		}
		SetLayeredWindowAttributes(curHandle, 0, alpha, LWA_ALPHA);
	}
}

bool cpp_fadeOutWindow(int durationMs) {
	if (curHandle == (HWND)0) return false;

	DWORD exStyle = GetWindowLong(curHandle, GWL_EXSTYLE);
	if (!(exStyle & WS_EX_LAYERED)) {
		SetWindowLong(curHandle, GWL_EXSTYLE, exStyle | WS_EX_LAYERED);
	}

	int steps = 20;
	int stepDuration = durationMs / steps;

	for (int i = steps; i >= 0; i--) {
		BYTE alpha = (BYTE)(255 * i / steps);
		SetLayeredWindowAttributes(curHandle, 0, alpha, LWA_ALPHA);
		Sleep(stepDuration);
	}

	return true;
}

// 创建额外窗口
int cpp_createWindow(int width, int height) {
	if (curHandle == (HWND)0) {
		getHandle();
	}

	ExtraWindowData data;
	data.id = nextWindowId;
	data.width = width;
	data.height = height;

	// 获取屏幕工作区域（排除任务栏）
	RECT workArea;
	SystemParametersInfo(SPI_GETWORKAREA, 0, &workArea, 0);

	// 计算屏幕中心位置
	int screenWidth = workArea.right - workArea.left;
	int screenHeight = workArea.bottom - workArea.top;
	int centerX = workArea.left + screenWidth / 2;
	int centerY = workArea.top + screenHeight / 2;

	// 计算窗口相对于中心的偏移（第一个窗口在中心，后续向右下偏移）
	int offset = (nextWindowId - 1) * 20;
	data.x = centerX - width / 2 + offset;
	data.y = centerY - height / 2 + offset;

	// 确保窗口不超出屏幕边界
	if (data.x < workArea.left) data.x = workArea.left;
	if (data.y < workArea.top) data.y = workArea.top;
	if (data.x + width > workArea.right) data.x = workArea.right - width;
	if (data.y + height > workArea.bottom) data.y = workArea.bottom - height;

	// 创建窗口类
	WNDCLASSW wc = {0};
	wc.lpfnWndProc = ExtraWindowProc;
	wc.hInstance = GetModuleHandle(NULL);
	wc.hCursor = LoadCursor(NULL, IDC_ARROW);
	wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
	wc.lpszClassName = L"ExtraWindow";

	static bool classRegistered = false;
	if (!classRegistered) {
		RegisterClassW(&wc);
		classRegistered = true;
	}

	// 创建窗口
	wchar_t title[64];
	wcscpy_s(title, 64, L"Extra Window #");
	wchar_t numStr[16];
	_itow_s(nextWindowId, numStr, 16, 10);
	wcscat_s(title, 64, numStr);

	data.handle = CreateWindowExW(
		0,
		L"ExtraWindow",
		title,
		WS_OVERLAPPEDWINDOW,
		data.x, data.y,
		width, height,
		NULL, NULL, GetModuleHandle(NULL), NULL
	);

	if (data.handle != NULL) {
		ShowWindow(data.handle, SW_SHOW);
		UpdateWindow(data.handle);

		windowMap[nextWindowId] = data;
		return nextWindowId++;
	}

	return -1;
}

// 关闭窗口
bool cpp_closeWindow(int windowId) {
	auto it = windowMap.find(windowId);
	if (it != windowMap.end()) {
		HWND handle = it->second.handle;
		// 先从map中移除，再销毁窗口
		// 这样可以防止WM_DESTROY重复处理（如果窗口已不存在于map中，则不处理）
		windowMap.erase(it);
		DestroyWindow(handle);
		return true;
	}
	return false;
}

// 获取窗口数量
int cpp_getWindowCount() {
	return windowMap.size();
}

// 获取所有窗口ID
::String cpp_getAllWindows() {
	::String result = "[";
	bool first = true;
	for (auto& pair : windowMap) {
		// 只包含仍然有效的窗口
		if (IsWindow(pair.second.handle)) {
			if (!first) {
				result += ",";
			}
			result += std::to_string(pair.first).c_str();
			first = false;
		}
	}
	result += "]";
	return result;
}

// 检查窗口是否存在
bool cpp_isWindowActive(int windowId) {
	auto it = windowMap.find(windowId);
	if (it != windowMap.end()) {
		// 同时检查map存在性和句柄有效性
		return IsWindow(it->second.handle);
	}
	return false;
}

// 获取窗口位置信息（分别返回x, y, width, height）
int cpp_getWindowX(int windowId) {
	auto it = windowMap.find(windowId);
	if (it != windowMap.end() && IsWindow(it->second.handle)) {
		RECT rect;
		GetWindowRect(it->second.handle, &rect);
		return rect.left;
	}
	return 0;
}

int cpp_getWindowY(int windowId) {
	auto it = windowMap.find(windowId);
	if (it != windowMap.end() && IsWindow(it->second.handle)) {
		RECT rect;
		GetWindowRect(it->second.handle, &rect);
		return rect.top;
	}
	return 0;
}

int cpp_getWindowWidth(int windowId) {
	auto it = windowMap.find(windowId);
	if (it != windowMap.end() && IsWindow(it->second.handle)) {
		RECT rect;
		GetWindowRect(it->second.handle, &rect);
		return rect.right - rect.left;
	}
	return 0;
}

int cpp_getWindowHeight(int windowId) {
	auto it = windowMap.find(windowId);
	if (it != windowMap.end() && IsWindow(it->second.handle)) {
		RECT rect;
		GetWindowRect(it->second.handle, &rect);
		return rect.bottom - rect.top;
	}
	return 0;
}
')
#end
class Native
{
	public static function __init__():Void
	{
		registerDPIAware();
	}

	public static function registerDPIAware():Void
	{
		#if (cpp && windows)
		// DPI Scaling fix for windows 
		// this shouldn't be needed for other systems
		// Credit to YoshiCrafter29 for finding this function
		untyped __cpp__('
			SetProcessDPIAware();	
			#ifdef DPI_AWARENESS_CONTEXT
			SetProcessDpiAwarenessContext(
				#ifdef DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
				DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
				#else
				DPI_AWARENESS_CONTEXT_SYSTEM_AWARE
				#endif
			);
			#endif
		');
		#end
	}

	private static var fixedScaling:Bool = false;
	private static var originalWidth:Int = 0;
	private static var originalHeight:Int = 0;

	public static function fixScaling():Void
	{
		if (fixedScaling) return;
		fixedScaling = true;

		#if (cpp && windows)
		final display:Null<Display> = System.getDisplay(0);
		if (display != null)
		{
			final dpiScale:Float = display.dpi / 96;
			originalWidth = Std.int(Main.game.width * dpiScale);
			originalHeight = Std.int(Main.game.height * dpiScale);
			@:privateAccess Application.current.window.width = originalWidth;
			@:privateAccess Application.current.window.height = originalHeight;

			Application.current.window.x = Std.int((Application.current.window.display.bounds.width - Application.current.window.width) / 2);
			Application.current.window.y = Std.int((Application.current.window.display.bounds.height - Application.current.window.height) / 2);
		}

		untyped __cpp__('
			getHandle();
			if (curHandle != (HWND)0) {
				HDC curHDC = GetDC(curHandle);
				RECT curRect;
				GetClientRect(curHandle, &curRect);
				FillRect(curHDC, &curRect, (HBRUSH)GetStockObject(BLACK_BRUSH));
				ReleaseDC(curHandle, curHDC);
			}
		');
		#end
	}

	/**
	 * 修复全屏时的分辨率问题
	 * 在全屏模式下使用显示器原生分辨率，而不是游戏逻辑分辨率
	 */
	public static function fixFullscreenResolution():Void
	{
		#if (cpp && windows)
		final display:Null<Display> = System.getDisplay(0);
		if (display != null && Application.current.window != null)
		{
			if (FlxG.fullscreen)
			{
				// 全屏模式：使用显示器原生分辨率
				@:privateAccess Application.current.window.width = Std.int(display.bounds.width);
				@:privateAccess Application.current.window.height = Std.int(display.bounds.height);
			}
			else
			{
				// 窗口模式：恢复原来的尺寸
				if (originalWidth > 0 && originalHeight > 0)
				{
					@:privateAccess Application.current.window.width = originalWidth;
					@:privateAccess Application.current.window.height = originalHeight;
				}
				else
				{
					final dpiScale:Float = display.dpi / 96;
					@:privateAccess Application.current.window.width = Std.int(Main.game.width * dpiScale);
					@:privateAccess Application.current.window.height = Std.int(Main.game.height * dpiScale);
				}

				// 居中窗口
				Application.current.window.x = Std.int((display.bounds.width - Application.current.window.width) / 2);
				Application.current.window.y = Std.int((display.bounds.height - Application.current.window.height) / 2);
			}
		}
		#end
	}

	/**
	 * 设置窗口透明度（仅Windows平台）
	 * @param alpha 透明度值 (0-255，0=完全透明，255=完全不透明)
	 */
	public static function setWindowAlpha(alpha:Int):Void
	{
		#if (cpp && windows)
		untyped __cpp__('
			setWindowAlpha({0});
		', alpha);
		#end
	}

	/**
	 * 渐隐关闭窗口（仅Windows平台）
	 * @param durationMs 渐隐持续时间（毫秒），默认500ms
	 * @return 是否成功启动渐隐动画
	 */
	public static function fadeOutWindow(?durationMs:Int = 500):Bool
	{
		#if (cpp && windows)
		var result:Bool = false;
		untyped __cpp__('
			result = cpp_fadeOutWindow({0});
		', durationMs);
		return result;
		#else
		return false;
		#end
	}

	/**
	 * 设置窗口关闭回调（仅Windows平台）
	 * 拦截 WM_CLOSE 消息，阻止默认关闭行为
	 */
	public static function setCloseCallback():Void
	{
		#if (cpp && windows)
		untyped __cpp__('
			initCloseCallback();
		');
		#end
	}

	/**
	 * 检查是否有关闭请求（仅Windows平台）
	 * @return 是否有未处理的关闭请求
	 */
	public static function isClosingRequested():Bool
	{
		#if (cpp && windows)
		var result:Bool = false;
		untyped __cpp__('
			result = cpp_isClosingRequested();
		');
		return result;
		#else
		return false;
		#end
	}

	/**
	 * 重置关闭请求标志（仅Windows平台）
	 */
	public static function resetClosingRequested():Void
	{
		#if (cpp && windows)
		untyped __cpp__('
			cpp_resetClosingRequested();
		');
		#end
	}

	#if (cpp && windows)
	/**
	 * 创建额外窗口（仅Windows平台）
	 * @param width 窗口宽度
	 * @param height 窗口高度
	 * @return 窗口ID，失败返回-1
	 */
	public static function createWindow(width:Int, height:Int):Int
	{
		var result:Int = -1;
		untyped __cpp__('result = cpp_createWindow({0}, {1})', width, height);
		return result;
	}

	/**
	 * 关闭窗口（仅Windows平台）
	 * @param windowId 窗口ID
	 * @return 是否成功
	 */
	public static function closeWindow(windowId:Int):Bool
	{
		var result:Bool = false;
		untyped __cpp__('result = cpp_closeWindow({0})', windowId);
		return result;
	}

	/**
	 * 获取窗口数量（仅Windows平台）
	 * @return 当前窗口数量
	 */
	public static function getWindowCount():Int
	{
		var count:Int = 0;
		untyped __cpp__('count = cpp_getWindowCount()');
		return count;
	}

	/**
	 * 获取所有窗口ID（仅Windows平台）
	 * @return 窗口ID数组
	 */
	public static function getAllWindowIds():Array<Int>
	{
		var jsonStr:String = untyped __cpp__('cpp_getAllWindows()');
		try {
			var arr:Array<Dynamic> = haxe.Json.parse(jsonStr);
			var result:Array<Int> = [];
			for (item in arr) {
				result.push(Std.int(item));
			}
			return result;
		} catch (e:Dynamic) {
			return [];
		}
	}

	/**
	 * 检查窗口是否存在（仅Windows平台）
	 * @param windowId 窗口ID
	 * @return 是否存在
	 */
	public static function isWindowActive(windowId:Int):Bool
	{
		var result:Bool = false;
		untyped __cpp__('result = cpp_isWindowActive({0})', windowId);
		return result;
	}

	/**
	 * 获取窗口位置信息（仅Windows平台）
	 * @param windowId 窗口ID
	 * @return 位置信息 {x, y, width, height}
	 */
	public static function getWindowPosition(windowId:Int):Dynamic
	{
		#if (cpp && windows)
		var x:Int = 0;
		var y:Int = 0;
		var width:Int = 0;
		var height:Int = 0;

		untyped __cpp__('x = cpp_getWindowX({0})', windowId);
		untyped __cpp__('y = cpp_getWindowY({0})', windowId);
		untyped __cpp__('width = cpp_getWindowWidth({0})', windowId);
		untyped __cpp__('height = cpp_getWindowHeight({0})', windowId);

		return {x: x, y: y, width: width, height: height};
		#else
		return {x: 0, y: 0, width: 0, height: 0};
		#end
	}
	#end
}