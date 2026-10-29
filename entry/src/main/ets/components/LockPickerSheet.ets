import { DoorLockInfo, SchoolInfo } from '../model/Models';
import { Palette } from './Visual';

@Component
export struct LockPickerSheet {
  @Prop schools: SchoolInfo[] = [];
  @Prop locks: DoorLockInfo[] = [];
  @Prop currentSchoolNo: string = '';
  @Prop currentLockNo: string = '';
  @Prop busy: boolean = false;
  onPickLock: (lock: DoorLockInfo) => void = (lock: DoorLockInfo) => {
  };
  onPickSchool: (school: SchoolInfo) => void = (school: SchoolInfo) => {
  };
  onRefresh: () => void = () => {
  };
  onClose: () => void = () => {
  };

  @State appeared: boolean = false;

  aboutToAppear(): void {
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.appeared = true;
    });
  }

  private maskedLockNo(lockNo: string): string {
    if (lockNo.length <= 6) {
      return lockNo;
    }
    return '••••' + lockNo.substring(lockNo.length - 4);
  }

  private capabilityLabel(lock: DoorLockInfo): string {
    if (!lock.aesKnown) {
      return '能力未知';
    }
    if (lock.aesSupport) {
      return 'AES 加密';
    }
    return '普通协议';
  }

  @Builder
  schoolChip(school: SchoolInfo) {
    Text(school.name.length > 0 ? school.name : school.schoolNo)
      .fontSize(12)
      .fontColor(this.currentSchoolNo === school.schoolNo ? '#FFFFFF' : Palette.TEXT_SOFT)
      .padding({ left: 13, right: 13, top: 8, bottom: 8 })
      .borderRadius(11)
      .backgroundColor(this.currentSchoolNo === school.schoolNo ? Palette.INK : '#F2F4F7')
      .onClick(() => this.onPickSchool(school))
  }

  @Builder
  lockRow(lock: DoorLockInfo) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(42)
          .height(42)
          .borderRadius(14)
          .backgroundColor(this.currentLockNo === lock.lockNo ? Palette.MINT_SOFT : '#F2F4F7')
        Image(this.currentLockNo === lock.lockNo ? $r('app.media.ic_lock_open_emerald') : $r('app.media.ic_lock_closed_gray'))
          .width(20)
          .height(20)
      }
      .width(42)
      .height(42)

      Column({ space: 5 }) {
        Row({ space: 6 }) {
          Text(lock.label.length > 0 ? lock.label : lock.lockNo)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Palette.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.capabilityLabel(lock))
            .fontSize(9)
            .fontColor(lock.blockedReason.length > 0 ? Palette.WARN : Palette.MINT_DARK)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor(lock.blockedReason.length > 0 ? '#FFF4E5' : Palette.MINT_SOFT)
        }

        Text(this.maskedLockNo(lock.lockNo))
          .fontSize(10)
          .fontColor(Palette.TEXT_DIM)

        if (lock.blockedReason.length > 0) {
          Text(lock.blockedReason)
            .fontSize(10)
            .fontColor('#9A4E00')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.currentLockNo === lock.lockNo) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(20)
            .height(20)
            .borderRadius(10)
            .backgroundColor(Palette.MINT)
          Text('✓')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(20)
        .height(20)
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .borderRadius(16)
    .backgroundColor(this.currentLockNo === lock.lockNo ? '#F2FBF7' : '#F9FAFB')
    .border({
      width: 1,
      color: this.currentLockNo === lock.lockNo ? '#990EA47A' : Palette.LINE_SOFT
    })
    .onClick(() => this.onPickLock(lock))
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66080F1A')
        .onClick(() => this.onClose())

      Column({ space: 14 }) {
        Column()
          .width(38)
          .height(4)
          .borderRadius(2)
          .backgroundColor('#D0D5DD')

        Row() {
          Column({ space: 4 }) {
            Text('门锁与学校')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.TEXT)
            Text('选择后会更新桌面卡片上的门锁')
              .fontSize(11)
              .fontColor(Palette.TEXT_MUTED)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_close_ink'))
              .width(14)
              .height(14)
              .opacity(0.5)
          }
          .width(32)
          .height(32)
          .backgroundColor('#F2F4F7')
          .onClick(() => this.onClose())
        }
        .width('100%')

        Column({ space: 8 }) {
          Text('学校')
            .fontSize(10)
            .letterSpacing(1.4)
            .fontColor(Palette.TEXT_DIM)
            .width('100%')

          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.schools, (school: SchoolInfo) => {
                this.schoolChip(school)
              }, (school: SchoolInfo) => school.schoolNo)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Row() {
            Text('门锁')
              .fontSize(10)
              .letterSpacing(1.4)
              .fontColor(Palette.TEXT_DIM)
            Blank()
            if (this.busy) {
              LoadingProgress()
                .width(14)
                .height(14)
                .color(Palette.TEXT_DIM)
            }
          }
          .width('100%')

          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.locks, (lock: DoorLockInfo) => {
                this.lockRow(lock)
              }, (lock: DoorLockInfo) => lock.lockNo)

              if (this.locks.length === 0) {
                Text(this.busy ? '正在加载门锁…' : '暂无可用门锁')
                  .fontSize(12)
                  .fontColor(Palette.TEXT_DIM)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 20, bottom: 20 })
              }
            }
            .width('100%')
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .constraintSize({ maxHeight: 330 })
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Button() {
          Row({ space: 8 }) {
            Image($r('app.media.ic_refresh_ink'))
              .width(16)
              .height(16)
              .opacity(0.5)
            Text('从服务器刷新门锁列表')
              .fontSize(13)
              .fontColor(Palette.TEXT_SOFT)
          }
        }
        .width('100%')
        .height(46)
        .borderRadius(15)
        .backgroundColor('#F2F4F7')
        .enabled(!this.busy)
        .onClick(() => this.onRefresh())

        Text('门锁凭据会在每次开门前重新获取')
          .fontSize(10)
          .fontColor(Palette.TEXT_DIM)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 24 })
      .borderRadius({ topLeft: 30, topRight: 30, bottomLeft: 0, bottomRight: 0 })
      .backgroundColor('#F2FFFFFF')
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
      .border({ width: 1, color: '#F0FFFFFF' })
      .shadow({ radius: 40, color: '#29101828', offsetY: -8 })
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 60 })
    }
    .width('100%')
    .height('100%')
  }
}
