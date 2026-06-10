-- ============================================
-- Spine骨骼动画 Lua脚本使用示例
-- ============================================
-- 文件路径: 相对于模组的 images/ 目录
-- 例如传入 'spines/CH0334_spr.skel' -> 系统查找:
--   mods/你的模组名/images/spines/CH0334_spr.skel
--   mods/你的模组名/images/spines/CH0334_spr.atlas
--   mods/你的模组名/images/spines/CH0334_spr.png
-- ============================================

local characters = {}

function onCreatePost()
    -- 创建Spine骨骼
    -- 参数: (标签, .skel/.json路径, .atlas路径, x, y)
    -- 路径相对于 images/ 目录
    local success = makeSpineSprite('aris1',
        'spines/CH0334_spr.skel',
        'spines/CH0334_spr.atlas',
        0, 0)

    if success then
        addSpineSprite('aris1')

        -- ============================================
        -- 显示 & 位置控制
        -- ============================================

        -- 设置缩放
        spineSetScale('aris1', 0.6, 0.6)

        -- 屏幕居中 (参数: 'x' 只水平, 'y' 只垂直, 'xy' 双向)
        spineScreenCenter('aris1', 'x')

        -- 或者手动设置位置
        -- spineSetPosition('aris1', 400, 300)

        -- ============================================
        -- 防止裁剪 / 完整显示
        -- ============================================

        -- 方法1: 自动计算所有动画的完整边界
        -- 遍历所有动画计算最大范围，确保不会被裁剪
        spineComputeFullBounds('aris1')

        -- 方法2: 用某个特定动画计算边界
        -- spineSetBoundingBox('aris1', 'idle', false)  -- false = 不裁剪

        -- 方法3: 手动设置宽高和偏移
        -- spineSetSize('aris1', 1000, 1000)
        -- spineSetOriginOffset('aris1', 500, 500)

        -- ============================================
        -- 相机图层 / 滚动控制
        -- ============================================

        -- 设置相机图层: 'game' (跟随镜头), 'hud' (固定在屏幕)
        spineSetObjectCamera('aris1', 'game')

        -- 设置滚动因子 (1,1 = 跟随相机, 0,0 = 固定在屏幕)
        spineSetScrollFactor('aris1', 1, 1)

        -- ============================================
        -- 动画控制
        -- ============================================

        -- 播放动画 (参数: 标签, 轨道号, 动画名, 是否循环)
        spineSetAnimation('aris1', 0, 'idle', true)

        -- 调试: 获取并打印可用动画列表
        local anims = spineGetAnimations('aris1')
        debugPrint('Available animations:')
        for i, anim in ipairs(anims) do
            debugPrint('  - ' .. anim)
        end

        -- 调试: 查看当前信息
        local info = spineGetInfo('aris1')
        if info ~= nil then
            debugPrint('Size: ' .. info.width .. 'x' .. info.height)
            debugPrint('Pos: (' .. info.x .. ', ' .. info.y .. ')')
            debugPrint('Scale: (' .. info.scaleX .. ', ' .. info.scaleY .. ')')
            debugPrint('Offset: (' .. info.offsetX .. ', ' .. info.offsetY .. ')')
        end

        table.insert(characters, 'aris1')
    else
        debugPrint('aris1 creation FAILED', 'RED')
    end
end

local time = 0
function onUpdate(elapsed)
    time = time + elapsed

    -- 示例: 每5秒切换动画
    -- if time > 5 then
    --     time = 0
    --     spineAddAnimation('aris1', 0, 'dance', true, 0)
    -- end
end

function onEvent(name, value1, value2, value3, value4)
    -- 处理事件
end

function onDestroy()
    -- 清理所有角色
    for _, tag in ipairs(characters) do
        if spineSpriteExists(tag) then
            removeSpineSprite(tag)
        end
    end
    characters = {}
end

-- ============================================
-- Spine API 完整参考
-- ============================================
--
-- === 创建与销毁 ===
-- makeSpineSprite(tag, skeletonPath, atlasPath, x, y)
-- spineSpriteExists(tag)
-- addSpineSprite(tag, inFront)
-- removeSpineSprite(tag, destroy)
--
-- === 动画控制 ===
-- spineSetAnimation(tag, trackIndex, animationName, loop)
-- spineAddAnimation(tag, trackIndex, animationName, loop, delay)
-- spineClearTrack(tag, trackIndex)
-- spineClearTracks(tag)
-- spineSetMix(tag, fromAnimation, toAnimation, duration)
-- spineSetAnimationSpeed(tag, trackIndex, speed)
-- spineGetAnimations(tag)  -> 返回动画名数组
--
-- === 位置 & 变换 ===
-- spineSetPosition(tag, x, y)
-- spineSetScale(tag, scaleX, scaleY)
-- spineSetAngle(tag, angle)
-- spineSetFlip(tag, flipX, flipY)
-- spineSetAlpha(tag, alpha)      -- 0 到 1
-- spineSetColor(tag, color)      -- 例如: 'FF0000' 红色
-- spineSetAntialiasing(tag, enabled)
-- spineSetVisible(tag, visible)
--
-- === 屏幕/相机控制 (新功能) ===
-- spineScreenCenter(tag, pos)    -- pos: 'x', 'y', 'xy'
-- spineSetObjectCamera(tag, camera)  -- camera: 'game', 'hud', 'other'
-- spineSetScrollFactor(tag, scrollX, scrollY)  -- 1=跟随, 0=固定
--
-- === 边界控制 (防止裁剪, 新功能) ===
-- spineComputeFullBounds(tag)    -- 遍历所有动画计算完整边界
-- spineSetBoundingBox(tag, animationName, clip)  -- clip默认false
-- spineSetSize(tag, width, height)  -- 手动设置宽高
-- spineSetOriginOffset(tag, offsetX, offsetY)  -- 手动设置原点偏移
--
-- === 骨骼控制 ===
-- spineGetBonePosition(tag, boneName)  -> 返回 [x, y]
-- spineSetBonePosition(tag, boneName, x, y)
-- spineGetAttachmentPosition(tag, slotName, attachmentName) -> [x, y]
--
-- === 信息查询 ===
-- spineGetInfo(tag)  -> 返回表: {width, height, x, y, scaleX, scaleY, ...}
