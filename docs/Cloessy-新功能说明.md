# Cloessy 新功能与接入说明

## 1. 界面与手势

- 主页面：`entry/src/main/ets/pages/CloessyHome.ets`，由 `EntryAbility` 直接加载。
- 深蓝灰 `#171D29` / 骨白 `#E9E4DA` 双色；`ArcBackdrop` 绘制半透明灰的局部圆环。
- 未登录：底部显示「长按屏幕登录账号」；长按 600ms 打开登录面板。
- 已登录：底部显示「向上滑动开锁」；上滑跟手，松手超过阈值开始开门；长按打开设置。
- 开锁时色块以 10° 斜切边向上覆盖；使用 `curves.springMotion(0.55, 0.85)`，非线性、末端轻微回弹。
- 成功页显示「开锁成功」，1.2s 后切换主页颜色 A/B 并持久化到 Preferences。

## 2. 登录 / 设置 / 支持开发者

- 登录：`components/cloessy/LoginSheet.ets`，圆角底部面板，账号密码写到本机 Preferences（密码只存 MD5）。
- 设置：`components/cloessy/SettingsSheet.ets`，顶部 28vp 圆角，包含账号、密码掩码、门锁列表、开发者信息和「支持开发者」。
- 支持开发者：`components/cloessy/SupportDialog.ets`，28vp 圆角弹窗，两个二维码由 `QrCode`（Canvas）按矩阵绘制。
  - 寒悦（App 开发者）：`wxp://f2f04N2klPYTDSmB_QpsMXIA82w7sjBmkiP3aJ4-irD805c`
  - PhoenixTree（逆向工程）：`wxp://f2f0HJUusXm2h7MXr_jrPAOXk4zXdnalQJS2MI80-0wbnFo`
  - 矩阵保存于 `components/cloessy/QrData.ets`；不是 PNG 贴图。

## 3. 卡片

- 2×2：`widgets/UnlockCardSmall.ets`
- 2×4：`widgets/UnlockCardWide.ets`
- 1×2 胶囊：`widgets/UnlockCardCapsule.ets`；鸿蒙 `1*2` 为 1 行 × 2 列，即 2:1。
- 表单配置：`resources/base/profile/form_config.json`，新增 `unlock_card_1x2`。
- 卡片内容：CLOESSY 字标、门锁名、状态；局部圆环；当前主页色为底，点击后另一色从左到右斜切扫过。
- 卡片绑定数据新增 `homeOnA`，由 `CardSnapshot` / `CardUpdater` / `UnlockCardAbility` 同步。
- 卡片仍通过 `postCardAction(call)` 调用 `CardUnlockAbility`，带 `method: unlockCard`、`cardToken`。

## 4. 系统实况窗

代码：`services/LiveViewService.ets`，使用 `@kit.LiveViewKit` 的 `liveViewManager`。

- 开锁开始 `startLiveView`，阶段 `updateLiveView`，完成 `stopLiveView`；
- 页面、卡片后台、智慧生活入口均接入；
- 失败/无权限/无实况窗权益时静默降级，不阻塞开门。

前置条件：

1. 在 AppGallery Connect 为应用开通 Live View Kit 权益；
2. 重新下载 profile，确认包含实况窗能力；
3. 设备「设置 > 通知与状态栏 > 实况窗」允许 Cloessy；
4. `event` 目前为 `UNLOCK`，正式上架时按 AGC 场景配置调整。

测试签名包一般没有该权益，实况窗不会显示，这是预期行为。

## 5. 华为智慧生活

### 快捷方式（优先验证）

`resources/base/profile/shortcuts_config.json` 定义 `cloessy_unlock`，目标是 `SmartLifeAbility`，参数：

```json
{ "action": "unlock", "source": "smartlife", "sceneKey": "cloessy-smartlife" }
```

`EntryAbility` 的 metadata `ohos.ability.shortcuts` 引用该 profile。安装后长按桌面图标应出现「开门」。

### 应用服务

`CloessyAppService`（`AppServiceExtensionAbility`）接收 `action=unlock`，转发到 `SmartLifeAbility`；`SmartLifeAbility` 无界面，调用 `SmartLifeService` 完成开锁。

智慧生活配置路径：**智慧生活 > 场景 > 添加动作 > 应用服务 > Cloessy > 开门**。入口是否展示取决于 HarmonyOS / 智慧生活版本、应用上架状态和华为场景平台配置；如果看不到，请先用快捷方式验证。

### 安全说明

`SmartLifeAbility` 是 exported，且没有卡片 token，只校验 `source=smartlife` / `action=unlock`。正式发布前应结合签名校验、上架白名单或自定义权限收紧。

## 6. 代码修改点

- `EntryAbility` 改为加载 `pages/CloessyHome`，隐藏系统栏。
- `AppModel` 增加 `homeOnA` 与 `toggleHomeColor()`；`CardSnapshot` 增加同名字段。
- `CardUpdater` / `UnlockCardAbility` 同步 `homeOnA`。
- 新增 `SmartLifeAbility`、`CloessyAppService`、`SmartLifeService`。
- 新增 `shortcuts_config.json`、`1*2` 表单。
- 应用名改为 Cloessy（AppScope 与 module string）。
- 启动窗口背景改为 `#171D29`。

## 7. 仍需真机验证

- 长按登录/设置的命中与冲突；
- 上滑跟手、斜切覆盖、spring 回弹的实际观感；
- 卡片 1×2 在桌面上的尺寸、文字是否被系统裁切；
- 实况窗在具备 AGC 权益的正式 profile 下能否展示；
- 智慧生活能否发现「应用服务」；
- 无界面入口能否在后台完成 BLE 开门。
