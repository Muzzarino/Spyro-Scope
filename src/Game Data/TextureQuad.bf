using System;

namespace SpyroScope {
	[Ordered]
	public struct TextureQuad {
		public uint8 left, leftSkew, clutX, clutY, right, rightSkew, texturePage, flipRotateRaw;
		public const float quadSize = 1f / 16;

		// Used for checking where the quad UVs would line up in VRAM
		public (float left, float right, float leftY, float rightY) GetVramPartialUV() {
			let pageCoords = GetPageCoordinates();
			let subPixels = (texturePage & 0x80 > 0) ? 2 : 4;

			let pageOffsetX = pageCoords.x * 0.0625f;
			let pageOffsetY = pageCoords.y * 0.5f;

			let rightSkewAdjusted = Emulator.installment == .SpyroTheDragon ? rightSkew + 0x1f : rightSkew;
			return (
				pageOffsetX + (float)left / subPixels / 1024,
				pageOffsetX + (float)((uint16)right + 1) / subPixels / 1024,
				pageOffsetY + (float)leftSkew / 512,
				pageOffsetY + (float)((uint16)rightSkewAdjusted + 1) / 512
			);
		}

		public (int x, int y) GetPageCoordinates() {
			return (texturePage & 0xf, (texturePage & 0x10) >> 4);
		}

		public uint8 GetQuadRotation() {
			return (flipRotateRaw & 0b00110000) >> 4;
		}

		public bool GetDiagonalFlip() {
			return (flipRotateRaw & 0b01000000) > 0;
		}

		public bool GetTransparency() {
			return Emulator.installment != .SpyroTheDragon && (flipRotateRaw & 0b10000000) > 0;
		}

		// All terrain quads are 32 by 32,
		// and the closer rendered ones are four of those combined

		/// Get a 32x32 pixel texture from the quad
		public uint32[] GetTextureData() {
			let pageCoords = GetPageCoordinates();
			let vramPageCoords = (pageCoords.x * 64) + (pageCoords.y * 256 * 1024);
			let vramCoords = vramPageCoords + ((int)leftSkew * 1024);
			// We are going to assuming that the area used in VRAM is always square

			let bitMode = (texturePage & 0x80 > 0) ? 8 : 4;
			let bitModeMask = (1 << bitMode) - 1;
			let subPixels = bitMode == 8 ? 2 : 4;

			// The game splits the VRAM into a grid of 64 by 128 possible CLUT locations
			// The size of each cell is 16x4 that contain all the necessary colors horizontally
			// and the fade out of saturation vertically when viewed from increasing distance
			let clutPosition = (int)clutX * 16 + ((int)clutY << 2) * 1024;

			uint32[] pixels = new .[32 * 32](0,);
			for (let x < 32) {
				for (let y < 32) {
					let texelX = x + left;

					// Get the target pixel from the texture
					let vramPixel = Emulator.vramSnapshot[vramCoords + texelX / subPixels + y * 1024];

					// Retrieve a sub-pixel value from VRAM (8- or 4-bit mode) to sample from a CLUT
					// Each sub-pixel contains a 8 or 4 bit value that tells the location of sample
					//
					// |       16-bit pixel        |
					// |       (8-bit mode)        |
					// |   11111111  |  00000000   |
					// |       (4-bit mode)        |
					// | 3333 | 2222 | 1111 | 0000 |
					//
					// After sampling, the result is a pixel in a color format of BGR555
					let p = texelX % subPixels;
					let clutSample = (((int)vramPixel >> (p * bitMode)) & bitModeMask) + clutPosition;
					let bgr555pixel = Emulator.vramSnapshot[clutSample];

					// Get each 5 bit color channel
					// |        16-bit pixel       |
					// | a | bbbbb | ggggg | rrrrr |
					let r5 = bgr555pixel & 0x1f;
					let g5 = bgr555pixel >> 5 & 0x1f;
					let b5 = bgr555pixel >> 10 & 0x1f;
					let a1 = bgr555pixel >> 15;

					// Bring values from 31 up to 255 (0x1f to 0xff)
					let r = (uint32)((float)r5 / 0x1f * 255);
					let g = (uint32)((float)g5 / 0x1f * 255);
					let b = (uint32)((float)b5 / 0x1f * 255);

					// Write to the texture data
					pixels[x + y * 32] = r + (g << 8) + (b << 16) + ((1 - a1) * (uint32)0xff000000);
				}
			}

			return pixels;
		}
	}
}
