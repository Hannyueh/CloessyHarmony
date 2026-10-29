/** Shared light palette and decorative building blocks for the native ArkUI surface. */
export class Palette {
  static readonly BG: string = '#F6F7F9';
  static readonly BG_TOP: string = '#FFFFFF';
  static readonly BG_BOTTOM: string = '#F3F5F8';
  static readonly SURFACE: string = '#FFFFFF';
  static readonly TEXT: string = '#101828';
  static readonly TEXT_SOFT: string = '#475467';
  static readonly TEXT_MUTED: string = '#667085';
  static readonly TEXT_DIM: string = '#98A2B3';
  static readonly LINE: string = '#EAECF0';
  static readonly LINE_SOFT: string = '#F2F4F7';
  static readonly HAIRLINE: string = '#EAECF0';
  static readonly MINT: string = '#0EA47A';
  static readonly MINT_DARK: string = '#067A5C';
  static readonly MINT_SOFT: string = '#E7F8F1';
  static readonly MINT_GLOW: string = '#140EA47A';
  static readonly CYAN: string = '#2E90FA';
  static readonly DANGER: string = '#D92D20';
  static readonly WARN: string = '#DC6803';
  static readonly INK: string = '#101828';
  static readonly GLASS: string = '#E6FFFFFF';
  static readonly GLASS_SOFT: string = '#F2FFFFFF';
}

@Component
export struct Backdrop {
  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [[Palette.BG_TOP, 0.0], ['#FAFBFC', 0.5], [Palette.BG_BOTTOM, 1.0]]
        })

      Column()
        .width(360)
        .height(360)
        .borderRadius(180)
        .radialGradient({
          center: ['50%', '50%'],
          radius: '50%',
          colors: [['#180EA47A', 0.0], ['#000EA47A', 1.0]]
        })
        .position({ x: -150, y: -100 })

      Column()
        .width(320)
        .height(320)
        .borderRadius(160)
        .radialGradient({
          center: ['50%', '50%'],
          radius: '50%',
          colors: [['#122E90FA', 0.0], ['#002E90FA', 1.0]]
        })
        .position({ x: 170, y: 470 })

      Column()
        .width(560)
        .height(560)
        .borderRadius(280)
        .border({ width: 1, color: '#F0F2F5' })
        .position({ x: -120, y: 260 })
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct BrandBadge {
  badgeSize: number = 72;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.badgeSize)
        .height(this.badgeSize)
        .borderRadius(this.badgeSize * 0.3)
        .linearGradient({
          angle: 145,
          colors: [['#101828', 0.0], ['#1D2939', 1.0]]
        })
        .shadow({ radius: 24, color: '#33101828', offsetY: 10 })

      Image($r('app.media.ic_lock_open_mint'))
        .width(this.badgeSize * 0.5)
        .height(this.badgeSize * 0.5)
        .objectFit(ImageFit.Contain)
    }
    .width(this.badgeSize)
    .height(this.badgeSize)
  }
}
