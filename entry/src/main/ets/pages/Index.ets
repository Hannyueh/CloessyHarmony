import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppModel } from '../services/AppModel';
import { ensureBluetoothPermission } from '../services/Permission';
import { DoorLockInfo, SchoolInfo, StageUpdate, UnlockKind, UnlockStage } from '../model/Models';
import { LoginPanel } from '../components/LoginPanel';
import { UnlockPanel } from '../components/UnlockPanel';
import { UnlockSheet } from '../components/UnlockSheet';
import { LockPickerSheet } from '../components/LockPickerSheet';
import { SettingsPanel } from '../components/SettingsPanel';
import { Backdrop, BrandBadge, Palette } from '../components/Visual';

/** A card launch consumed in this process must not fire again after a page rebuild. */
let consumedLaunchTick: number = 0;

@Entry
@Component
struct Index {
  @StorageLink('launchAction') launchAction: string = '';
  @StorageLink('launchTick') @Watch('onLaunchTick') launchTick: number = 0;

  @State phase: number = 0;
  @State bootMessage: string = '正在恢复登录状态';
  @State currentTab: number = 0;

  @State username: string = '';
  @State password: string = '';
  @State remember: boolean = true;
  @State loginBusy: boolean = false;
  @State loginError: string = '';

  @State greeting: string = '你好';
  @State lockLabel: string = '未选择门锁';
  @State schoolName: string = '';
  @State capabilityText: string = '';
  @State aesChip: string = '能力未知';
  @State blockedReason: string = '';
  @State lastStatus: string = '';
  @State lastTime: string = '';
  @State online: boolean = false;

  @State unlocking: boolean = false;
  @State stageIndex: number = 0;
  @State stageTitle: string = '';
  @State stageDetail: string = '';
  @State sheetVisible: boolean = false;
  @State resultKind: number = -1;
  @State resultText: string = '';

  @State pickerVisible: boolean = false;
  @State pickerBusy: boolean = false;
  @State schoolsForPicker: SchoolInfo[] = [];
  @State locksForPicker: DoorLockInfo[] = [];

  private model: AppModel = AppModel.shared;
  private uiContext: common.UIAbilityContext | null = null;
  private pendingUnlock: boolean = false;
  private lastSeenTick: number = 0;

  aboutToAppear(): void {
    this.greeting = Index.greetingFor(new Date().getHours());
    this.uiContext = getContext(this) as common.UIAbilityContext;
    this.lastSeenTick = this.launchTick;
    const unlockingSince = AppStorage.get<number>('cardUnlockingAt') ?? 0;
    if (AppStorage.get<boolean>('appUnlocking') === true
      && (unlockingSince <= 0 || Date.now() - unlockingSince > 120000)) {
      AppStorage.set<boolean>('appUnlocking', false);
    }
    AppStorage.setOrCreate<boolean>('appUnlocking', false);
    const freshLaunch = this.launchTick > 0 && this.launchTick !== consumedLaunchTick;
    this.pendingUnlock = freshLaunch && this.launchAction === 'unlock';
    if (this.pendingUnlock) {
      consumedLaunchTick = this.launchTick;
    }
    this.boot();
  }

  private static greetingFor(hour: number): string {
    if (hour >= 5 && hour < 11) {
      return '早上好';
    }
    if (hour >= 11 && hour < 13) {
      return '中午好';
    }
    if (hour >= 13 && hour < 18) {
      return '下午好';
    }
    if (hour >= 18 && hour < 23) {
      return '晚上好';
    }
    return '夜深了';
  }

  private static kindToNumber(kind: UnlockKind): number {
    if (kind === UnlockKind.ACKNOWLEDGED) {
      return 0;
    }
    if (kind === UnlockKind.KEY_REJECTED) {
      return 1;
    }
    if (kind === UnlockKind.UNSUPPORTED) {
      return 3;
    }
    if (kind === UnlockKind.TRANSPORT_ERROR) {
      return 4;
    }
    if (kind === UnlockKind.CANCELLED) {
      return 5;
    }
    return 2;
  }

  private async boot(): Promise<void> {
    if (this.uiContext === null) {
      return;
    }
    try {
      await this.model.init(this.uiContext);
      this.username = this.model.savedUsername;
      this.remember = this.model.remember;
      this.bootMessage = '正在恢复登录状态';
      const restored = await this.model.restore();
      if (restored) {
        this.applyModel();
        animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
          this.phase = 2;
        });
        this.afterHomeReady();
      } else {
        this.phase = 1;
        this.loginError = this.model.savedUsername.length > 0 ? this.model.lastError : '';
      }
    } catch (error) {
      this.phase = 1;
      this.loginError = (error as Error).message;
    }
  }

  private afterHomeReady(): void {
    if (this.pendingUnlock) {
      this.pendingUnlock = false;
      setTimeout(() => {
        this.startUnlock();
      }, 520);
    }
  }

  onLaunchTick(): void {
    if (this.launchTick === this.lastSeenTick) {
      return;
    }
    this.lastSeenTick = this.launchTick;
    if (this.launchAction !== 'unlock' || this.launchTick === consumedLaunchTick) {
      return;
    }
    consumedLaunchTick = this.launchTick;
    if (this.phase === 2) {
      this.startUnlock();
    } else {
      this.pendingUnlock = true;
    }
  }

  private applyModel(): void {
    const lock = this.model.lock;
    this.lockLabel = lock === null ? '未选择门锁' : (lock.label.length > 0 ? lock.label : lock.lockNo);
    this.schoolName = this.model.school === null ? '' : this.model.school.name;
    this.online = this.model.session !== null && lock !== null;

    if (lock === null) {
      this.aesChip = '能力未知';
      this.capabilityText = '';
      this.blockedReason = '尚未选择门锁';
    } else if (!lock.aesKnown) {
      this.aesChip = '能力未知';
      this.capabilityText = lock.blockedReason;
      this.blockedReason = lock.blockedReason;
    } else if (lock.aesSupport) {
      this.aesChip = 'AES 加密';
      this.capabilityText = '门锁能力已确认 · AES 外层封装';
      this.blockedReason = lock.blockedReason;
    } else {
      this.aesChip = '普通协议';
      this.capabilityText = lock.capabilityStatus === 'OFFICIAL_NULL_AS_PLAIN'
        ? '按官方空值规则使用普通协议' : '门锁能力已确认 · 普通帧';
      this.blockedReason = lock.blockedReason;
    }
    this.lastStatus = this.model.lastStatus;
    this.lastTime = this.model.lastTime;
  }

  private async submitLogin(): Promise<void> {
    if (this.loginBusy) {
      return;
    }
    this.loginBusy = true;
    this.loginError = '';
    try {
      await this.model.login(this.username, this.password, this.remember);
      this.password = '';
      this.applyModel();
      animateTo({ duration: 440, curve: Curve.EaseOut }, () => {
        this.phase = 2;
      });
      if (this.pendingUnlock) {
        this.pendingUnlock = false;
        setTimeout(() => {
          this.startUnlock();
        }, 560);
      }
    } catch (error) {
      this.loginError = (error as Error).message;
    } finally {
      this.loginBusy = false;
    }
  }

  private setStage(index: number, title: string, detail: string): void {
    this.stageIndex = index;
    this.stageTitle = title;
    this.stageDetail = detail;
  }

  private consumeStage(update: StageUpdate): void {
    if (update.stage === UnlockStage.PREPARING) {
      this.setStage(this.stageIndex < 1 ? 1 : this.stageIndex, update.text, update.detail);
    } else if (update.stage === UnlockStage.CONNECTING) {
      this.setStage(2, update.text, update.detail);
    } else if (update.stage === UnlockStage.DISCOVERING || update.stage === UnlockStage.SUBSCRIBING) {
      this.setStage(3, update.text, update.detail);
    } else if (update.stage === UnlockStage.SENDING) {
      this.setStage(4, update.text, update.detail);
    } else if (update.stage === UnlockStage.WAITING) {
      this.setStage(5, update.text, update.detail);
    }
  }

  private async startUnlock(): Promise<void> {
    if (this.unlocking || AppStorage.get<boolean>('appUnlocking') === true) {
      if (!this.unlocking) {
        promptAction.showToast({ message: '正在开门，请稍候', duration: 1600 });
      }
      return;
    }
    if (this.model.lock === null) {
      this.openPicker();
      promptAction.showToast({ message: '请先选择寝室门锁', duration: 2000 });
      return;
    }
    if (this.uiContext === null) {
      return;
    }
    this.pickerVisible = false;
    this.resultKind = -1;
    this.resultText = '';
    this.unlocking = true;
    this.sheetVisible = true;
    AppStorage.setOrCreate<boolean>('appUnlocking', true);
    this.setStage(0, '准备开门', '正在检查门锁与蓝牙状态');

    const granted = await ensureBluetoothPermission(this.uiContext);
    if (!granted) {
      this.unlocking = false;
      AppStorage.setOrCreate<boolean>('appUnlocking', false);
      this.resultKind = 4;
      this.resultText = '未获得蓝牙权限。请在系统设置中允许「云莓开门」使用蓝牙后重试。';
      return;
    }

    try {
      this.setStage(1, '正在刷新门锁凭据', '向学校服务器重新获取当前门锁密钥');
      await this.model.refreshForUnlock(true);
      this.applyModel();
      const outcome = await this.model.unlockWithRetry((update: StageUpdate) => {
        this.consumeStage(update);
      });
      await this.model.recordOutcome(outcome);
      this.lastStatus = this.model.lastStatus;
      this.lastTime = this.model.lastTime;
      this.stageIndex = 6;
      this.resultKind = Index.kindToNumber(outcome.kind);
      this.resultText = outcome.message;
    } catch (error) {
      this.resultKind = 2;
      this.resultText = (error as Error).message;
    } finally {
      this.unlocking = false;
      AppStorage.setOrCreate<boolean>('appUnlocking', false);
      if (this.resultKind < 0) {
        this.resultKind = 2;
        this.resultText = '开锁流程结束，但未收到可验证的门锁返回，请确认门锁实际状态。';
      }
    }
  }

  private closeSheet(): void {
    if (this.unlocking) {
      return;
    }
    this.sheetVisible = false;
  }

  private openPicker(): void {
    this.schoolsForPicker = this.model.schools.slice(0);
    this.locksForPicker = this.model.locks.slice(0);
    this.pickerVisible = true;
  }

  private async pickLock(lock: DoorLockInfo): Promise<void> {
    await this.model.selectLock(lock);
    this.applyModel();
    this.pickerVisible = false;
    promptAction.showToast({ message: '已选择 ' + this.lockLabel, duration: 1800 });
  }

  private async pickSchool(school: SchoolInfo): Promise<void> {
    if (this.pickerBusy) {
      return;
    }
    this.pickerBusy = true;
    try {
      await this.model.switchSchool(school);
      this.applyModel();
      this.schoolsForPicker = this.model.schools.slice(0);
      this.locksForPicker = this.model.locks.slice(0);
    } catch (error) {
      promptAction.showToast({ message: (error as Error).message, duration: 2600 });
    } finally {
      this.pickerBusy = false;
    }
  }

  private async refreshAll(): Promise<void> {
    if (this.pickerBusy) {
      return;
    }
    this.pickerBusy = true;
    try {
      await this.model.refreshAll();
      this.applyModel();
      this.schoolsForPicker = this.model.schools.slice(0);
      this.locksForPicker = this.model.locks.slice(0);
      promptAction.showToast({ message: '门锁列表已刷新', duration: 1600 });
    } catch (error) {
      promptAction.showToast({ message: (error as Error).message, duration: 2600 });
    } finally {
      this.pickerBusy = false;
    }
  }

  private async logout(): Promise<void> {
    await this.model.logout();
    this.username = '';
    this.password = '';
    this.loginError = '';
    this.applyModel();
    this.currentTab = 0;
    animateTo({ duration: 360, curve: Curve.EaseOut }, () => {
      this.phase = 1;
    });
  }

  @Builder
  tabBarItem(index: number, label: string, activeIcon: Resource, inactiveIcon: Resource) {
    Column({ space: 3 }) {
      Image(this.currentTab === index ? activeIcon : inactiveIcon)
        .width(22)
        .height(22)
        .objectFit(ImageFit.Contain)
      Text(label)
        .fontSize(10)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentTab === index ? Palette.TEXT : Palette.TEXT_DIM)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  bootView() {
    Column({ space: 18 }) {
      BrandBadge({ badgeSize: 86 })
      Text('云莓开门')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Palette.TEXT)
        .letterSpacing(1.4)
      Row({ space: 8 }) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color(Palette.MINT)
        Text(this.bootMessage)
          .fontSize(12)
          .fontColor(Palette.TEXT_MUTED)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      Backdrop()

      if (this.phase === 0) {
        this.bootView()
      } else if (this.phase === 1) {
        Column() {
          LoginPanel({
            username: $username,
            password: $password,
            remember: $remember,
            busy: this.loginBusy,
            errorText: this.loginError,
            onSubmit: () => {
              this.submitLogin();
            }
          })
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY)
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
          TabContent() {
            UnlockPanel({
              username: this.username,
              greeting: this.greeting,
              schoolName: this.schoolName,
              lockLabel: this.lockLabel,
              capabilityText: this.capabilityText,
              aesChip: this.aesChip,
              blockedReason: this.blockedReason,
              lastStatus: this.lastStatus,
              lastTime: this.lastTime,
              online: this.online,
              unlocking: this.unlocking,
              stageTitle: this.stageTitle,
              onUnlock: () => {
                this.startUnlock();
              },
              onPick: () => {
                this.openPicker();
              },
              onRefresh: () => {
                this.refreshAll();
              }
            })
          }
          .tabBar(this.tabBarItem(0, '开门', $r('app.media.ic_lock_open_emerald'),
            $r('app.media.ic_lock_open_gray')))

          TabContent() {
            SettingsPanel({
              username: this.username,
              schoolName: this.schoolName,
              lockLabel: this.lockLabel,
              capabilityText: this.aesChip,
              onPick: () => {
                this.openPicker();
              },
              onRefresh: () => {
                this.refreshAll();
              },
              onLogout: () => {
                this.logout();
              }
            })
          }
          .tabBar(this.tabBarItem(1, '我的', $r('app.media.ic_person_emerald'),
            $r('app.media.ic_person_gray')))
        }
        .barHeight(66)
        .barBackgroundColor('#D9FFFFFF')
        .barBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
        .barOverlap(true)
        .divider(null)
        .scrollable(false)
        .animationDuration(260)
        .onChange((index: number) => {
          this.currentTab = index;
        })
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY)
      }

      if (this.sheetVisible) {
        UnlockSheet({
          running: this.unlocking,
          stageIndex: this.stageIndex,
          stageTitle: this.stageTitle,
          stageDetail: this.stageDetail,
          resultKind: this.resultKind,
          resultText: this.resultText,
          onClose: () => {
            this.closeSheet();
          },
          onRetry: () => {
            this.closeSheet();
            setTimeout(() => {
              this.startUnlock();
            }, 280);
          }
        })
      }

      if (this.pickerVisible) {
        LockPickerSheet({
          schools: this.schoolsForPicker,
          locks: this.locksForPicker,
          currentSchoolNo: this.model.school === null ? '' : this.model.school.schoolNo,
          currentLockNo: this.model.lock === null ? '' : this.model.lock.lockNo,
          busy: this.pickerBusy,
          onPickLock: (lock: DoorLockInfo) => {
            this.pickLock(lock);
          },
          onPickSchool: (school: SchoolInfo) => {
            this.pickSchool(school);
          },
          onRefresh: () => {
            this.refreshAll();
          },
          onClose: () => {
            this.pickerVisible = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Palette.BG)
  }
}
