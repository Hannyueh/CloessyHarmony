import { Palette, BrandBadge } from './Visual';

@Component
export struct LoginPanel {
  @Link username: string;
  @Link password: string;
  @Link remember: boolean;
  @Prop busy: boolean = false;
  @Prop errorText: string = '';
  onSubmit: () => void = () => {
  };

  @State appeared: boolean = false;
  @State accountFocus: boolean = false;
  @State passwordFocus: boolean = false;
  @State buttonScale: number = 1;
  @State hintIndex: number = 0;
  private hintTimer: number = 0;
  private hints: string[] = [
    '在桌面添加「一键开门」卡片，点按钮即可开门',
    '卡片会直接显示开门进度，不会跳转应用',
    '同一账号可切换学校与门锁'
  ];

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({ duration: 620, curve: Curve.EaseOut }, () => {
        this.appeared = true;
      });
    }, 70);
    this.hintTimer = setInterval(() => {
      this.hintIndex = (this.hintIndex + 1) % this.hints.length;
    }, 4200);
  }

  aboutToDisappear(): void {
    if (this.hintTimer > 0) {
      clearInterval(this.hintTimer);
    }
  }

  private submit(): void {
    if (this.busy) {
      return;
    }
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      this.buttonScale = 0.97;
    });
    setTimeout(() => {
      animateTo({ duration: 240, curve: Curve.Friction }, () => {
        this.buttonScale = 1;
      });
    }, 110);
    this.onSubmit();
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: 12 }) {
          BrandBadge({ badgeSize: 76 })
          Text('云莓开门')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(Palette.TEXT)
            .letterSpacing(1)
          Text('YUNMEI · 宿舍智能门锁')
            .fontSize(10)
            .fontColor(Palette.TEXT_DIM)
            .letterSpacing(2.6)
        }
        .width('100%')
        .margin({ top: 30, bottom: 24 })
        .opacity(this.appeared ? 1 : 0)
        .translate({ y: this.appeared ? 0 : 18 })

        Column({ space: 15 }) {
          Column({ space: 5 }) {
            Text('登录你的云莓账号')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(Palette.TEXT)
            Text('与官方客户端使用同一套账号密码')
              .fontSize(12)
              .fontColor(Palette.TEXT_MUTED)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 2 })

          Row({ space: 10 }) {
            Image($r('app.media.ic_person_ink'))
              .width(18)
              .height(18)
              .opacity(0.5)
              .margin({ left: 15 })
            TextInput({ placeholder: '云莓账号', text: this.username })
              .layoutWeight(1)
              .height(54)
              .backgroundColor(Color.Transparent)
              .fontSize(15)
              .fontColor(Palette.TEXT)
              .placeholderColor(Palette.TEXT_DIM)
              .caretColor(Palette.MINT)
              .padding({ left: 0, right: 14 })
              .onChange((value: string) => {
                this.username = value;
              })
              .onFocus(() => {
                this.accountFocus = true;
              })
              .onBlur(() => {
                this.accountFocus = false;
              })
          }
          .width('100%')
          .height(54)
          .borderRadius(16)
          .backgroundColor('#F9FAFB')
          .border({ width: 1, color: this.accountFocus ? '#660EA47A' : Palette.LINE })

          Row({ space: 10 }) {
            Image($r('app.media.ic_key_ink'))
              .width(18)
              .height(18)
              .opacity(0.5)
              .margin({ left: 15 })
            TextInput({ placeholder: '登录密码', text: this.password })
              .layoutWeight(1)
              .height(54)
              .type(InputType.Password)
              .showPasswordIcon(true)
              .backgroundColor(Color.Transparent)
              .fontSize(15)
              .fontColor(Palette.TEXT)
              .placeholderColor(Palette.TEXT_DIM)
              .caretColor(Palette.MINT)
              .padding({ left: 0, right: 6 })
              .enterKeyType(EnterKeyType.Go)
              .onChange((value: string) => {
                this.password = value;
              })
              .onFocus(() => {
                this.passwordFocus = true;
              })
              .onBlur(() => {
                this.passwordFocus = false;
              })
              .onSubmit(() => {
                this.submit();
              })
          }
          .width('100%')
          .height(54)
          .borderRadius(16)
          .backgroundColor('#F9FAFB')
          .border({ width: 1, color: this.passwordFocus ? '#660EA47A' : Palette.LINE })

          Row() {
            Text('记住账号与密码')
              .fontSize(13)
              .fontColor(Palette.TEXT_SOFT)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.remember })
              .selectedColor(Palette.MINT)
              .switchPointColor('#FFFFFF')
              .onChange((value: boolean) => {
                this.remember = value;
              })
          }
          .width('100%')
          .margin({ top: 2 })

          Button() {
            Row({ space: 10 }) {
              if (this.busy) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color('#FFFFFF')
              }
              Text(this.busy ? '正在登录并加载门锁' : '登录并加载门锁')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
            }
          }
          .width('100%')
          .height(54)
          .borderRadius(17)
          .backgroundColor(Palette.INK)
          .linearGradient({
            angle: 100,
            colors: [['#101828', 0.0], ['#1D2939', 1.0]]
          })
          .shadow({ radius: 20, color: '#26101828', offsetY: 10 })
          .enabled(!this.busy)
          .opacity(this.busy ? 0.75 : 1)
          .scale({ x: this.buttonScale, y: this.buttonScale })
          .onClick(() => this.submit())
          .margin({ top: 4 })

          if (this.errorText.length > 0) {
            Row({ space: 8 }) {
              Text('!')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .width(18)
                .height(18)
                .borderRadius(9)
                .backgroundColor(Palette.DANGER)
                .textAlign(TextAlign.Center)
              Text(this.errorText)
                .fontSize(12)
                .fontColor('#B42318')
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 9, bottom: 9 })
            .borderRadius(12)
            .backgroundColor('#FEF3F2')
            .border({ width: 1, color: '#FECDCA' })
            .transition(TransitionEffect.OPACITY)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 20 })
        .borderRadius(28)
        .backgroundColor('#E6FFFFFF')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: 1, color: '#F0FFFFFF' })
        .shadow({ radius: 36, color: '#0F172A1A', offsetY: 18 })
        .opacity(this.appeared ? 1 : 0)
        .translate({ y: this.appeared ? 0 : 26 })

        Column({ space: 8 }) {
          Text(this.hints[this.hintIndex])
            .fontSize(11)
            .fontColor(Palette.TEXT_MUTED)
            .width('100%')
            .textAlign(TextAlign.Center)
            .maxLines(2)
          Text('凭据只保存在本机 · 不会上传到第三方')
            .fontSize(10)
            .fontColor(Palette.TEXT_DIM)
        }
        .width('100%')
        .margin({ top: 20 })
        .opacity(this.appeared ? 1 : 0)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 12, bottom: 30 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
