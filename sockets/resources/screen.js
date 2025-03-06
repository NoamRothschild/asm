export class Screen {
    #canvas;
    #ctx;

    constructor(canvasId, width, height) {
        this.width = width;
        this.height = height;
        this.#canvas = document.getElementById(canvasId);
        this.#ctx = this.#canvas.getContext('2d');
        this.imageData = this.#ctx.createImageData(this.width, this.height);
        this.palette = undefined;

        this.#ctx.fillStyle = 'black';
        this.#ctx.fillRect(0, 0, this.width, this.height);
    }

    setPalette(binPalette) {
        const raw_palette = new Uint8Array(binPalette);
        
        this.palette = [];
        for (let i = 0; i < raw_palette.length; i += 3) {
            if (i + 2 < raw_palette.length) {
                this.palette.push([raw_palette[i], raw_palette[i+1], raw_palette[i+2]]);
            }
        }
    }

    async draw(binData) {
        return new Promise((resolve, reject) => {
            if (!this.palette) {
                reject("Uninitialized palette");
            }

            const screen = new Uint8Array(binData);
            
            for (let pixelIndex = 0; pixelIndex < this.width * this.height; pixelIndex++) {
                const colorIndex = screen[pixelIndex];
                if (colorIndex !== undefined && this.palette[colorIndex]) {
                    const [r, g, b] = this.palette[colorIndex];
                    
                    // Set pixel in ImageData (RGBA format)
                    const dataIndex = pixelIndex * 4;
                    this.imageData.data[dataIndex]     = r;   // Red
                    this.imageData.data[dataIndex + 1] = g;   // Green
                    this.imageData.data[dataIndex + 2] = b;   // Blue
                    this.imageData.data[dataIndex + 3] = 255; // Alpha (fully opaque)
                }
            }
            
            // Put the image data onto the canvas
            this.#ctx.putImageData(this.imageData, 0, 0);
            resolve();
        });
    }

}