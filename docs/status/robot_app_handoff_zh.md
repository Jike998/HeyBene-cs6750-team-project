# Robot App 中文交接文档

## 这份文档的用途

这份文档给以下场景使用：

- 队友接手开发
- 真机测试前先理解界面和逻辑
- 后续写新手第一次使用引导
- 中断后快速恢复上下文

当前工作基线：

- 分支：`backup/working-tree-20260428-1615`
- 当前重点 app：`apps/robot_app`

---

## 一、先讲清楚两个模式

### 1. Robot mode 是什么

`Robot` 是真正控制小车的主端。

它负责：

- 连接小车硬件
- 决定当前运行模式：`Drive / Auto / Track`
- 决定 `START / STOP`
- 决定现在是否应该显示视频
- 决定现在是否接受远程控制
- 决定当前控制权在谁手里

一句话：

**Robot 是系统真源头。**

### 2. Controller mode 是什么

`Controller` 是远程控制端。

它负责：

- 连接 robot phone
- 显示 robot 回传的视频和状态
- 发送远程控制输入
- 提供不同控制布局

一句话：

**Controller 负责“怎么看、怎么控”，但不负责决定 robot 真正在跑什么。**

---

## 二、当前主流程总规则

### 1. START / STOP 是统一运行开关

不管当前是：

- `Drive`
- `Auto`
- `Track`

都由 `START / STOP` 统一控制运行。

规则：

- 小车没连上时，`START` 仍然显示
- 但这时 `START` 是禁用的，不能点
- 只有 `Car USB` 连上后，才能真正 `START`
- 只有 `START` 后，才开始视频和控制链路
- `STOP` 后，当前运行态要清掉

### 2. 控制权不是设置项，而是运行时状态

当前规则：

- 正常情况下通常只有一个控制设备
- 如果真的有多个控制源，谁先发有效输入，谁先接管
- Robot 设置里的 `Controller` 只负责显示当前控制来源
- 它不是一个让用户手动切换控制权的开关

### 3. 视频显示规则

#### Robot mode

- `START` 前：显示背景图
- `START` 后：显示本地相机
- `STOP` 后：回到背景图

#### Controller mode

- robot 没启动前：显示背景图
- robot 已启动但第一帧视频还没到：显示 `Video starting`
- 收到第一帧后：显示远程预览
- robot `STOP` 后：回到背景图

---

## 三、Robot mode 界面说明

文件入口：

- `apps/robot_app/lib/features/robot_camera/presentation/robot_camera_screen.dart`

### 1. 中间大区域：背景图 / 本地相机 / Track 框

#### 背景图

什么时候显示：

- Robot 没在运行
- 本地相机没显示时

作用：

- 待机画面

#### 本地相机

什么时候显示：

- Robot 已经 `START`
- 相机已经准备好

作用：

- 显示车上手机本地实时画面

#### Track 跟踪框

什么时候显示：

- 当前模式是 `Track`
- Robot 正在运行
- backend 已经识别到目标并回了目标框

作用：

- 显示当前正在追踪的目标
- 框会跟着目标移动

注意：

- 现在不是手点目标框
- 而是按目标类别自动识别出的框

### 2. 左上信息托盘

#### 收起时显示

- 蓝牙状态
- USB 状态
- 电池
- `Info / Hide`

#### 展开时显示

- `PING`
- `SPEED`
- `STEERING`
- 当前模式对应的一个关键指标

对应关系：

- `Drive` -> `VOLTAGE`
- `Auto` -> `CONFIDENCE`
- `Track` -> `DISTANCE`

#### 额外信息

在 `Drive` 且采集中时，会显示：

- `REC`
- `SESSION`

在 `Auto / Track` 下，会显示 backend 相关信息：

- `BACKEND`
- `INF`
- `LEFT`
- `RIGHT`

### 3. 右上角手柄图标

作用：

- 切换到 `Controller mode`

说明：

- 这是角色切换按钮
- 不是运行模式切换按钮

### 4. 底部模式切换条

当前模式条是：

- `AUTO`
- `DRIVE`
- `TRACK`

作用：

- 切换 robot 当前运行模式

切换规则：

- 会先停掉当前运行
- 再切到新模式并重新配置 backend

说明：

- 这是 Robot 的真实 mode
- 不是 Controller 的布局切换

### 5. 中间主按钮

#### Drive

- 空闲时显示：`START`
- 运行时显示：`STOP`

#### Auto

- 空闲时显示：`START AUTO`
- 运行时显示：`STOP AUTO`

#### Track

- 空闲时显示：`START TRACK`
- 运行时显示：`STOP TRACK`

按钮规则：

- 空闲且满足条件时，点它启动当前模式
- 运行中时，点它停止当前模式

启用规则：

- 只有 `Car USB` 已连接时，空闲态的启动按钮才可点
- 停止按钮始终可点

### 6. 设置按钮

图标：齿轮

作用：

- 打开 Robot 设置面板

---

## 四、Robot 设置面板说明

### 1. Connection 区

#### Car USB

按钮：`USB`

作用：

- 连接或断开小车 USB

意义：

- 这是 `START` 的硬前提
- 不连车就不能启动

#### Controller Links

##### Phone Link

作用：

- 开启或关闭 robot 端蓝牙控制链路

意义：

- 给另一台 controller 手机连接用

##### PC Link

作用：

- 开启或关闭 robot 端 PC 链路

意义：

- 给 PC 调试或远控路径使用

#### PC Status

什么时候显示：

- PC link 端口存在时

作用：

- 显示当前 PC 监听或连接状态

#### Car BLE

当前状态：

- `Unavailable`

意义：

- 当前还没实现

### 2. Drive 相关设置

#### Collect data

什么时候显示：

- 当前 mode 是 `Drive`

作用：

- 开关 Drive 模式下的数据采集

意义：

- 以后可以用来做训练数据
- 不是一个通用录像按钮

#### Session

什么时候显示：

- 当前已有采集会话路径

作用：

- 显示当前数据采集 session

#### Controller

作用：

- 只读显示当前控制来源

可能显示：

- `PC`
- `Gamepad`
- `Phone`
- `None`

意义：

- 这是显示值
- 不是切换器

#### Speed mode

可选：

- `Low`
- `Normal`
- `High`

作用：

- 当前 Drive 速度档位

意义：

- 对应小车输出强度 / 速度档位

### 3. Auto 相关设置

#### Model

作用：

- 显示/选择当前 Auto 模型

#### Device

可选：

- `CPU`
- `GPU`
- `NNAPI`

作用：

- 选择推理运行位置

说明：

- 当前优先级不高
- 主要是计算放在哪跑

#### Speed mode

作用：

- 当前 Auto 速度档位

### 4. Track 相关设置

#### Model

作用：

- 选择 Track 用的检测模型

#### Target type

当前选项：

- `Person`
- `Dog`
- `Cat`
- `Bicycle`
- `Car`
- `Banana`

作用：

- 选择要跟踪的目标类别

重点：

- 这是现在 Track 的主输入
- 不再通过点屏幕手动指定目标点

#### Device

作用：

- Track 模式计算设备

#### Speed mode

作用：

- Track 模式速度档位

---

## 五、Track 现在的正确语义

现在 `Track` 的意思是：

1. 选择一个 Track 模型
2. 选择一个目标类别
3. 点 `START TRACK`
4. backend 自动识别画面里符合该类别的目标
5. backend 返回目标框
6. 界面上的框跟着目标移动

现在 `Track` 不再表示：

- 用户手点屏幕选一个目标位置

---

## 六、Controller mode 界面说明

文件入口：

- `apps/robot_app/lib/features/control/presentation/control_screen.dart`

### 1. 主画面三种状态

#### 背景页

什么时候显示：

- 没连 robot
- 或者 robot 还没启动
- 或者还没进入视频阶段

#### Video starting

什么时候显示：

- robot 已启动
- 视频已允许
- 但第一帧还没到

#### 远程预览

什么时候显示：

- robot 回来的状态表示视频已启用
- 且已经收到远程预览帧

### 2. 顶部信息条

#### Link pill

可能显示：

- `BT Linked`
- `USB Linked`
- `Robot Link`

点击逻辑：

- 蓝牙已连：断开蓝牙
- USB 已连：断开 USB
- 都未连：打开链路选择

#### 延迟 pill

显示：

- 已连接时显示延迟毫秒数
- 未连接时显示 `--`

#### Layout pill

显示：

- 当前 controller 布局名

意义：

- 只是 controller 自己的布局状态

#### Tune 按钮

作用：

- 打开 Controller Settings

#### Robot 图标按钮

作用：

- 回到 Robot mode

#### Driving Mode 切换器

当前选项：

- `Manual`
- `Auto`

意义：

- 这是 controller 自己的驾驶交互模式
- 不是 robot 的真实运行模式

### 3. 链路选择流程

#### 链路选择弹窗

当前选项：

- `Robot Phone via Bluetooth`
- `Direct USB`

意义：

- 蓝牙是主远控路径
- USB 是 fallback / debug 路径

#### Bonded Robot Picker

作用：

- 选择已经配对的 robot phone
- 用于建立蓝牙连接

### 4. Controller Settings

#### Driving Mode

作用：

- 切换 controller 自己的 driving mode

#### Layout

当前选项：

- `Dual`
- `Arrow`
- `One Hand`

作用：

- 切换 controller 控制布局

意义：

- 只影响 controller 自己的界面和操作方式
- 不改变 robot 的 runtime mode

#### Control Position

作用：

- 微调控制区域位置

规则：

- 按 driving mode + layout 分别保存
- 可 reset 单侧
- 可 reset 双侧

### 5. Controller 实际控制区

#### Dual

左边：

- 转向控制

右边：

- 油门 / 刹车控制

#### Arrow

左边：

- 方向控制簇

右边：

- 踏板控制区

#### One Hand

- 单手摇杆控制

这些控制区统一做的事情：

- 更新本地控制 UI
- 算出左右轮 drive 值
- 通过当前链路发送出去
- 最终是否真正生效，以 robot 侧控制权判断为准

---

## 七、真机测试步骤版

建议测试顺序：

1. 先测 Robot 基本门禁
2. 再测 Controller 链路和视频
3. 最后测 Track

### A. Robot 基本门禁测试

#### A1. 未连车启动测试

步骤：

1. 打开 app，进入 `Robot mode`
2. 不连接小车 USB
3. 看主按钮和主画面

预期：

- 主按钮显示 `START`
- 但按钮是禁用态，不能点击
- 主画面显示背景图，不显示实时相机

如果不符合，记录：

- `START` 是否还能点
- 是否一进来就出现相机

#### A2. 连接小车测试

步骤：

1. 打开设置
2. 在 `Car USB` 里点 `USB`
3. 等待连接完成

预期：

- USB 状态变成已连接
- 主按钮可以点击

如果不符合，记录：

- USB 按钮是否无反应
- 连接后主按钮是否仍禁用

#### A3. Drive 启停测试

步骤：

1. 保持 mode 在 `Drive`
2. 点 `START`
3. 观察主画面
4. 再点 `STOP`

预期：

- `START` 后显示本地相机
- `STOP` 后回到背景图
- 停止后不应继续显示实时画面

### B. Drive 数据采集测试

#### B1. Collect Data 开关

步骤：

1. 进入 `Drive`
2. 打开设置
3. 打开 `Collect data`
4. 展开左上信息托盘

预期：

- 展开后能看到 `REC`
- 如果 session 已创建，能看到 `SESSION`

如果不符合，记录：

- `Collect data` 开后是否完全没变化
- `REC` 是否不显示

### C. Controller 链路测试

#### C1. 打开 robot 端蓝牙链路

步骤：

1. 在 `Robot mode` 打开设置
2. 在 `Controller Links` 中点 `Phone Link`

预期：

- robot 端蓝牙控制链路启动

#### C2. Controller 蓝牙连接测试

步骤：

1. 切到 `Controller mode`
2. 点击顶部 `Robot Link`
3. 选择 `Robot Phone via Bluetooth`
4. 在配对设备列表里选 robot phone

预期：

- 顶部显示 `BT Linked`
- 顶部延迟开始显示数值

如果不符合，记录：

- 是否连不上
- 是否连上但没有延迟值

### D. Controller 视频门禁测试

#### D1. Robot 未启动时的视频

步骤：

1. 保持蓝牙已连
2. 不启动 Robot
3. 看 Controller 主画面

预期：

- 只显示背景页
- 不显示远程预览
- 不显示 `Video starting`

#### D2. Robot 启动后的首帧测试

步骤：

1. 回到 `Robot mode`
2. 在 `Drive` 下点 `START`
3. 再看 `Controller mode`

预期：

- 先显示 `Video starting`
- 收到首帧后切到远程预览

如果不符合，记录：

- 是否一直停在背景页
- 是否一直停在 `Video starting`
- 是否首帧出来后仍不切换

#### D3. Robot 停止后的视频回退测试

步骤：

1. Robot 已经在运行，Controller 已看到远程预览
2. 在 Robot 点 `STOP`
3. 看 Controller 画面

预期：

- Controller 回到背景页
- 不继续显示旧视频帧

### E. Track 主流程测试

#### E1. Track 启动测试

步骤：

1. 在 `Robot mode` 切到 `Track`
2. 在设置中选择：
   - `Track Model`
   - `Target type`
3. 点 `START TRACK`

预期：

- 不需要点击屏幕选目标
- Track 能直接启动

如果不符合，记录：

- 是否还需要点屏幕才有反应
- 是否启动失败

#### E2. Track 目标识别测试

建议优先测试这些目标：

- `Person`
- `Car`
- `Banana`

步骤：

1. 把 `Target type` 设成其中一个
2. 让目标进入画面
3. 保持 `Track` 运行

预期：

- backend 自动识别到对应目标
- 界面出现跟踪框
- 跟踪框位置大致正确

如果不符合，记录：

- 框完全不出现
- 框位置明显偏移
- 框识别成别的目标

#### E3. Track 跟随测试

步骤：

1. 让目标在画面中移动
2. 持续观察跟踪框

预期：

- 框跟着目标移动
- 不应该固定在屏幕某个点

如果不符合，记录：

- 框不动
- 框延迟太大
- 框跳动严重
- 框很快丢失

### F. 控制权测试

#### F1. 单控制源测试

步骤：

1. 保证只有一个控制源
2. 在 Controller 端发送输入
3. 观察 Robot 设置里的 `Controller`

预期：

- `Controller` 显示当前接管来源
- 控制输入正常生效

#### F2. 多控制源接管测试

步骤：

1. 先让一个控制源发送输入
2. 再让另一个控制源发送输入

预期：

- 第一个有效输入源先接管
- 后来的输入不会直接覆盖当前 owner
- Robot 侧显示当前 owner

如果不符合，记录：

- 是否后来的输入直接抢走控制权
- 是否 owner 显示不对

### G. 异常情况测试

#### G1. 蓝牙断开测试

步骤：

1. 让 robot 正在运行
2. 保持当前控制来源是 `Phone`
3. 主动断开蓝牙链路

预期：

- Robot 应立即停止当前远控驱动链路
- Controller 回到非运行态显示

#### G2. USB 断开测试

步骤：

1. 让 Robot 正在运行
2. 断开 `Car USB`

预期：

- Robot 停止运行
- 主按钮回到不可启动状态
- 视频应停止

---

## 八、测试反馈建议格式

为了让后续排查更快，建议测试结果按下面格式回报：

- Drive：正常 / 异常
- Collect Data：正常 / 异常
- Controller 链路：正常 / 异常
- Controller 视频：正常 / 异常
- Track 测了哪些目标：
- Track 框：正常 / 不出现 / 偏移 / 不跟随 / 跳动
- 控制权：正常 / 异常
- 蓝牙断开：正常 / 异常
- USB 断开：正常 / 异常
- 其他备注：

---

## 九、后续可继续扩展的方向

这份中文稿后面还可以继续扩展成：

- 新手第一次使用引导
- Apple 风格气泡提示文案
- 测试 checklist
- 版本交接说明

建议后面所有中文引导和交接内容，都以这份文档为母稿继续更新。
