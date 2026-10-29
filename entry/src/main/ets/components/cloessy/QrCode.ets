import { CloessyColors } from './Theme';
import { CloessyQrData } from './QrData';

/**
 * Draws the QR modules directly on a Canvas. The payment QR is regenerated from
 * its payload matrix, so no screenshot/bitmap is embedded in the app.
 */
@Component
export struct QrCode {
  @Prop source: string = 'hanyue';
  @Prop codeSize: number = 136;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private draw(): void {
    const rows: string[] = this.source === 'phoenix' ? CloessyQrData.PHOENIX : CloessyQrData.HANYUE;
    const count = rows.length;
    const cell = this.codeSize / count;
    this.ctx.fillStyle = CloessyColors.B;
    this.ctx.fillRect(0, 0, this.codeSize, this.codeSize);
    this.ctx.fillStyle = CloessyColors.A;
    for (let y = 0; y < count; y++) {
      const row = rows[y];
      for (let x = 0; x < row.length; x++) {
        if (row.charAt(x) === '1') {
          this.ctx.fillRect(x * cell, y * cell, cell + 0.35, cell + 0.35);
        }
      }
    }
  }

  build() {
    Canvas(this.ctx)
      .width(this.codeSize)
      .height(this.codeSize)
      .onReady(() => {
        this.draw();
      })
  }
}
