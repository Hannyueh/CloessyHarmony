import { CloessyColors } from './Theme';

@Component
export struct LoginSheet {
  @Link username: string;
  @Link password: string;
  @Prop busy: boolean = false;
  @Prop errorText: string = '';
  @Prop titleText: string = '登录 CLOESSY';
  @Prop subtitleText: string = '使用云莓账号登录，账号仅保存在本机';
  @Prop submitText: string = '登录';
  @Prop passwordPlaceholder: string = '请输入密码';
  onSubmit: () => void = () => {
  };
  onClose: () => void = () => {
  };

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(CloessyColors.DIM)
        .onClick(() => {
          this.onClose();
        })

      Column() {
        Blank()
          .layoutWeight(1)

        Column({ space: 0 }) {
          Row() {
            Text(this.titleText)
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(CloessyColors.A)
              .letterSpacing(1)
              .layoutWeight(1)
            Text('×')
              .fontSize(24)
              .fontColor('#99171D29')
              .onClick(() => {
                this.onClose();
              })
          }
          .width('100%')
          .margin({ bottom: 6 })

          Text(this.subtitleText)
            .fontSize(10)
            .fontColor('#80171D29')
            .width('100%')
            .margin({ bottom: 26 })

          Text('账号')
            .fontSize(9)
            .fontColor('#66171D29')
            .letterSpacing(2)
            .width('100%')
            .margin({ bottom: 6 })
          TextInput({ text: this.username, placeholder: '请输入账号' })
            .height(44)
            .width('100%')
            .padding(0)
            .backgroundColor('#00000000')
            .fontSize(16)
            .fontColor(CloessyColors.A)
            .placeholderColor('#4D171D29')
            .caretColor(CloessyColors.A)
            .onChange((value: string) => {
              this.username = value;
            })
          Divider()
            .strokeWidth(1)
            .color('#24171D29')

          Text('密码')
            .fontSize(9)
            .fontColor('#66171D29')
            .letterSpacing(2)
            .width('100%')
            .margin({ top: 22, bottom: 6 })
          TextInput({ text: this.password, placeholder: this.passwordPlaceholder })
            .type(InputType.Password)
            .enterKeyType(EnterKeyType.Go)
            .height(44)
            .width('100%')
            .padding(0)
            .backgroundColor('#00000000')
            .fontSize(16)
            .fontColor(CloessyColors.A)
            .placeholderColor('#4D171D29')
            .caretColor(CloessyColors.A)
            .onChange((value: string) => {
              this.password = value;
            })
            .onSubmit(() => {
              this.onSubmit();
            })
          Divider()
            .strokeWidth(1)
            .color('#24171D29')

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(10)
              .fontColor('#B3423A')
              .width('100%')
              .margin({ top: 14 })
          }

          Button(this.busy ? '正在处理…' : this.submitText)
            .width('100%')
            .height(50)
            .margin({ top: 28 })
            .backgroundColor(CloessyColors.A)
            .fontColor(CloessyColors.B)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .borderRadius(2)
            .enabled(!this.busy)
            .onClick(() => {
              this.onSubmit();
            })
        }
        .width('100%')
        .padding({ top: 24, bottom: 30, left: 28, right: 28 })
        .backgroundColor(CloessyColors.B)
        .borderRadius({ topLeft: 28, topRight: 28 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
