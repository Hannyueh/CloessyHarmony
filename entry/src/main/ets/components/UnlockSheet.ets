import { Palette } from './Visual';

@Component
export struct UnlockSheet {
  @Prop running: boolean = true;
  @Prop stageIndex: number = 0;
  @Prop stageTitle: string = '';
  @Prop stageDetail: string = '';
  @Prop @Watch('onResultChanged') resultKind: number = -1;
  @Prop resultText: string = '';
  onClose: () => void = () => {
  };
  onRetry: () => void = () => {
  };

  @State appeared: boolean = false;
  @State resultScale: number = 0.65;
  @State ringAngle: number = 0;
  @State pulseScale: number = 1;
  @State pulseAlpha: number = 0.45;
  private steps: string[] = ['准备开门', '刷新门锁凭据', '连接门锁', '订阅门锁通知', '发送开锁指令', '等待门锁返回'];

  aboutToAppear(): void {
    animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
      this.appeared = true;
    });
    animateTo({
      duration: 1300,
      curve: Curve.Linear,
      iterations: -1
    }, () => {
      this.ringAngle = 360;
    });
    animateTo({
      duration: 1700,
      curve: Curve.EaseOut,
      iterations: -1
    }, () => {
      this.pulseScale = 1.5;
      this.pulseAlpha = 0;
    });
  }

  onResultChanged(): void {
    if (this.resultKind >= 0) {
      this.resultScale = 0.65;
      animateTo({ duration: 460, curve: Curve.Friction }, () => {
        this.resultScale = 1;
      });
    }
  }

  private isSuccess(): boolean {
    return this.resultKind === 0;
  }

  private titleText(): string {
    if (this.resultKind < 0) {
      return this.stageTitle.length > 0 ? this.stageTitle : '正在开门';
    }
    if (this.resultKind === 0) {
      return '开门指令已确认';
    }
    if (this.resultKind === 1) {
      return '门锁拒绝当前密钥';
    }
    if (this.resultKind === 2) {
      return '开锁结果未确认';
    }
    if (this.resultKind === 3) {
      return '当前门锁暂不可开';
    }
    if (this.resultKind === 4) {
      return '蓝牙连接未完成';
    }
    return '操作已结束';
  }

  private accent(): string {
    if (this.resultKind < 0 || this.resultKind === 0) {
      return Palette.MINT;
    }
    if (this.resultKind === 1) {
      return Palette.WARN;
    }
    return Palette.DANGER;
  }

  private stepDone(index: number): boolean {
    if (this.resultKind === 0) {
      return true;
    }
    return index < this.stageIndex;
  }

  private stepCurrent(index: number): boolean {
    return this.resultKind < 0 && index === this.stageIndex;
  }

  private stepFailed(index: number): boolean {
    return this.resultKind > 0 && index === this.stageIndex;
  }

  @Builder
  stepRow(step: string, index: number) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.stepFailed(index)) {
          Column()
            .width(18)
            .height(18)
            .borderRadius(9)
            .backgroundColor(Palette.DANGER)
          Text('!')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        } else if (this.stepDone(index)) {
          Column()
            .width(18)
            .height(18)
            .borderRadius(9)
            .backgroundColor(Palette.MINT)
          Text('✓')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
        } else if (this.stepCurrent(index)) {
          Column()
            .width(18)
            .height(18)
            .borderRadius(9)
            .border({ width: 1.5, color: Palette.MINT })
          Column()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor(Palette.MINT)
        } else {
          Column()
            .width(18)
            .height(18)
            .borderRadius(9)
            .border({ width: 1, color: Palette.LINE })
        }
      }
      .width(18)
      .height(18)

      Text(step)
        .fontSize(12)
        .fontColor(this.stepDone(index) || this.stepCurrent(index) || this.stepFailed(index)
          ? Palette.TEXT : Palette.TEXT_DIM)
        .fontWeight(this.stepCurrent(index) || this.stepFailed(index) ? FontWeight.Medium : FontWeight.Normal)
        .layoutWeight(1)

      if (this.stepFailed(index)) {
        Text('失败')
          .fontSize(10)
          .fontColor(Palette.DANGER)
      } else if (this.stepCurrent(index)) {
        Text('进行中')
          .fontSize(10)
          .fontColor(Palette.MINT_DARK)
      } else if (this.stepDone(index)) {
        Text('完成')
          .fontSize(10)
          .fontColor(Palette.TEXT_DIM)
      }
    }
    .width('100%')
    .height(34)
    .animation({ duration: 240, curve: Curve.EaseOut })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.appeared ? '#66080F1A' : '#00080F1A')
        .onClick(() => {
          if (this.resultKind >= 0) {
            this.onClose();
          }
        })

      Column({ space: 0 }) {
        Row() {
          Row({ space: 7 }) {
            Column()
              .width(5)
              .height(5)
              .borderRadius(3)
              .backgroundColor(this.accent())
            Text('OPEN · 云莓开门')
              .fontSize(9)
              .letterSpacing(2.2)
              .fontColor(Palette.TEXT_MUTED)
          }

          Blank()

          if (this.resultKind >= 0) {
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.ic_close_ink'))
                .width(14)
                .height(14)
                .opacity(0.5)
            }
            .width(30)
            .height(30)
            .backgroundColor('#F2F4F7')
            .onClick(() => this.onClose())
          }
        }
        .width('100%')

        Stack({ alignContent: Alignment.Center }) {
          if (this.resultKind < 0) {
            Column()
              .width(126)
              .height(126)
              .borderRadius(63)
              .border({ width: 1, color: '#330EA47A' })
              .scale({ x: this.pulseScale, y: this.pulseScale })
              .opacity(this.pulseAlpha)

            Circle({ width: 126, height: 126 })
              .fill(Color.Transparent)
              .stroke('#CC0EA47A')
              .strokeWidth(2)
              .strokeDashArray([50, 380])
              .rotate({ angle: this.ringAngle })

            Column()
              .width(94)
              .height(94)
              .borderRadius(47)
              .backgroundColor(Palette.MINT_SOFT)
              .border({ width: 1, color: '#1F0EA47A' })

            Image($r('app.media.ic_lock_open_emerald'))
              .width(40)
              .height(40)
              .objectFit(ImageFit.Contain)
          } else {
            Column()
              .width(116)
              .height(116)
              .borderRadius(58)
              .backgroundColor(this.isSuccess() ? Palette.MINT_SOFT : (this.resultKind === 1 ? '#FFF4E5' : '#FEF3F2'))
              .scale({ x: this.resultScale, y: this.resultScale })

            Column()
              .width(84)
              .height(84)
              .borderRadius(42)
              .backgroundColor(this.isSuccess() ? Palette.MINT : (this.resultKind === 1 ? Palette.WARN : Palette.DANGER))
              .scale({ x: this.resultScale, y: this.resultScale })
              .shadow({
                radius: 24,
                color: this.isSuccess() ? '#3310B981' : '#26D92D20',
                offsetY: 8
              })

            if (this.isSuccess()) {
              Image($r('app.media.ic_check'))
                .width(38)
                .height(38)
                .scale({ x: this.resultScale, y: this.resultScale })
            } else {
              Text('!')
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .scale({ x: this.resultScale, y: this.resultScale })
            }
          }
        }
        .width('100%')
        .height(178)

        Text(this.titleText())
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.TEXT)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 4 })

        Text(this.resultKind >= 0 ? this.resultText : (this.stageDetail.length > 0 ? this.stageDetail : '正在处理，请保持手机靠近门锁'))
          .fontSize(12)
          .fontColor(Palette.TEXT_MUTED)
          .textAlign(TextAlign.Center)
          .lineHeight(19)
          .width('100%')
          .padding({ left: 8, right: 8 })
          .margin({ top: 8, bottom: 14 })

        Column({ space: 2 }) {
          ForEach(this.steps, (step: string, index: number) => {
            this.stepRow(step, index)
          }, (step: string, index: number) => step + index.toString())
        }
        .width('100%')
        .padding({ left: 6, right: 6, top: 6, bottom: 6 })
        .borderRadius(18)
        .backgroundColor('#F9FAFB')

        if (this.resultKind >= 0) {
          Row({ space: 10 }) {
            Button() {
              Text('关闭')
                .fontSize(15)
                .fontColor(Palette.TEXT_SOFT)
            }
            .layoutWeight(1)
            .height(48)
            .borderRadius(15)
            .backgroundColor('#F2F4F7')
            .onClick(() => this.onClose())

            Button() {
              Text(this.isSuccess() ? '完成' : '重新尝试')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
            }
            .layoutWeight(1)
            .height(48)
            .borderRadius(15)
            .backgroundColor(Palette.INK)
            .linearGradient({
              angle: 100,
              colors: [['#101828', 0.0], ['#1D2939', 1.0]]
            })
            .onClick(() => {
              if (this.isSuccess()) {
                this.onClose();
              } else {
                this.onRetry();
              }
            })
          }
          .width('100%')
          .margin({ top: 14 })
        } else {
          Row({ space: 7 }) {
            LoadingProgress()
              .width(14)
              .height(14)
              .color(Palette.TEXT_DIM)
            Text('正在与门锁通信，请勿离开')
              .fontSize(11)
              .fontColor(Palette.TEXT_DIM)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 14 })
        }
      }
      .width('88%')
      .padding({ left: 20, right: 20, top: 18, bottom: 20 })
      .borderRadius(30)
      .backgroundColor('#F2FFFFFF')
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
      .border({ width: 1, color: '#F0FFFFFF' })
      .shadow({ radius: 44, color: '#29101828', offsetY: 24 })
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 30 })
    }
    .width('100%')
    .height('100%')
  }
}
