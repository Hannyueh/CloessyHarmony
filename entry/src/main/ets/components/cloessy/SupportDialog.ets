import { CloessyColors } from './Theme';
import { QrCode } from './QrCode';

@Component
export struct SupportDialog {
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

      Column({ space: 14 }) {
        Row() {
          Column({ space: 4 }) {
            Text('支持开发者')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(CloessyColors.A)
              .letterSpacing(2)
            Text('微信扫码 · 感谢支持')
              .fontSize(9)
              .fontColor('#80171D29')
              .letterSpacing(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('×')
            .fontSize(24)
            .fontColor('#99171D29')
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')

        Row({ space: 12 }) {
          Column({ space: 8 }) {
            QrCode({ source: 'hanyue', codeSize: 124 })
            Text('寒悦')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(CloessyColors.A)
            Text('App 开发者')
              .fontSize(9)
              .fontColor('#80171D29')
          }
          .layoutWeight(1)

          Column({ space: 8 }) {
            QrCode({ source: 'phoenix', codeSize: 124 })
            Text('PhoenixTree')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(CloessyColors.A)
            Text('逆向工程')
              .fontSize(9)
              .fontColor('#80171D29')
          }
          .layoutWeight(1)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Text('CLOESSY')
          .fontSize(8)
          .fontColor('#4D171D29')
          .letterSpacing(3)
          .margin({ top: 4 })
      }
      .width('86%')
      .padding({ top: 22, bottom: 20, left: 20, right: 20 })
      .backgroundColor(CloessyColors.B)
      .borderRadius(28)
      .shadow({ radius: 30, color: '#40000000', offsetX: 0, offsetY: 12 })
      .onClick(() => {
      })
    }
    .width('100%')
    .height('100%')
  }
}
