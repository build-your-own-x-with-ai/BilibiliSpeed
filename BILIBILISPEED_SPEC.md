# BilibiliSpeed 需求与实现规范

## 项目概述

**项目名称**: BilibiliSpeed  
**基础项目**: Bilibili-NEXT (macOS 1.1.4 / iOS 0.1.4)  
**核心功能**: 为离线缓存视频播放增加扩展速度选项（0.25× - 128×）  
**开发方法**: TDD (测试驱动开发) + Git 版本控制

---

## 实现与验证状态（2026-11-07）

本节以实际代码为准；下文第二、三节是最初的设计草案，与实现不一致处以本节为准。

- 实现位置：`Sources/BiliGlass/Player.swift`（`offlineSpeedOptions`、`onlineSpeedOptions`、`clampSpeed`、`formatSpeed`、`availableSpeeds`、`setSpeed`），Mac 倍速菜单在 `Sources/BiliGlass/Views.swift`，iOS 选择器为 `Apps/iOS/Sources/MobileSpeedPicker.swift`，入口在 `MobilePlayer.swift` 的“播放选项”菜单。
- 草案中的 `SpeedSelectionView`、`MobileSpeedSelector` 和 `showSpeedSelection` 未采用；Mac 直接复用原有倍速菜单。
- 选项按 `isOffline` 决定，不再按 `canPlayFastForward` 区分；在线保留原有六档。
- 测试：`swift test --filter "SpeedSelectionTests|PlaybackSpeedPreferenceTests"`（8 项），全量 `swift test` 263 项通过；`Scripts/build-ios.sh` 模拟器构建通过。
- 本机 AVPlayer 实测（10 分钟 720p H.264 本地文件，每档播放 1 秒）：22 档均被接受，实际推进约为设定值的 92%–94%，128× 约 117×。
- 尚未验证：应用内播放已下载视频的画面与音频、高倍速下的弹幕、iPhone／iPad 真机。

---

## 一、需求分析

### 1.1 功能需求

#### 主要需求
为已下载到本地的视频提供以下播放速度选项：

```
0.25, 0.5, 0.75, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 32, 64, 128
```

**共计 22 个速度档位**

#### 功能边界

- **适用范围**: 仅离线缓存视频（`isOffline = true`）
- **在线限制**: 在线播放保持现有逻辑（HLS 2×，完整缓存 3×）
- **系统能力**: 依赖 `AVPlayerItem.canPlayFastForward` 的实际支持
- **临时倍速**: 保持现有右方向键加速功能（长按临时加速）

### 1.2 用户场景

1. **快速浏览**: 使用 4× - 16× 快速浏览已看过的内容
2. **超快跳过**: 使用 32× - 128× 跳过片头/片尾/无关内容
3. **慢速学习**: 使用 0.25× - 0.75× 精细学习技术内容
4. **正常观看**: 1× - 3× 覆盖日常观看需求

### 1.3 非功能需求

- **性能**: 速度切换响应时间 < 200ms
- **稳定性**: 高速播放不崩溃、不丢帧（在系统能力范围内）
- **兼容性**: macOS 26+, iOS/iPadOS 26+
- **可维护性**: 清晰的代码结构，完整的测试覆盖
- **用户体验**: 速度选择界面直观，状态反馈清晰

---

## 二、技术设计

### 2.1 架构变更

#### 现有架构
```
Playback (Sources/BiliGlass/Player.swift)
├── speed: Float = 1              // 常规播放速度
├── temporarySpeed: Float = 3      // 临时加速（右方向键）
└── temporaryRate(isOffline, canPlayFastForward) -> Float
    ├── 离线且支持: 3×
    └── 在线 HLS: 2×
```

#### 新架构
```
Playback
├── speed: Float = 1                    // 用户选择的常规速度
├── temporarySpeed: Float = 3           // 临时加速速度
├── availableSpeeds: [Float]           // 当前可用速度列表（动态）
├── offlineSpeedOptions: [Float]       // 离线速度档位（静态）
└── effectiveSpeed() -> Float          // 实际生效速度
    └── isBoosting ? temporarySpeed : speed
```

### 2.2 数据模型

#### 速度档位定义
```swift
extension Playback {
  static let offlineSpeedOptions: [Float] = [
    0.25, 0.5, 0.75, 1, 2, 3, 4, 5, 6, 7, 8,
    9, 10, 11, 12, 13, 14, 15, 16, 32, 64, 128
  ]
  
  static let onlineSpeedOptions: [Float] = [
    0.5, 0.75, 1, 1.25, 1.5, 2
  ]
}
```

#### 速度可用性判断
```swift
func availableSpeeds(for item: AVPlayerItem?, isOffline: Bool) -> [Float] {
  guard let item, item.status == .readyToPlay else {
    return [1.0]  // 加载中时仅显示 1×
  }
  
  if isOffline && item.canPlayFastForward {
    return Self.offlineSpeedOptions
  } else {
    return Self.onlineSpeedOptions
  }
}
```

### 2.3 UI 设计

#### macOS 界面
```
┌─────────────────────────────────────┐
│  播放速度                            │
├─────────────────────────────────────┤
│  ○ 0.25×    ○ 5×      ○ 12×        │
│  ○ 0.5×     ○ 6×      ○ 13×        │
│  ○ 0.75×    ○ 7×      ○ 14×        │
│  ● 1×       ○ 8×      ○ 15×        │
│  ○ 2×       ○ 9×      ○ 16×        │
│  ○ 3×       ○ 10×     ○ 32×        │
│  ○ 4×       ○ 11×     ○ 64×        │
│                        ○ 128×       │
└─────────────────────────────────────┘
```

#### iOS 界面
```
竖屏：滚动列表
横屏播放：底部半透明面板，分段选择器
```

### 2.4 核心逻辑变更

#### 播放速度应用点

1. **初始播放**: `player.playImmediately(atRate: speed)`
2. **恢复播放**: `togglePlayback()`, `continuePlayback()`
3. **速度切换**: 新增 `setSpeed(_ rate: Float)`
4. **临时加速**: `startBoosting()` / `stopBoosting()`
5. **质量切换**: 保持当前 `speed`，恢复时应用

#### 状态持久化

```swift
// 用户偏好：分离在线/离线速度
UserDefaults: "offlinePlaybackSpeed" -> Float  // 默认 1.0
UserDefaults: "onlinePlaybackSpeed" -> Float   // 默认 1.0

// 加载时应用
func load(...) {
  // ...
  if isOffline {
    speed = UserDefaults.standard.float(forKey: "offlinePlaybackSpeed") ?? 1.0
  } else {
    speed = UserDefaults.standard.float(forKey: "onlinePlaybackSpeed") ?? 1.0
  }
  // 验证速度在可用范围内
  speed = clampSpeed(speed, for: item, isOffline: isOffline)
}
```

---

## 三、实现计划

### 3.1 开发阶段

#### Phase 1: 测试基础设施（TDD 第一步）
- [ ] 创建 `SpeedSelectionTests.swift`
- [ ] 编写速度档位枚举测试
- [ ] 编写速度可用性判断测试
- [ ] 编写速度持久化测试

#### Phase 2: 数据模型（TDD 实现）
- [ ] 实现 `Playback.offlineSpeedOptions`
- [ ] 实现 `availableSpeeds(for:isOffline:)`
- [ ] 实现速度验证与约束逻辑
- [ ] 通过 Phase 1 所有测试

#### Phase 3: 播放逻辑集成
- [ ] 修改 `load()` 方法：应用保存的速度
- [ ] 实现 `setSpeed(_ rate: Float)` 方法
- [ ] 更新 `togglePlayback()` / `continuePlayback()`
- [ ] 保持临时加速功能不受影响
- [ ] 编写播放速度切换测试

#### Phase 4: UI 实现（macOS）
- [ ] 创建 `SpeedSelectionView.swift`
- [ ] 多列网格布局（macOS Liquid Glass 风格）
- [ ] 集成到播放页设置面板
- [ ] 实时状态同步（选中态、禁用态）

#### Phase 5: UI 实现（iOS）
- [ ] 创建 `MobileSpeedPicker.swift`
- [ ] 竖屏列表 + 横屏底部面板
- [ ] 集成到 `MobilePlayer.swift`
- [ ] 触摸交互优化

#### Phase 6: 集成测试与验证
- [ ] 离线视频速度切换测试（0.25× - 128×）
- [ ] 在线视频速度限制测试
- [ ] 临时加速与常规速度交互测试
- [ ] 质量切换时速度保持测试
- [ ] 界面状态一致性测试

#### Phase 7: 文档与发布
- [ ] 更新 `CHANGELOG.md`
- [ ] 更新 `GuideContent.currentUpdates`
- [ ] 更新 `QA.md` 验证范围
- [ ] 提交 Git 历史记录
- [ ] 构建与打包

### 3.2 Git 工作流

```bash
# 初始化功能分支
git checkout -b feature/bilibili-speed

# Phase 1: 测试基础
git add Tests/BiliGlassTests/SpeedSelectionTests.swift
git commit -m "Add speed selection test infrastructure

- Define offline speed options (0.25× - 128×)
- Test speed availability for offline/online content
- Test speed persistence across sessions

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"

# Phase 2: 数据模型
git add Sources/BiliGlass/Player.swift
git commit -m "Implement speed selection data model

- Add offlineSpeedOptions constant
- Implement availableSpeeds(for:isOffline:) method
- Add speed validation and clamping logic

All Phase 1 tests passing.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"

# Phase 3-7: 类似提交...

# 最终合并
git checkout main
git merge --no-ff feature/bilibili-speed
git tag v1.2.0-speed
```

---

## 四、测试策略

### 4.1 单元测试

#### `SpeedSelectionTests.swift`
```swift
import Testing
@testable import BiliGlass

@Suite("Speed Selection") struct SpeedSelectionTests {
  
  @Test("Offline speed options complete")
  func offlineSpeedOptionsComplete() {
    let expected: [Float] = [
      0.25, 0.5, 0.75, 1, 2, 3, 4, 5, 6, 7, 8,
      9, 10, 11, 12, 13, 14, 15, 16, 32, 64, 128
    ]
    #expect(Playback.offlineSpeedOptions == expected)
    #expect(Playback.offlineSpeedOptions.count == 22)
  }
  
  @Test("Speed availability for offline content")
  func speedAvailabilityOffline() async {
    // Mock AVPlayerItem with canPlayFastForward = true
    // Verify returns full offline speed options
  }
  
  @Test("Speed availability for online content")
  func speedAvailabilityOnline() async {
    // Mock online playback
    // Verify limited to online speed options
  }
  
  @Test("Speed persistence across sessions")
  func speedPersistence() {
    // Save offline speed 16×
    // Create new Playback instance
    // Verify speed restored
  }
  
  @Test("Speed clamping to valid range")
  func speedClamping() {
    // Set speed 200× (invalid)
    // Verify clamped to 128× (max offline)
  }
}
```

### 4.2 集成测试

```swift
@Suite("Offline Playback Speed") struct OfflineSpeedTests {
  
  @Test("Switch speed during offline playback")
  func switchSpeedDuringPlayback() async {
    // Open offline video
    // Play at 1×
    // Switch to 16×
    // Verify player.rate == 16
    // Verify playback continues
  }
  
  @Test("Temporary boost preserves user speed")
  func temporaryBoostPreservesSpeed() async {
    // Set speed 8×
    // Start boosting (should go to temporarySpeed)
    // Stop boosting
    // Verify returns to 8×
  }
}
```

### 4.3 手动验证清单

#### macOS
- [ ] 下载视频 A（测试 BVID）
- [ ] 播放，切换到 16× —— 验证流畅播放
- [ ] 切换到 64× —— 验证播放（可能有帧跳跃）
- [ ] 切换到 0.25× —— 验证慢放清晰
- [ ] 长按右方向键 —— 验证临时加速仍为 3×（或配置值）
- [ ] 松开 —— 验证返回 16×
- [ ] 切换清晰度 —— 验证速度保持 16×
- [ ] 关闭播放页，重新打开 —— 验证速度恢复为默认或上次保存值

#### iOS
- [ ] 下载视频 B
- [ ] 竖屏播放，打开速度选择器 —— 验证列表显示完整
- [ ] 选择 32× —— 验证应用成功
- [ ] 横屏播放 —— 验证速度保持 32×
- [ ] 后台/前台切换 —— 验证速度不变

---

## 五、风险与约束

### 5.1 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| AVPlayer 高速播放崩溃 | 高 | 捕获异常，降级到最高支持速度 |
| 极高速度掉帧严重 | 中 | UI 提示"仅跳转，无流畅保证" |
| 音频在高速下异常 | 中 | 禁用极高速音频，或提供静音选项 |
| 不同编码格式支持度不同 | 低 | 实测主流格式，文档说明限制 |

### 5.2 用户体验约束

- **速度上限**: 128× 为理论上限，实际可播放速度取决于：
  - 视频编码格式（H.264, H.265, AV1）
  - 设备性能（M1/M2/M3, A17/A18）
  - 视频分辨率（1080p vs 4K vs 8K）
  
- **音频处理**: 
  - 2× 以下：正常变调播放
  - 2× - 4×：可能音调异常
  - 4× 以上：建议提供静音选项

- **UI 反馈**:
  - 当前速度显示在播放器上
  - 速度不可用时灰显并说明原因（"在线播放限速"/"视频加载中"）

### 5.3 兼容性约束

- **向后兼容**: 旧版本缓存的视频仍可用（速度默认 1×）
- **配置迁移**: 旧 `speed` 值在合理范围内保留
- **在线播放**: 完全不受影响，保持现有逻辑

---

## 六、验收标准

### 6.1 功能验收

- ✅ 离线视频可选择全部 22 个速度档位
- ✅ 在线视频速度限制在 6 个档位（保持现有逻辑）
- ✅ 速度选择立即生效，无需重新加载
- ✅ 速度偏好持久化，重启应用后恢复
- ✅ 临时加速功能不受常规速度影响

### 6.2 质量验收

- ✅ 所有单元测试通过（swift test）
- ✅ 无新增编译警告
- ✅ 代码符合项目风格（匹配 `CLAUDE.md` 约定）
- ✅ 手动测试清单 100% 完成

### 6.3 文档验收

- ✅ `CHANGELOG.md` 包含功能说明
- ✅ `GuideContent` 更新提示用户新功能
- ✅ `QA.md` 记录验证范围和已知限制

---

## 七、后续优化方向

### 7.1 短期优化
- 速度预设方案（"快速浏览 8×"/"学习模式 0.5×"）
- 速度渐变过渡（避免突变卡顿）
- 高速播放时自动降低画质（省性能）

### 7.2 长期优化
- 智能速度推荐（根据观看历史）
- 速度与章节联动（片头自动 16×）
- 弹幕同步调整（高速下降低密度）

---

## 附录 A：关键代码位置

### A.1 现有代码结构
```
Sources/BiliGlass/
├── Player.swift              # 核心播放逻辑（~850 行）
│   ├── speed: Float          # 第 45 行
│   ├── temporarySpeed        # 第 47 行
│   ├── temporaryRate()       # 第 619 行
│   └── togglePlayback()      # 第 96 行
├── PlayerControls.swift      # 播放控制 UI（96 行）
├── PlayerKeyboard.swift      # 键盘事件处理
└── Preferences.swift         # 设置页面

Apps/iOS/Sources/
├── MobilePlayer.swift        # iOS 播放器
└── MobileVideoControls.swift # iOS 控制栏
```

### A.2 需要修改的文件
1. **Sources/BiliGlass/Player.swift** (核心逻辑)
   - 添加 `offlineSpeedOptions`
   - 添加 `availableSpeeds(for:isOffline:)`
   - 添加 `setSpeed(_ rate: Float)`
   - 修改 `load()` 应用保存的速度

2. **Sources/BiliGlass/SpeedSelectionView.swift** (新建)
   - macOS 速度选择 UI

3. **Apps/iOS/Sources/MobileSpeedPicker.swift** (新建)
   - iOS 速度选择 UI

4. **Tests/BiliGlassTests/SpeedSelectionTests.swift** (新建)
   - 单元测试与集成测试

5. **Sources/BiliGlass/FeatureGuide.swift**
   - 更新 `currentUpdates` 说明新功能

6. **CHANGELOG.md**
   - 记录功能变更

---

## 附录 B：参考现有实现

### B.1 临时加速逻辑（保持不变）
```swift
// Player.swift:619
static func temporaryRate(isOffline: Bool, canPlayFastForward: Bool) -> Float {
  isOffline && canPlayFastForward ? 3 : 2
}

// 启动加速
func startBoosting() {
  isBoosting = true
  if player.rate != 0 { player.rate = temporarySpeed }
}

// 停止加速
func stopBoosting() {
  isBoosting = false
  if player.rate != 0 { player.rate = speed }
}
```

### B.2 速度应用时机
```swift
// 1. 初始播放
player.playImmediately(atRate: speed)

// 2. 恢复播放
player.playImmediately(atRate: isBoosting ? temporarySpeed : speed)

// 3. 实时切换
if player.rate != 0 {
  player.rate = isBoosting ? temporarySpeed : speed
}
```

---

**文档版本**: 1.0  
**创建日期**: 2026-11-06  
**作者**: Claude Opus 5.5 (1M context)  
**状态**: 待审核
