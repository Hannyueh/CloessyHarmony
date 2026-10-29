import { curves } from '@kit.ArkUI';
import { DoorLockInfo } from '../../model/Models';
import { CloessyColors } from './Theme';

@Component
export struct SettingsSheet {
  @Prop username: string = '';
  @Prop locks: DoorLockInfo[] = [];
  @Prop currentLockNo: string = '';
  @Prop autoUnlockOnOpen: boolean = false;
  @Prop dark: boolean = false;
  private closing: boolean = false;
  @State contentH: number = 0;
  @State viewportH: number = 0;
  @State scrollY: number = 0;
  @State pull: number = 0;
  private startScroll: number = 0;
  private startPull: number = 0;
  onAutoUnlockChange: (value: boolean) => void = () => {
  };
  onSelectLock: (lock: DoorLockInfo) => void = () => {
  };
  onSupport: () => void = () => {
  };
  onEditAccount: () => void = () => {
  };
  onClose: () => void = () => {
  };

  private closeAnimated(): void {
    if (this.closing) { return; }
    this.closing = true;
    const target = (this.viewportH > 0 ? this.viewportH : 800) + 220;
    animateTo({ duration: 320, curve: Curve.FastOutSlowIn }, () => {
      this.pull = target;
    });
    setTimeout(() => {
      this.onClose();
    }, 330);
  }
  private bg(): string {
    return this.dark ? CloessyColors.A : CloessyColors.B;
  }

  private fg(): string {
    return this.dark ? CloessyColors.B : CloessyColors.A;
  }

  private dim(): string {
    return this.dark ? '#99E9E4DA' : '#66171D29';
  }

  private line(): string {
    return this.dark ? '#33E9E4DA' : '#1F171D29';
  }

  @Builder
  sectionLabel(text: string) {
    Text(text)
      .fontSize(8)
      .fontColor(this.dim())
      .letterSpacing(3)
      .width('100%')
      .margin({ top: 20, bottom: 2 })
  }

  @Builder
  row(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12.5)
        .fontColor(this.dim())
      Blank()
      Text(value)
        .fontSize(12)
        .fontColor(this.fg())
    }
    .width('100%')
    .height(44)
    .border({ width: { bottom: 1 }, color: this.line() })
  }

  @Builder
  developer(role: string, name: string, email: string) {
    Column({ space: 3 }) {
      Text(role)
        .fontSize(8)
        .fontColor(this.dim())
        .letterSpacing(2.4)
      Text(name)
        .fontSize(13)
        .fontColor(this.fg())
      Text(email)
        .fontSize(10)
        .fontColor(this.dim())
        .letterSpacing(0.2)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: this.line() })
  }
  @Builder
  instruction(index: string, text: string) {
    Row({ space: 10 }) {
      Text(index)
        .fontSize(9)
        .fontColor(this.dim())
        .width(20)
      Text(text)
        .fontSize(11)
        .fontColor(this.fg())
        .opacity(0.72)
        .lineHeight(17)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 4, bottom: 4 })
  }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          Row() {
            Text('CLOESSY')
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.dim())
              .letterSpacing(3.5)
              .layoutWeight(1)
            Text('×')
              .fontSize(24)
              .fontColor(this.dim())
              .onClick(() => {
                this.closeAnimated();
              })
          }
          .width('100%')

          Text('设置')
            .fontSize(26)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.fg())
            .letterSpacing(1)
            .width('100%')
            .margin({ top: 18 })
          Text('ACCOUNT · LOCKS · DEVELOPER')
            .fontSize(8)
            .fontColor(this.dim())
            .letterSpacing(2.2)
            .width('100%')
            .margin({ top: 6 })

          Row() {
            Text('账号')
              .fontSize(8)
              .fontColor(this.dim())
              .letterSpacing(3)
              .layoutWeight(1)
            Text('编辑')
              .fontSize(10)
              .fontColor(this.fg())
              .letterSpacing(1)
              .onClick(() => {
                this.onEditAccount();
              })
          }
          .width('100%')
          .height(34)
          .margin({ top: 18, bottom: 2 })

          this.row('手机号', this.username.length > 0 ? this.username : '未登录')
          this.row('密码', '••••••••')
          this.sectionLabel('门锁')
          ForEach(this.locks, (lock: DoorLockInfo) => {
            Row({ space: 12 }) {
              Stack() {
                if (lock.lockNo === this.currentLockNo) {
                  Rect()
                    .width(8)
                    .height(8)
                    .fill(this.fg())
                } else {
                  Rect()
                    .width(8)
                    .height(8)
                    .fill('#00000000')
                    .stroke(this.dim())
                    .strokeWidth(1)
                }
              }
              .width(10)
              .height(10)

              Text(lock.label.length > 0 ? lock.label : lock.lockNo)
                .fontSize(13.5)
                .fontColor(this.fg())
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(lock.lockNo === this.currentLockNo ? '当前' : '已授权')
                .fontSize(9)
                .fontColor(this.dim())
            }
            .width('100%')
            .height(50)
            .border({ width: { bottom: 1 }, color: this.line() })
            .onClick(() => {
              this.onSelectLock(lock);
            })
          }, (lock: DoorLockInfo) => lock.lockNo)

          Row() {
            Column({ space: 2 }) {
              Text('打开软件自动开门')
                .fontSize(13)
                .fontColor(this.fg())
              Text('启动并恢复登录后自动执行开锁')
                .fontSize(9)
                .fontColor(this.dim())
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.autoUnlockOnOpen })
              .selectedColor(this.fg())
              .switchPointColor(this.bg())
              .onChange((value: boolean) => {
                this.onAutoUnlockChange(value);
              })
          }
          .width('100%')
          .height(56)
          .border({ width: { bottom: 1 }, color: this.line() })

          this.sectionLabel('使用说明')
          Column({ space: 3 }) {
            this.instruction('01', '在主页向上滑动开始开门，开锁过程中向下滑动可取消。')
            this.instruction('02', '长按主页空白处进入设置；在设置中向下拉过头可关闭。')
            this.instruction('03', '开启「打开软件自动开门」后，冷启动或从后台回到软件都会自动开锁。')
            this.instruction('04', '桌面长按 Cloessy 图标，可使用快捷开门。')
            this.instruction('05', '首次使用请长按屏幕登录云莓账号，账号仅保存在本机。')
          }
          .width('100%')
          .padding({ top: 4, bottom: 8 })
          this.sectionLabel('开发者')
          this.developer('App 开发', '寒悦Hannyueh', 'Hannyueh@163.com')
          this.developer('逆向工程', 'PhoenixTree', 'phoenixtree_zh@163.com')
          this.row('版本', '0.1.0')

          Row({ space: 12 }) {
            Row() {
              Text('▦')
                .fontSize(18)
                .fontColor(this.fg())
              Text('支持开发者')
                .fontSize(12.5)
                .fontColor(this.fg())
                .margin({ left: 10 })
            }
            Blank()
            Text('›')
              .fontSize(18)
              .fontColor(this.dim())
          }
          .width('100%')
          .height(48)
          .onClick(() => {
            this.onSupport();
          })

          Blank().height(36)
        }
        .width('100%')
        .padding({ left: 26, right: 26, top: 22 })
        .alignItems(HorizontalAlign.Start)
        .height(1220)
        .translate({ y: this.scrollY })
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.contentH = newArea.height as number;
        })
      }
      .width('100%')
      .height('100%')
      .clip(true)
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.viewportH = newArea.height as number;
      })
      .gesture(
        PanGesture({ direction: PanDirection.Vertical, distance: 2 })
          .onActionStart(() => {
            this.startScroll = this.scrollY;
            this.startPull = this.pull;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (this.closing) { return; }
            const next = this.startScroll + event.offsetY;
            if (next >= 0) {
              this.scrollY = 0;
              this.pull = Math.min(110, next * 0.45);
            } else {
              this.scrollY = Math.max(Math.min(0, this.viewportH - this.contentH), next);
              this.pull = 0;
            }
          })
          .onActionEnd((event: GestureEvent) => {
            if (this.closing) { return; }
            if (this.pull > 64) {
              this.closeAnimated();
            } else {
              animateTo({ duration: 420, curve: curves.springMotion(0.55, 0.85) }, () => { this.pull = 0; });
              const velocity = event.velocityY;
              if (Math.abs(velocity) > 180 && this.contentH > this.viewportH) {
                const min = this.viewportH - this.contentH;
                const target = Math.max(min, Math.min(0, this.scrollY + velocity * 0.22));
                animateTo({ duration: 520, curve: Curve.EaseOut }, () => { this.scrollY = target; });
              }
            }
          })
      )
    }
    .translate({ y: this.pull })
    .scale({ x: 1, y: 1 + this.pull / 5000 })
    .width('100%')
    .height('75%')
    .backgroundColor(this.bg())
    .borderRadius({ topLeft: 28, topRight: 28 })
    .clip(true)
  }
}
