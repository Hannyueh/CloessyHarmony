# Cloessy

Cloessy 是一个 HarmonyOS NEXT 用于替换云莓智能的宿舍智能门锁客户端，去除了打卡等无用的功能，主界面极简设计，滑动开门。针对开门进程进行了优化，大大提升了解锁成功率和速度。设计了三种不同尺寸的桌面卡片，桌面点击即可开门，无需进入软件。长按主界面可打开设置。可使用小白调试助手或HoKit等工具进行侧载安装到华为HarmonyOS 5/6/7及以上的手机上。

## 技术框架

- **平台**：HarmonyOS NEXT，Stage 模型，ArkTS + ArkUI
- **SDK**：targetSdkVersion 6.0.2(22)，compatibleSdkVersion 6.0.0(20)
- **蓝牙**：`@kit.ConnectivityKit`，BLE GATT 连接、服务发现、通知订阅和开锁指令写入
- **服务卡片**：Form Kit / `FormExtensionAbility`，提供 2×2、2×4、1×2 三种卡片
- **实况窗**：`@kit.LiveViewKit`，展示开门阶段和结果，不可用时自动降级
- **快捷入口**：`shortcuts_config.json` + `AppServiceExtensionAbility`，支持桌面长按快捷开门和智慧生活场景
- **本地数据**：Preferences 保存账号、门锁和设置；卡片 token 通过应用沙箱文件跨进程共享
- **界面**：原生 ArkUI 组件，自定义圆环背景、斜切覆盖、底部进度条

### 工程结构

```text
entry/src/main/ets/
├─ entryability/        应用入口、卡片与智慧生活无界面 Ability
├─ entryformability/    桌面卡片 FormExtensionAbility
├─ pages/               主页面与旧版页面
├─ components/cloessy/  设置、登录、二维码、圆环等组件
├─ services/            账号、门锁、BLE、卡片、实况窗、智慧生活服务
├─ model/               数据模型
└─ widgets/             2×2、2×4、1×2 服务卡片
```

## 使用说明

### 首次使用

1. 打开 Cloessy，主页默认深色；
2. 长按屏幕空白处，输入云莓账号和密码登录；
3. 登录后自动获取学校和已授权门锁；
4. 首次开门需要允许蓝牙权限。

### 应用内开门

1. 在主页向上滑动；
2. 页面按“准备凭据 → 连接门锁 → 发现服务 → 发送指令 → 等待返回”显示当前步骤；
3. 开锁过程中向下滑动可取消，覆盖层向下退出；
4. 开门成功后整屏保持白色并显示「开锁成功」，随后平滑渐变回深色主页。

### 设置

- 登录后长按主页空白处进入设置；
- 在列表顶部继续向下拉，或点击右上角 `×`，面板向下退出；
- 设置中可查看账号、切换门锁、编辑账号、开启「打开软件自动开门」、查看使用说明和开发者信息。

### 桌面卡片

- 支持 2×2、2×4 和 1×2 胶囊卡片；
- 卡片始终为深色；
- 点击卡片直接发起开门；
- 解锁时底部进度条向右增长，成功后进度条走满并自动复位；
- 卡片开门在后台执行，耗时会受系统后台 BLE 调度影响。

### 快捷方式

- 桌面长按 Cloessy 图标，可使用「开门」快捷方式；

### 自动开门与凭据刷新

- 开启「打开软件自动开门」后，冷启动恢复登录或从后台回到应用时会自动开始开门；
- 每次开门前都会刷新门锁凭据，减少密钥过期导致的连接超时；
- 会话超过 8 分钟会自动重新登录并重新获取门锁；
- 刷新失败时仅在短时间内允许使用缓存凭据。

## 隐私政策

Cloessy 不收集与开门无关的个人信息，账号与凭据仅加密保存在本机。完整说明见 [docs/privacy.html](docs/privacy.html)。

## 其他客户端版本

本应用的Android分支版本参见由PhoenixTree维护的https://github.com/PhoenixTreeZh/yunmei-lite，本项目基于该项目开发和维护，详细技术原理可以参见该项目的说明，本项目在开锁进程的优化方式和该项目略有差异，但对于门锁的兼容性等问题与该项目一致。

## 作者联系方式

| 角色 | 作者 | 邮箱 | 个人主页 |
|---|---|---|---|
| App 开发 | 寒悦Hannyueh | Hannyueh@163.com | https://github.com/Hannyueh |
| 逆向工程 | PhoenixTree | phoenixtree_zh@163.com | https://github.com/PhoenixTreeZh |
