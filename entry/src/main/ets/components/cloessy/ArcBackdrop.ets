import { CloessyColors } from './Theme';

/** Complete rings with a slow two-way drift; clipped by the screen edge. */
@Component
export struct ArcBackdrop {
  @Prop dark: boolean = true;
  @State shift: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      animateTo({ duration: 4200, curve: Curve.EaseInOut }, () => {
        this.shift = this.shift === 0 ? 1 : 0;
      });
    }, 4500);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  build() {
    Stack() {
      Circle()
        .width(420)
        .height(420)
        .fill('#00000000')
        .fillOpacity(0)
        .stroke(this.dark ? CloessyColors.ARC_ON_A : CloessyColors.ARC_ON_B)
        .strokeWidth(5)
        .position({ x: -270, y: 90 })
        .translate({ y: this.shift * 22 })
      Circle()
        .width(300)
        .height(300)
        .fill('#00000000')
        .fillOpacity(0)
        .stroke(this.dark ? CloessyColors.ARC_ON_A : CloessyColors.ARC_ON_B)
        .strokeWidth(5)
        .position({ x: 270, y: 520 })
        .translate({ y: -this.shift * 16 })
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
