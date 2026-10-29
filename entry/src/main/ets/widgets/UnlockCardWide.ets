import { CloessyColors } from '../components/cloessy/Theme';

let storageWideV2 = new LocalStorage();

@Entry(storageWideV2)
@Component
struct UnlockCardWide {
  @LocalStorageProp('lockLabel') lockLabel: string = '未选择门锁';
  @LocalStorageProp('statusText') statusText: string = '长按应用登录';
  @LocalStorageProp('step') @Watch('onStepChanged') step: number = 0;
  @LocalStorageProp('busy') busy: boolean = false;
  @LocalStorageProp('cardToken') cardToken: string = '';
  @LocalStorageProp('homeOnA') homeOnA: boolean = true;
  @LocalStorageProp('animate') animate: boolean = true;
  @State shownProgress: number = 0;

  aboutToAppear(): void {
    this.shownProgress = this.progress();
  }

  private onStepChanged(): void {
    const target = Math.min(1, this.progress() + (this.busy && this.step > 0 && this.step < 5 ? 0.02 : 0));
    if (this.step >= 5) {
      animateTo({ duration: 620, curve: Curve.FastOutSlowIn }, () => {
        this.shownProgress = 1;
      });
      return;
    }
    if (target < this.shownProgress) {
      if (this.animate) {
        animateTo({ duration: 620, curve: Curve.FastOutSlowIn }, () => {
          this.shownProgress = target;
        });
      } else {
        this.shownProgress = target;
      }
      return;
    }
    animateTo({ duration: this.busy ? 12000 : 620, curve: Curve.FastOutSlowIn }, () => {
      this.shownProgress = target;
    });
  }

  private progress(): number {
    if (this.step < 0) {
      return 0;
    }
    return Math.max(0, Math.min(1, this.step / 5));
  }

  private baseColor(): string {
    return CloessyColors.A;
  }

  private fgColor(): string {
    return CloessyColors.B;
  }

  private arcColor(): string {
    return CloessyColors.ARC_ON_A;
  }

  private requestUnlock(): void {
    postCardAction(this, {
      action: 'call',
      abilityName: 'CardUnlockAbility',
      params: {
        'method': 'unlockCard',
        'yunmeiAction': 'cardUnlock',
        'cardToken': this.cardToken
      }
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(160)
        .height(160)
        .borderRadius(80)
        .border({ width: 1, color: this.arcColor() })
        .position({ x: -50, y: 12 })
        .rotate({ angle: -55 })
      Column()
        .width(80)
        .height(80)
        .borderRadius(40)
        .border({ width: 1, color: this.arcColor() })
        .position({ x: 292, y: 118 })
        .rotate({ angle: 150 })

      Column() {
        Blank()
        Stack() {
          Row()
            .width('100%')
            .height(3)
            .backgroundColor(this.arcColor())
            .opacity(0.35)
          Row()
            .width((this.shownProgress * 100) + '%')
            .height(3)
            .backgroundColor(this.fgColor())
        }
        .width('100%')
        .height(3)
      }
      .width('100%')
      .height('100%')


      Column() {
        Text('CLOESSY')
          .fontSize(8)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.fgColor())
          .letterSpacing(2.6)
          .opacity(0.62)
          .width('100%')
          .textAlign(TextAlign.End)

        Blank()

        Column({ space: 3 }) {
          Text(this.lockLabel)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.fgColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.End)
          Text(this.statusText)
            .fontSize(10)
            .fontColor(this.fgColor())
            .opacity(0.6)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.End)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.baseColor())
    .borderRadius(2)
    .clip(true)
    .border({ width: 1, color: CloessyColors.HAIR_ON_A })
    .onClick(() => {
      this.requestUnlock();
    })
  }
}
