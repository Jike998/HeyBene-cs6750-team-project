# Controller App Handoff

## 目的
这个文档给另一个 Claude 窗口使用，避免继续把 `controller app` 做偏。

当前项目是 **两个 app**：
1. **Robot App**：装在小车上的手机，负责 camera-first 机器人端界面。
2. **Controller App**：装在人手里的手机，负责把手机当作手柄来遥控小车。

**你现在只负责 `Controller App`。不要再把 Robot App 的内容混进去。**

---

## 绝对不要再犯的错误
之前已经犯过的错误：
- 把 `Drive / Auto / Track` 当作 controller app 的主结构
- 把 `Battery / Latency / Server live / Collect` 这种 robot-side 信息放到 controller 主界面
- 做成了工程调试页 / 占位骨架，而不是游戏手柄式控制界面
- 用“先做个能跑的骨架再慢慢补 UI”的方式，结果完全偏离用户要的设计

### 明确规则
- **Controller App 不是 Robot App 的缩小版**
- **Controller App 不是工程仪表盘**
- **Controller App 不是模式管理中心**
- **Controller App 要优先像游戏控制器 / 手柄**

---

## Controller App 的正确定位
这是一个 **controller-side app**，用户手持手机，把它当作控制器。

### 核心任务
- 进行遥控操作
- 左右手分工明确
- 横屏优先
- 操作像游戏，而不是像机器人后台管理页面

### 设计关键词
- landscape
- gamepad-like
- left-hand / right-hand separation
- minimal telemetry
- no clutter on main sightline
- mobile gaming feel
- clean / premium / Apple-like polish, but **interaction metaphor is game controller**, not iPhone Camera

---

## 用户已经明确表达过的需求
### 1. 左右手分区
控制必须分布在横屏两侧。

用户原话的核心意思：
- 左手一侧一组控制
- 右手一侧一组控制
- 不要把控件堆在中间

### 2. 两种控制布局
至少支持这两种：

#### A. Dual Stick
- 两个摇杆分别位于左右两侧
- 可以作为双摇杆手柄布局
- 后续可以再区分 tank / arcade，但第一版先把双摇杆布局做对

#### B. Arrow + Throttle
- 左边：左右方向箭头
- 右边：前进 / 刹车 / 后退
- 更像简单赛车/遥控器控制法

### 3. 参数不是主角
用户已经明确说过：
- 参数不是必须展示的
- 即使展示，也**不能遮挡主视线**
- 不能影响驾驶

所以：
- 不要把 telemetry 放在中央
- 不要做大块状态栏
- 最多做很弱的状态提示、小角标、小 pill

### 4. 不要把 Robot App 的职责搬过来
以下内容不应该成为 Controller App 主界面的重心：
- `Drive / Auto / Track` 主模式切换
- battery / confidence / telemetry 大面板
- collect 状态
- robot-side 模型说明
- camera-first mode management

如果需要和 Robot App 协同，也应该是：
- 轻量状态提示
- 而不是主界面主体内容

---

## 当前正确的工作边界
### 你要改的目录
- `apps/controller_app/`

### 不要碰
- `apps/robot_app/`
- Robot App 的 Flutter 页面

如果要双窗口并行工作：
- 本窗口只改 `controller_app`
- 另一个窗口只改 `robot_app`

---

## 对当前 controller app 状态的判断
当前已安装到手机上的 controller app 是 **错误方向的原生骨架**。
它已经被用户明确否定。

### 现状问题
- 太像调试页
- 有 Robot App 的状态语义混入
- 不是游戏手柄界面
- 不是用户要的控制布局

### 这意味着
不要继续在旧 UI 上做小修小补。
应该直接按正确目标重做 controller 主界面。

---

## 推荐实施策略
### 第一版先做对结构
优先顺序：
1. 横屏主界面
2. 左右手控制区
3. 双摇杆布局
4. Arrow + Throttle 布局
5. 布局切换入口
6. 极简状态提示
7. 如需视频，仅做不挡视线的小窗/弱化区域

### 不要一开始就做很多工程功能
第一版目标是：
- 真机上看起来对
- 手柄逻辑对
- 布局结构对
- 和用户预期一致

不是：
- 先堆协议
- 先堆状态
- 先堆调试信息

---

## 可接受的主界面结构
### 顶部
只允许很少的信息：
- connection state（可选）
- maybe battery（可选）
- maybe layout switch（可选）

### 中间
- 尽量保持开阔
- 如有视频，只能弱化/小窗，不要挡住操作

### 左下 / 左侧
- 左手控制区

### 右下 / 右侧
- 右手控制区

### 底部或角落
- 布局切换
- 小型状态提示

---

## 成功标准
如果做对了，用户看到 controller app 后应该说：
- 这像手机手柄/游戏控制器
- 左右手逻辑清楚
- 不像工程后台
- 不再混入 robot app 的模式和数据面板

如果看到后还是像：
- dashboard
- telemetry app
- robot admin page
- 简单按钮 demo

那就还是错的。

---

## 给接手窗口的最后一句话
**不要继续沿用当前 controller app 已安装的那版 UI。**
它方向错了。

请直接按照“横屏游戏手柄 + 左右分侧 + 双布局 + 极简信息”的方向重做。
