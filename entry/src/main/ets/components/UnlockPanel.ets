import { Palette } from './Visual';

@Component
export struct UnlockPanel {
  @Prop username: string = '';
  @Prop greeting: string = '';
  @Prop schoolName: string = '';
  @Prop lockLabel: string = '未选择门锁';
  @Prop capabilityText: string = '';
  @Prop aesChip: string = '';
  @Prop blockedReason: string = '';
  @Prop lastStatus: string = '';
  @Prop lastTime: string = '';
  @Prop online: boolean = false;
  @Prop unlocking: boolean = false;
  @Prop stageTitle: string = '';
  onUnlock: () => void = () => {
  };
  onPick: () => void = () => {
  };
  onRefresh: () => void = () => {
  };

  @State appeared: boolean = false;
  @State pulseScale: number = 1;
  @State pulseAlpha: number = 0.5;
  @State pulseScaleOuter: number = 1;
  @State pulseAlphaOuter: number = 0.28;
  @State arcAngle: number = 0;
  @State pressScale: number = 1;

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({ duration: 560, curve: Curve.EaseOut }, () => {
        this.appeared = true;
      });
    }, 60);
    animateTo({
      duration: 2200,
      curve: Curve.EaseOut,
      iterations: -1
    }, () => {
      this.pulseScale = 1.4;
      this.pulseAlpha = 0;
    });
    setTimeout(() => {
      animateTo({
        duration: 2600,
        curve: Curve.EaseOut,
        iterations: -1
      }, () => {
        this.pulseScaleOuter = 1.62;
        this.pulseAlphaOuter = 0;
      });
    }, 700);
    animateTo({
      duration: 1500,
      curve: Curve.Linear,
      iterations: -1
    }, () => {
      this.arcAngle = 360;
    });
  }

  private pressDown(): void {
    animateTo({ duration: 110, curve: Curve.EaseOut }, () => {
      this.pressScale = 0.94;
    });
  }

  private pressUp(): void {
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.pressScale = 1;
    });
  }

  private isBlocked(): boolean {
    return this.blockedReason.length > 0;
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Column({ space: 3 }) {
            Text('YUNMEI')
              .fontSize(9)
              .letterSpacing(2.8)
              .fontColor(Palette.MINT)
              .fontWeight(FontWeight.Medium)
            Text(this.greeting + '，' + this.username)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.TEXT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Row({ space: 6 }) {
            Column()
              .width(6)
              .height(6)
              .borderRadius(3)
              .backgroundColor(this.online ? Palette.MINT : Palette.TEXT_DIM)
            Text(this.online ? '已登录' : '离线')
              .fontSize(10)
              .fontColor(this.online ? Palette.MINT_DARK : Palette.TEXT_MUTED)
          }
          .padding({ left: 9, right: 9, top: 6, bottom: 6 })
          .borderRadius(9)
          .backgroundColor(this.online ? Palette.MINT_SOFT : '#F2F4F7')

          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_refresh_ink'))
              .width(18)
              .height(18)
              .opacity(0.6)
          }
          .width(40)
          .height(40)
          .margin({ left: 8 })
          .backgroundColor('#F2F4F7')
          .onClick(() => this.onRefresh())
        }
        .width('100%')
        .margin({ top: 8 })

        Row({ space: 8 }) {
          Row({ space: 6 }) {
            Image($r('app.media.ic_building_ink'))
              .width(12)
              .height(12)
              .opacity(0.4)
            Text(this.schoolName.length > 0 ? this.schoolName : '未选择学校')
              .fontSize(11)
              .fontColor(Palette.TEXT_SOFT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(9)
          .backgroundColor('#F2F4F7')

          Text(this.aesChip)
            .fontSize(11)
            .fontColor(this.isBlocked() ? Palette.WARN : Palette.MINT_DARK)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(9)
            .backgroundColor(this.isBlocked() ? '#FFF4E5' : Palette.MINT_SOFT)

          Blank()
        }
        .width('100%')

        Stack({ alignContent: Alignment.TopStart }) {
          Column()
            .width(280)
            .height(280)
            .borderRadius(140)
            .radialGradient({
              center: ['50%', '50%'],
              radius: '50%',
              colors: [['#1F0EA47A', 0.0], ['#000EA47A', 1.0]]
            })
            .position({ x: 110, y: -120 })

          Column({ space: 0 }) {
            Row() {
              Column({ space: 5 }) {
                Text('当前门锁')
                  .fontSize(10)
                  .letterSpacing(1.4)
                  .fontColor(Palette.TEXT_DIM)
                Text(this.lockLabel)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Palette.TEXT)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text(this.isBlocked() ? '未就绪' : '就绪')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isBlocked() ? Palette.WARN : Palette.MINT_DARK)
                .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                .borderRadius(8)
                .backgroundColor(this.isBlocked() ? '#FFF4E5' : Palette.MINT_SOFT)
            }
            .width('100%')

            Blank()

            Column({ space: 14 }) {
              Stack({ alignContent: Alignment.Center }) {
                Column()
                  .width(204)
                  .height(204)
                  .borderRadius(102)
                  .border({ width: 1, color: '#260EA47A' })
                  .scale({ x: this.pulseScaleOuter, y: this.pulseScaleOuter })
                  .opacity(this.pulseAlphaOuter)

                Column()
                  .width(184)
                  .height(184)
                  .borderRadius(92)
                  .border({ width: 1, color: '#332E90FA' })
                  .scale({ x: this.pulseScale, y: this.pulseScale })
                  .opacity(this.pulseAlpha)

                Circle({ width: 172, height: 172 })
                  .fill(Color.Transparent)
                  .stroke(this.isBlocked() ? '#66DC6803' : '#CC0EA47A')
                  .strokeWidth(2.5)
                  .strokeDashArray([64, 500])
                  .rotate({ angle: this.arcAngle })
                  .opacity(this.unlocking ? 1 : 0.32)

                Button({ type: ButtonType.Circle }) {
                  Column({ space: 3 }) {
                    if (this.unlocking) {
                      LoadingProgress()
                        .width(38)
                        .height(38)
                        .color('#06251B')
                    } else {
                      Image($r('app.media.ic_lock_open_deep'))
                        .width(52)
                        .height(52)
                        .objectFit(ImageFit.Contain)
                    }
                    Text(this.unlocking ? '开门中' : '开门')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#06251B')
                      .letterSpacing(1)
                  }
                }
                .width(150)
                .height(150)
                .backgroundColor(this.isBlocked() ? '#D0D5DD' : '#10B981')
                .linearGradient({
                  angle: 135,
                  colors: this.isBlocked()
                    ? [['#D0D5DD', 0.0], ['#B8C0CC', 1.0]]
                    : [['#34D399', 0.0], ['#22C3EE', 1.0]]
                })
                .shadow({
                  radius: this.unlocking ? 38 : 28,
                  color: this.isBlocked() ? '#1A101828' : '#4010B981',
                  offsetY: 14
                })
                .scale({ x: this.pressScale, y: this.pressScale })
                .enabled(!this.unlocking && !this.isBlocked())
                .onTouch((event: TouchEvent) => {
                  if (event.type === TouchType.Down) {
                    this.pressDown();
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.pressUp();
                  }
                })
                .onClick(() => this.onUnlock())
              }
              .width(212)
              .height(212)

              Text(this.unlocking ? this.stageTitle : '轻触开门 · 请靠近寝室门锁')
                .fontSize(12)
                .fontColor(this.unlocking ? Palette.MINT_DARK : Palette.TEXT_MUTED)
                .letterSpacing(0.3)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')

            Blank()

            if (this.isBlocked()) {
              Row({ space: 8 }) {
                Text('!')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .width(17)
                  .height(17)
                  .borderRadius(9)
                  .backgroundColor(Palette.WARN)
                  .textAlign(TextAlign.Center)
                Text(this.blockedReason)
                  .fontSize(11)
                  .fontColor('#9A4E00')
                  .layoutWeight(1)
                  .maxLines(2)
              }
              .width('100%')
              .padding({ left: 10, right: 10, top: 8, bottom: 8 })
              .borderRadius(12)
              .backgroundColor('#FFF4E5')
            } else {
              Row({ space: 8 }) {
                Column()
                  .width(5)
                  .height(5)
                  .borderRadius(3)
                  .backgroundColor(Palette.MINT)
                Text(this.capabilityText.length > 0 ? this.capabilityText : '门锁能力已确认')
                  .fontSize(11)
                  .fontColor(Palette.TEXT_MUTED)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text('切换门锁')
                  .fontSize(11)
                  .fontColor(Palette.MINT_DARK)
                  .onClick(() => this.onPick())
              }
              .width('100%')
            }
          }
          .width('100%')
          .height(432)
          .padding({ left: 22, right: 22, top: 20, bottom: 18 })
        }
        .width('100%')
        .height(432)
        .borderRadius(30)
        .clip(true)
        .backgroundColor('#F2FFFFFF')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: 1, color: '#F0FFFFFF' })
        .shadow({ radius: 34, color: '#0F172A14', offsetY: 18 })

        Row({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(38)
              .height(38)
              .borderRadius(13)
              .backgroundColor(this.lastStatus.length > 0 ? Palette.MINT_SOFT : '#F2F4F7')
            Image(this.lastStatus.length > 0 ? $r('app.media.ic_check_emerald') : $r('app.media.ic_door_ink'))
              .width(18)
              .height(18)
              .opacity(this.lastStatus.length > 0 ? 1 : 0.4)
          }
          .width(38)
          .height(38)

          Column({ space: 3 }) {
            Text(this.lastStatus.length > 0 ? this.lastStatus : '尚未开门')
              .fontSize(13)
              .fontWeight(this.lastStatus.length > 0 ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.lastStatus.length > 0 ? Palette.TEXT : Palette.TEXT_SOFT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.lastTime.length > 0 ? this.lastTime : '开门结果会显示在这里')
              .fontSize(11)
              .fontColor(Palette.TEXT_DIM)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 13, bottom: 13 })
        .borderRadius(20)
        .backgroundColor('#E6FFFFFF')
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .border({ width: 1, color: '#F0FFFFFF' })
        .shadow({ radius: 20, color: '#0F172A0F', offsetY: 8 })

        Row({ space: 10 }) {
          Button() {
            Row({ space: 7 }) {
              Image($r('app.media.ic_door_ink'))
                .width(16)
                .height(16)
                .opacity(0.5)
              Text('切换门锁')
                .fontSize(13)
                .fontColor(Palette.TEXT_SOFT)
            }
          }
          .layoutWeight(1)
          .height(46)
          .borderRadius(15)
          .backgroundColor('#F2F4F7')
          .onClick(() => this.onPick())

          Button() {
            Row({ space: 7 }) {
              Image($r('app.media.ic_refresh_ink'))
                .width(16)
                .height(16)
                .opacity(0.5)
              Text('刷新凭据')
                .fontSize(13)
                .fontColor(Palette.TEXT_SOFT)
            }
          }
          .layoutWeight(1)
          .height(46)
          .borderRadius(15)
          .backgroundColor('#F2F4F7')
          .onClick(() => this.onRefresh())
        }
        .width('100%')
        .margin({ bottom: 10 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 6, bottom: 106 })
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 18 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
