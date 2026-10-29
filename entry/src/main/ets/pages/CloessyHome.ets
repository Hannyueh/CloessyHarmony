import { common } from '@kit.AbilityKit';
import { curves, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { AppModel } from '../services/AppModel';
import { STORE_NAME } from '../services/Prefs';
import { ensureBluetoothPermission } from '../services/Permission';
import { DoorLockInfo, StageUpdate, UnlockKind, UnlockStage } from '../model/Models';
import { ArcBackdrop } from '../components/cloessy/ArcBackdrop';
import { LoginSheet } from '../components/cloessy/LoginSheet';
import { SettingsSheet } from '../components/cloessy/SettingsSheet';
import { SupportDialog } from '../components/cloessy/SupportDialog';
import { CloessyColors } from '../components/cloessy/Theme';
import { LiveViewService } from '../services/LiveViewService';

@Entry
@Component
struct CloessyHome {
  @StorageLink('launchAction') launchAction: string = '';
  @StorageLink('launchTick') @Watch('onLaunchTick') launchTick: number = 0;
  @StorageLink('appForegroundTick') @Watch('onAppForeground') foregroundTick: number = 0;
  private lastForegroundAuto: number = 0;
  @State phase: string = 'boot';
  @State splashOpacity: number = 1;
  @State splashOnA: boolean = true;
  @State arcOpacity: number = 1;
  @State autoUnlockOnOpen: boolean = false;
  @State homeOnA: boolean = true;
  @State fill: number = 0;
  @State screenW: number = 390;
  @State screenH: number = 844;
  @State stageText: string = '正在准备开门';
  @State floatShift: number = 0;
  @State centerOpacity: number = 1;
  @State successWhite: number = 0;
  private successFadeTimer: number = -1;
  private floatTimer: number = -1;
  private cancelRequested: boolean = false;

  @State username: string = '';
  @State password: string = '';
  @State loginBusy: boolean = false;
  @State loginError: string = '';
  @State settingsVisible: boolean = false;
  @State supportVisible: boolean = false;
  @State editVisible: boolean = false;
  @State locks: DoorLockInfo[] = [];
  @State currentLockNo: string = '';
  @State statusLine: string = '';

  private model: AppModel = AppModel.shared;
  private uiContext: common.UIAbilityContext | null = null;
  private dragOffset: number = 0;
  private unlockRunning: boolean = false;
  private pendingSmartLife: boolean = false;
  private consumedTick: number = 0;
  private lastSeenTick: number = 0;
  private creepToken: number = 0;

  aboutToAppear(): void {
    this.uiContext = getContext(this) as common.UIAbilityContext;
    this.lastSeenTick = this.launchTick;
    try {
      const store = preferences.getPreferencesSync(this.uiContext, { name: STORE_NAME });
      const saved = store.getSync('home_on_a', true);
      this.splashOnA = true;
      this.homeOnA = true;
    } catch (error) {
    }
    if (this.launchAction === 'smartlifeUnlock' && this.launchTick !== this.consumedTick) {
      this.consumedTick = this.launchTick;
      this.pendingSmartLife = true;
    }
    try {
      const info = display.getDefaultDisplaySync();
      this.screenW = px2vp(info.width);
      this.screenH = px2vp(info.height);
    } catch (error) {
    }
    this.boot();
  }

  onLaunchTick(): void {
    if (this.launchTick === this.lastSeenTick) {
      return;
    }
    this.lastSeenTick = this.launchTick;
    if (this.launchAction === 'smartlifeUnlock' && this.launchTick !== this.consumedTick) {
      this.consumedTick = this.launchTick;
      this.pendingSmartLife = true;
      hilog.info(0x1201, 'CloessyHome', 'smart life launch consumed tick=%{public}d', this.launchTick);
      this.trySmartLife();
    }
  }

  private trySmartLife(): void {
    if (!this.pendingSmartLife) {
      return;
    }
    hilog.info(0x1201, 'CloessyHome', 'smart life pending: phase=%{public}s logged=%{public}s',
      this.phase, this.model.isLoggedIn ? 'true' : 'false');
    if (this.phase !== 'home' || !this.model.isLoggedIn || this.unlockRunning) {
      return;
    }
    this.pendingSmartLife = false;
    this.settingsVisible = false;
    this.startUnlock();
  }

  private async boot(): Promise<void> {
    if (this.uiContext === null) {
      this.phase = 'home';
      return;
    }
    try {
      await this.model.init(this.uiContext);
      this.splashOnA = true;
      this.homeOnA = true;
      this.autoUnlockOnOpen = this.model.autoUnlockOnOpen;
      this.username = this.model.savedUsername;
      this.applyModel();
      this.phase = 'home';
      animateTo({ duration: 450, curve: Curve.EaseOut }, () => {
        this.splashOpacity = 0;
      });
      if (this.model.savedUsername.length > 0) {
        const restored = await this.model.restore();
        if (!restored) {
          this.loginError = this.model.lastError;
        }
      }
      this.applyModel();
    } catch (error) {
      this.loginError = (error as Error).message;
      this.phase = 'home';
      animateTo({ duration: 450, curve: Curve.EaseOut }, () => {
        this.splashOpacity = 0;
      });
    }
    this.trySmartLife();
    if (this.autoUnlockOnOpen && this.model.isLoggedIn && !this.pendingSmartLife) {
      setTimeout(() => {
        if (this.phase === 'home' && !this.unlockRunning) {
          this.startUnlock();
        }
      }, 700);
    }
  }

  private onAppForeground(): void {
    if (!this.autoUnlockOnOpen || !this.model.isLoggedIn || this.phase !== 'home' ||
      this.unlockRunning || this.settingsVisible || this.pendingSmartLife) {
      return;
    }
    const now = Date.now();
    if (now - this.lastForegroundAuto < 1200) {
      return;
    }
    this.lastForegroundAuto = now;
    setTimeout(() => {
      if (this.autoUnlockOnOpen && this.model.isLoggedIn && this.phase === 'home' && !this.unlockRunning) {
        this.startUnlock();
      }
    }, 500);
  }
  private applyModel(): void {
    this.homeOnA = true;
    this.autoUnlockOnOpen = this.model.autoUnlockOnOpen;
    this.locks = this.model.locks.slice(0);
    this.currentLockNo = this.model.lock === null ? '' : this.model.lock.lockNo;
    this.username = this.model.savedUsername;
  }

  private effectiveOnA(): boolean {
    if (this.phase === 'boot') {
      return this.splashOnA;
    }
    return this.homeOnA;
  }

  private baseColor(): string {
    return this.effectiveOnA() ? CloessyColors.A : CloessyColors.B;
  }

  private textColor(): string {
    return this.effectiveOnA() ? CloessyColors.B : CloessyColors.A;
  }

  private promptText(): string {
    if (this.phase === 'boot') {
      return '';
    }
    return this.model.isLoggedIn ? '上滑屏幕开门' : '长按屏幕登录账号';
  }

  private centerTextColor(): string {
    const baseA = this.effectiveOnA();
    if (this.fill >= 0.5) {
      return baseA ? CloessyColors.A : CloessyColors.B;
    }
    return baseA ? CloessyColors.B : CloessyColors.A;
  }

  private fillPath(): string {
    const slope = this.screenW * 0.1763;
    return `M 0 ${slope * 1.5} L ${this.screenW * 3} ${-slope * 1.5} ` +
      `L ${this.screenW * 3} ${this.screenH * 3} L 0 ${this.screenH * 3} Z`;
  }

  private homeSubText(): string {
    if (this.model.lock === null) {
      return '未选择门锁';
    }
    const label = this.model.lock.label.length > 0 ? this.model.lock.label : this.model.lock.lockNo;
    const status = this.model.lastStatus.length > 0 ? this.model.lastStatus : '准备就绪';
    return label + '  ·  ' + status;
  }

  private animateFill(value: number): void {
    animateTo({
      duration: 680,
      curve: curves.springMotion(0.55, 0.85)
    }, () => {
      this.fill = value;
    });
  }

  private animateFillCreep(value: number): void {
    animateTo({
      duration: 10000,
      curve: Curve.Linear
    }, () => {
      this.fill = Math.min(value, 0.96);
    });
  }

  private onLongPress(): void {
    if (this.phase !== 'home' || this.unlockRunning) {
      return;
    }
    if (this.model.isLoggedIn) {
      this.settingsVisible = true;
    } else {
      this.loginError = '';
      this.phase = 'login';
    }
  }

  private onPanStart(): void {
    if (this.phase !== 'home' || !this.model.isLoggedIn || this.unlockRunning) {
      return;
    }
    this.dragOffset = 0;
  }

  private onPanUpdate(event: GestureEvent): void {
    if (this.phase !== 'home' || !this.model.isLoggedIn || this.unlockRunning) {
      return;
    }
    this.dragOffset = event.offsetY;
  }

  private onPanEnd(): void {
    if (this.phase !== 'home' || !this.model.isLoggedIn || this.unlockRunning) {
      return;
    }
    const shouldUnlock = this.dragOffset < -60;
    this.dragOffset = 0;
    if (shouldUnlock) {
      this.startUnlock();
    }
  }

  private async submitLogin(): Promise<void> {
    if (this.loginBusy) {
      return;
    }
    this.loginBusy = true;
    this.loginError = '';
    try {
      await this.model.login(this.username, this.password, true);
      this.password = '';
      this.applyModel();
      this.phase = 'home';
      this.statusLine = '';
      this.trySmartLife();
    } catch (error) {
      this.loginError = (error as Error).message;
    } finally {
      this.loginBusy = false;
    }
  }

  private openEditAccount(): void {
    this.username = this.model.savedUsername;
    this.password = '';
    this.loginError = '';
    this.editVisible = true;
  }

  private async submitAccountEdit(): Promise<void> {
    if (this.loginBusy) {
      return;
    }
    this.loginBusy = true;
    this.loginError = '';
    try {
      await this.model.login(this.username, this.password, true);
      this.password = '';
      this.applyModel();
      this.editVisible = false;
    } catch (error) {
      this.loginError = (error as Error).message;
    } finally {
      this.loginBusy = false;
    }
  }

  private async selectLock(lock: DoorLockInfo): Promise<void> {
    try {
      await this.model.selectLock(lock);
      this.applyModel();
      this.statusLine = '已选择 ' + (lock.label.length > 0 ? lock.label : lock.lockNo);
    } catch (error) {
      this.statusLine = (error as Error).message;
    }
  }

  private stageProgress(update: StageUpdate): number {
    if (update.stage === UnlockStage.PREPARING || update.stage === UnlockStage.REFRESHING) {
      return 0.2;
    }
    if (update.stage === UnlockStage.CONNECTING) {
      return 0.4;
    }
    if (update.stage === UnlockStage.DISCOVERING || update.stage === UnlockStage.SUBSCRIBING) {
      return 0.6;
    }
    if (update.stage === UnlockStage.SENDING) {
      return 0.8;
    }
    if (update.stage === UnlockStage.WAITING) {
      return 0.8;
    }
    return 0.5;
  }

  private consumeStage(update: StageUpdate): void {
    if (this.cancelRequested || this.phase !== 'unlocking') { return; }
    const progress = this.stageProgress(update);
    this.animateFill(progress);
    const token = ++this.creepToken;
    setTimeout(() => {
      if (token === this.creepToken && this.phase === 'unlocking' && this.fill < progress + 0.02) {
        this.animateFillCreep(progress + 0.02);
      }
    }, 850);
    LiveViewService.update(progress * 100, update.text).catch(() => {
    });
    this.model.setCardProgress(update.text, Math.max(1, Math.round(progress * 5)), true).catch(() => {
    });
  }

  private startFloat(): void {
    if (this.floatTimer >= 0) { return; }
    this.floatTimer = setInterval(() => {
      animateTo({ duration: 1400, curve: Curve.EaseInOut }, () => {
        this.floatShift = this.floatShift === 0 ? 1 : 0;
      });
    }, 1500);
  }

  private stopFloat(): void {
    if (this.floatTimer >= 0) { clearInterval(this.floatTimer); this.floatTimer = -1; }
    this.floatShift = 0;
  }

  private cancelUnlockFlow(): void {
    if (this.cancelRequested) { return; }
    this.cancelRequested = true;
    this.creepToken++;
    this.stopFloat();
    this.unlockRunning = false;
    this.model.cancelUnlock();
    AppStorage.setOrCreate<boolean>('appUnlocking', false);
    this.phase = 'cancelling';
    animateTo({ duration: 280, curve: Curve.EaseOut }, () => { this.centerOpacity = 0; });
    this.animateFill(0);
    this.statusLine = '';
    LiveViewService.finish(false, '已取消').catch(() => { });
    setTimeout(() => {
      this.model.setCardProgress('已取消开门', 0, false).catch(() => { });
      this.phase = 'home';
      this.fill = 0;
      this.centerOpacity = 0;
      animateTo({ duration: 320, curve: Curve.EaseOut }, () => { this.centerOpacity = 1; });
    }, 700);
  }
  private async startUnlock(): Promise<void> {
    if (this.phase !== 'home' || this.unlockRunning) {
      return;
    }
    if (!this.model.isLoggedIn) {
      this.phase = 'login';
      return;
    }
    if (this.uiContext === null) {
      return;
    }
    if (this.model.lock === null) {
      this.settingsVisible = true;
      return;
    }
    AppStorage.setOrCreate<boolean>('appUnlocking', false);
    this.cancelRequested = false;
    this.centerOpacity = 1;
    this.unlockRunning = true;
    this.statusLine = '';
    this.stageText = '正在准备开门';
    AppStorage.setOrCreate<boolean>('appUnlocking', true);
    AppStorage.setOrCreate<number>('cardUnlockingAt', Date.now());
    this.phase = 'unlocking';
    this.animateFill(0.08);
    LiveViewService.start('Cloessy 开门', '正在准备').catch(() => {
    });
    this.model.setCardProgress('正在准备开门', 1, true).catch(() => {
    });

    const granted = await ensureBluetoothPermission(this.uiContext);
    if (!granted) {
      this.failUnlock('未获得蓝牙权限，请在系统设置中允许 Cloessy 使用蓝牙');
      return;
    }

    try {
      this.animateFill(0.18);
      LiveViewService.update(18, '正在刷新门锁凭据').catch(() => {
      });
      await this.model.refreshForUnlock(true);
      if (this.cancelRequested) { return; }
      this.applyModel();
      this.consumeStage(new StageUpdate(UnlockStage.PREPARING, '正在连接门锁', '准备开门'));
      const outcome = await this.model.unlockWithRetry((update: StageUpdate) => {
        this.consumeStage(update);
      });
      if (this.cancelRequested) { return; }
      await this.model.recordOutcome(outcome);
      if (outcome.isSuccess) {
        this.creepToken++;
        this.animateFill(1);
        setTimeout(() => {
          this.fill = 0;
          this.phase = 'success';
          this.successWhite = 1;
          LiveViewService.finish(true, '已开门').catch(() => {
          });
          setTimeout(() => {
            const startedAt = Date.now();
            this.successFadeTimer = setInterval(() => {
              const t = Math.min(1, (Date.now() - startedAt) / 900);
              const eased = t * t * (3 - 2 * t);
              this.successWhite = 1 - eased;
              if (t >= 1) {
                clearInterval(this.successFadeTimer);
                this.successFadeTimer = -1;
                this.finishSuccess();
              }
            }, 16);
          }, 500);
        }, 900);
      } else {
        this.failUnlock(outcome.message);
        LiveViewService.finish(false, '开门失败').catch(() => {
        });
      }
    } catch (error) {
      if (this.cancelRequested) { return; }
      this.failUnlock((error as Error).message);
      LiveViewService.finish(false, '开门失败').catch(() => {
      });
    } finally {
      AppStorage.setOrCreate<boolean>('appUnlocking', false);
      this.unlockRunning = false;
    }
  }

  private failUnlock(message: string): void {
    if (this.cancelRequested) { return; }
    this.creepToken++;
    this.statusLine = message;
    this.phase = 'home';
    this.animateFill(0);
    LiveViewService.finish(false, '开门失败').catch(() => {
    });
    this.model.setCardProgress(message, -1, false).catch(() => {
    });
  }

  private async finishSuccess(): Promise<void> {
    try {
      await this.model.toggleHomeColor();
      this.homeOnA = this.model.homeOnA;
      this.applyModel();
    } catch (error) {
    }
    this.fill = 0;
    this.successWhite = 0;
    this.homeOnA = true;
    this.arcOpacity = 0;
    this.phase = 'home';
    this.statusLine = '';
    setTimeout(() => {
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.arcOpacity = 1;
      });
    }, 60);
    this.trySmartLife();
  }

  @Builder
  homeView() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.baseColor())

      if (this.phase !== 'success' && this.phase !== 'boot') {
        Stack() {
          ArcBackdrop({ dark: this.effectiveOnA() })
        }
        .width('100%')
        .height('100%')
        .opacity(this.arcOpacity)
      }

      if (this.phase !== 'boot' && this.fill > 0) {
        Column()
          .width(this.screenW * 2.5)
          .height(this.screenH * 3)
          .backgroundColor(this.effectiveOnA() ? CloessyColors.B : CloessyColors.A)
          .position({ x: -this.screenW * 0.75, y: 0 })
          .rotate({ angle: -10 })
          .translate({ y: this.screenH + 200 - this.fill * (this.screenH + 400) })
      }

      if (this.fill >= 0.985 && (this.phase === 'unlocking' || this.phase === 'success')) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.effectiveOnA() ? CloessyColors.B : CloessyColors.A)
      }

      if (this.phase !== 'boot') {
        Text('CLOESSY')
          .fontSize(9)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor())
          .letterSpacing(3.4)
          .position({ x: 30, y: 30 })
          .opacity(0.72)
      }

      if (this.phase === 'unlocking') {
        Text(this.stageText)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.centerTextColor())
          .letterSpacing(1)
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .padding({ left: 36, right: 36 })
          .width('100%')
          .height('100%')
          .opacity(this.centerOpacity)
      } else if (this.phase === 'home') {
        Text('上滑屏幕开门')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor())
          .letterSpacing(2)
          .width('100%')
          .height('100%')
          .textAlign(TextAlign.Center)
          .opacity(this.centerOpacity)
      } else if (this.phase === 'cancelling') {
        Text('已取消开门')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.centerTextColor())
          .letterSpacing(2)
          .width('100%')
          .height('100%')
          .textAlign(TextAlign.Center)
          .opacity(this.centerOpacity)
      }

      if (this.phase === 'unlocking') {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .gesture(
            PanGesture({ fingers: 1, direction: PanDirection.Down, distance: 2 })
              .onActionUpdate((event: GestureEvent) => {
                if (event.offsetY > 50 && !this.cancelRequested) {
                  this.cancelUnlockFlow();
                }
              })
          )
      }
      if (this.phase === 'success') {
        Column() {
          Text('开锁成功')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(CloessyColors.A)
            .letterSpacing(2)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(CloessyColors.B)
        .opacity(this.successWhite)
        .hitTestBehavior(HitTestMode.None)
      }

      if (this.splashOpacity > 0) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.splashOnA ? CloessyColors.A : CloessyColors.B)
          .opacity(this.splashOpacity)
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        LongPressGesture({ repeat: false, duration: 600 })
          .onAction(() => {
            this.onLongPress();
          }),
        PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 6 })
          .onActionStart(() => {
            this.onPanStart();
          })
          .onActionUpdate((event: GestureEvent) => {
            this.onPanUpdate(event);
          })
          .onActionEnd(() => {
            this.onPanEnd();
          }),
        SwipeGesture({ direction: SwipeDirection.Vertical, speed: 120 })
          .onAction(() => {
            if (this.phase === 'unlocking') {
              this.cancelUnlockFlow();
            }
          })
      )
    )
  }

  build() {
    Stack() {
      this.homeView()

      if (this.phase === 'login') {
        LoginSheet({
          username: $username,
          password: $password,
          busy: this.loginBusy,
          errorText: this.loginError,
          onSubmit: () => {
            this.submitLogin();
          },
          onClose: () => {
            this.phase = 'home';
            this.trySmartLife();
          }
        })
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.translate({ y: '100%' })
              .combine(TransitionEffect.OPACITY)
              .animation({ duration: 380, curve: Curve.FastOutSlowIn }),
            TransitionEffect.OPACITY.animation({ duration: 80, curve: Curve.EaseOut })
          ))
      }

      if (this.settingsVisible) {
        Column() {
          SettingsSheet({
          username: this.username,
          locks: this.locks,
          currentLockNo: this.currentLockNo,
          autoUnlockOnOpen: this.autoUnlockOnOpen,
          dark: !this.homeOnA,
          onAutoUnlockChange: (value: boolean) => {
            this.model.setAutoUnlockOnOpen(value);
            this.autoUnlockOnOpen = value;
          },
          onSelectLock: (lock: DoorLockInfo) => {
            this.selectLock(lock);
          },
          onSupport: () => {
            this.supportVisible = true;
          },
          onEditAccount: () => {
            this.openEditAccount();
          },
          onClose: () => {
            this.settingsVisible = false;
            this.trySmartLife();
          }
        })
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.translate({ y: '100%' })
              .combine(TransitionEffect.OPACITY)
              .animation({ duration: 380, curve: Curve.FastOutSlowIn }),
            TransitionEffect.OPACITY.animation({ duration: 80, curve: Curve.EaseOut })
          ))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }

      if (this.editVisible) {
        LoginSheet({
          username: $username,
          password: $password,
          busy: this.loginBusy,
          errorText: this.loginError,
          titleText: '编辑账号',
          subtitleText: '重新验证账号密码后更新本机凭据',
          submitText: '保存并重新登录',
          passwordPlaceholder: '请输入新密码',
          onSubmit: () => {
            this.submitAccountEdit();
          },
          onClose: () => {
            this.editVisible = false;
          }
        })
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut }))
      }

      if (this.supportVisible) {
        SupportDialog({
          onClose: () => {
            this.supportVisible = false;
          }
        })
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(CloessyColors.A)
  }
}
