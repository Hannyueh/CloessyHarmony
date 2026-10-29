import { CloessyColors } from '../components/cloessy/Theme';

let storageCapsule = new LocalStorage();

@Entry(storageCapsule)
@Component
struct UnlockCardCapsule {
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
        .width(90)
        .height(90)
        .borderRadius(45)
        .border({ width: 1, color: this.arcColor() })
        .position({ x: -24, y: -4 })
        .rotate({ angle: -55 })

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
          .fontSize(6)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.fgColor())
          .letterSpacing(2.2)
          .opacity(0.62)
          .width('100%')
          .textAlign(TextAlign.End)

        Blank()

        Row() {
          Blank()
          Column({ space: 1 }) {
            Text(this.lockLabel)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.fgColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.End)
            Text(this.statusText)
              .fontSize(7)
              .fontColor(this.fgColor())
              .opacity(0.6)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.End)
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 14, right: 14, top: 8, bottom: 9 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.baseColor())
    .clip(true)
    .onClick(() => {
      this.requestUnlock();
    })
  }
}
