import { Palette } from './Visual';

@Component
export struct SettingsPanel {
  @Prop username: string = '';
  @Prop schoolName: string = '';
  @Prop lockLabel: string = '';
  @Prop capabilityText: string = '';
  onPick: () => void = () => {
  };
  onRefresh: () => void = () => {
  };
  onLogout: () => void = () => {
  };

  @State appeared: boolean = false;

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
        this.appeared = true;
      });
    }, 40);
  }

  private initial(): string {
    return this.username.length > 0 ? this.username.substring(0, 1).toUpperCase() : 'Y';
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 4 }) {
          Text('我的')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Palette.TEXT)
          Text('账号、门锁与本地数据')
            .fontSize(12)
            .fontColor(Palette.TEXT_MUTED)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 10 })

        Row({ space: 14 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(54)
              .height(54)
              .borderRadius(19)
              .linearGradient({
                angle: 145,
                colors: [['#101828', 0.0], ['#1D2939', 1.0]]
              })
            Text(this.initial())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.MINT)
          }
          .width(54)
          .height(54)

          Column({ space: 4 }) {
            Text(this.username.length > 0 ? this.username : '未登录')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(Palette.TEXT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.schoolName.length > 0 ? this.schoolName : '未选择学校')
              .fontSize(11)
              .fontColor(Palette.TEXT_MUTED)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('已登录')
            .fontSize(10)
            .fontColor(Palette.MINT_DARK)
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .borderRadius(8)
            .backgroundColor(Palette.MINT_SOFT)
        }
        .width('100%')
        .padding(16)
        .borderRadius(24)
        .backgroundColor('#E6FFFFFF')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: 1, color: '#F0FFFFFF' })
        .shadow({ radius: 24, color: '#0F172A14', offsetY: 12 })

        Column({ space: 2 }) {
          Text('门锁')
            .fontSize(11)
            .letterSpacing(1.4)
            .fontColor(Palette.TEXT_DIM)
            .width('100%')
            .margin({ left: 4, bottom: 4 })

          Row() {
            Text('当前门锁')
              .fontSize(13)
              .fontColor(Palette.TEXT_MUTED)
            Blank()
            Text(this.lockLabel.length > 0 ? this.lockLabel : '未选择')
              .fontSize(13)
              .fontColor(Palette.TEXT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 190 })
          }
          .width('100%')
          .height(44)

          Divider().color(Palette.LINE_SOFT)

          Row() {
            Text('门锁协议')
              .fontSize(13)
              .fontColor(Palette.TEXT_MUTED)
            Blank()
            Text(this.capabilityText.length > 0 ? this.capabilityText : '未知')
              .fontSize(13)
              .fontColor(Palette.TEXT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 190 })
          }
          .width('100%')
          .height(44)

          Divider().color(Palette.LINE_SOFT)

          Row({ space: 10 }) {
            Button() {
              Text('切换门锁')
                .fontSize(13)
                .fontColor(Palette.TEXT_SOFT)
            }
            .layoutWeight(1)
            .height(42)
            .borderRadius(13)
            .backgroundColor('#F2F4F7')
            .onClick(() => this.onPick())

            Button() {
              Text('刷新凭据')
                .fontSize(13)
                .fontColor(Palette.TEXT_SOFT)
            }
            .layoutWeight(1)
            .height(42)
            .borderRadius(13)
            .backgroundColor('#F2F4F7')
            .onClick(() => this.onRefresh())
          }
          .width('100%')
          .margin({ top: 10, bottom: 2 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .borderRadius(24)
        .backgroundColor('#E6FFFFFF')
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .border({ width: 1, color: '#F0FFFFFF' })
        .shadow({ radius: 20, color: '#0F172A0F', offsetY: 10 })

        Column({ space: 8 }) {
          Text('数据与隐私')
            .fontSize(11)
            .letterSpacing(1.4)
            .fontColor(Palette.TEXT_DIM)
            .width('100%')
          Text('账号与密码摘要保存在本机，未加密；不会上传到第三方，也不会写入调试日志。')
            .fontSize(12)
            .fontColor(Palette.TEXT_SOFT)
            .lineHeight(19)
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(22)
        .backgroundColor('#F2F4F7')

        Column({ space: 8 }) {
          Text('桌面卡片')
            .fontSize(11)
            .letterSpacing(1.4)
            .fontColor(Palette.TEXT_DIM)
            .width('100%')
          Text('长按桌面应用图标 → 服务卡片 → 添加「一键开门」。点卡片按钮后应用不会跳转，开门进度直接显示在卡片上。')
            .fontSize(12)
            .fontColor(Palette.TEXT_SOFT)
            .lineHeight(19)
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(22)
        .backgroundColor('#F2F4F7')

        Column({ space: 8 }) {
          Text('关于开门')
            .fontSize(11)
            .letterSpacing(1.4)
            .fontColor(Palette.TEXT_DIM)
            .width('100%')
          Text('开门使用官方离线页面的独立 OPEN 指令，并按型号能力选择普通或 AES 封装。门锁是否机械开启仍需以现场为准。')
            .fontSize(12)
            .fontColor(Palette.TEXT_SOFT)
            .lineHeight(19)
            .width('100%')
          Text('版本 0.1.0 · HarmonyOS')
            .fontSize(11)
            .fontColor(Palette.TEXT_DIM)
            .width('100%')
            .margin({ top: 2 })
        }
        .width('100%')
        .padding(16)
        .borderRadius(22)
        .backgroundColor('#F2F4F7')

        Button() {
          Row({ space: 8 }) {
            Image($r('app.media.ic_logout_ink'))
              .width(16)
              .height(16)
              .opacity(0.55)
            Text('退出登录并清除本机凭据')
              .fontSize(14)
              .fontColor('#B42318')
          }
        }
        .width('100%')
        .height(50)
        .borderRadius(16)
        .backgroundColor('#FEF3F2')
        .border({ width: 1, color: '#FECDCA' })
        .onClick(() => this.onLogout())
        .margin({ top: 4, bottom: 10 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 6, bottom: 110 })
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 16 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
