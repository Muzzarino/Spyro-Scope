using OpenGL;
using SDL2;
using System;
using System.Collections;
using System.IO;

namespace SpyroScope {
	class VRAMViewerState : WindowState {

		List<TextureSprite> textureSprites = new .() ~ DeleteContainerAndItems!(_);
		TextureQuad[] textureSprites3 = new .[45] ~ delete _;
		int blinkerTime = 0;
		bool spritesDecoded;

		enum TextureType {
			Terrain,
			Object,
			Sprite
		}

		enum CLUTType {
			Normal,
			Gradient
		}

		struct CLUTReference {
			public int location;
			public int width;
			public CLUTType type;
			public TextureType category;
			public List<int> references;
		}

		List<CLUTReference> cluts = new .();

		enum RenderMode {
			Raw,
			Decoded
		}
		RenderMode renderMode;

		enum ClickMode {
			Normal,
			Export,
			Alter
		}
		ClickMode clickMode;

		float scale = 1, scaleMagnitude = 0;
		bool expand;
		Vector2 vramOrigin;
		(float width, float height) vramSize;

		Vector2 viewPosition, testPosition;
		int hoveredTexturePage = -1, hoveredTextureIndex = -1, hoveredCLUTIndex = -1, hoveredSpriteIndex = -1;
		int selectedTexturePage = -1, selectedTextureIndex = -1, selectedCLUTIndex = -1, selectedSpriteIndex = -1;
		bool panning;

		public this() {
			Emulator.OnSceneChanged.Add(new => OnSceneChanged);
			VRAM.OnSnapshotTaken.Add(new => OnNewSnapshot);
		}

		public ~this() {
			for (let clutReference in cluts) {
				delete clutReference.references;
			}

			delete cluts;
		}

		public override void Enter() {
			ResetView();
		}

		public override void Exit() {

		}

		public override void Update() {
			Emulator.FetchImportantData();

			Terrain.UpdateTextureInfo(false);
			blinkerTime = (blinkerTime + 1) % 50;

			if (VRAM.upToDate) {
				Decode();
			}
		}

		public override void DrawGUI() {
			let pixelWidth = expand ? 4 : 1;
			vramSize.width = (expand ? 512 : 1024) * pixelWidth;
			vramSize.height = 512;

			let right = vramOrigin.x + vramSize.width * scale;
			let bottom = vramOrigin.y + vramSize.height * scale;

			if (VRAM.upToDate) {
				DrawUtilities.Rect(vramOrigin.y, bottom, vramOrigin.x, right, 0, 1, expand ? 0.5f : 0, 1, VRAM.raw, .(255,255,255));
				DrawUtilities.Rect(vramOrigin.y, bottom, vramOrigin.x, right, 0, 1, expand ? 0.5f : 0, 1, VRAM.decoded, .(255,255,255));
			}

			for (let textureIndex in Terrain.usedTextureIndices) {
				let quadCount = Emulator.installment == .SpyroTheDragon ? 21 : 6;

				for (let quadIndex < quadCount) {
					let i = textureIndex * quadCount + quadIndex;
					let quad = Terrain.textures[i];
					let partialUVs = quad.GetVramPartialUV();

					Rect quadRect;
					quadRect.start = UVToScreen(partialUVs.left, partialUVs.leftY);
					quadRect.end = UVToScreen(partialUVs.right, partialUVs.rightY);

					Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.right, quadRect.top, 0), .(64,64,64), .(64,64,64));
					Renderer.DrawLine(.(quadRect.left, quadRect.bottom, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,64), .(64,64,64));
					Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.left, quadRect.bottom, 0), .(64,64,64), .(64,64,64));
					Renderer.DrawLine(.(quadRect.right, quadRect.top, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,64), .(64,64,64));

					if (blinkerTime < 30 && selectedCLUTIndex > -1 && cluts[selectedCLUTIndex].category == .Terrain && cluts[selectedCLUTIndex].references.Contains(i)) {
						DrawUtilities.Rect(quadRect, .(255,0,0,64));
					}

					let modifiedQuadIndex = quadIndex + (Emulator.installment == .SpyroTheDragon ? 1 : 0);
					switch (modifiedQuadIndex) {
						case 0:
							quadRect.left += 4;
							quadRect.top += 4;
							quadRect.right -= 4;
							quadRect.bottom -= 4;

							Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.right, quadRect.top, 0), .(255,64,64), .(255,64,64));
							Renderer.DrawLine(.(quadRect.left, quadRect.bottom, 0), .(quadRect.right, quadRect.bottom, 0), .(255,64,64), .(255,64,64));
							Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.left, quadRect.bottom, 0), .(255,64,64), .(255,64,64));
							Renderer.DrawLine(.(quadRect.right, quadRect.top, 0), .(quadRect.right, quadRect.bottom, 0), .(255,64,64), .(255,64,64));
						case 1:
							quadRect.left += 2;
							quadRect.top += 2;
							quadRect.right -= 2;
							quadRect.bottom -= 2;

							Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.right, quadRect.top, 0), .(64,255,64), .(64,255,64));
							Renderer.DrawLine(.(quadRect.left, quadRect.bottom, 0), .(quadRect.right, quadRect.bottom, 0), .(64,255,64), .(64,255,64));
							Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.left, quadRect.bottom, 0), .(64,255,64), .(64,255,64));
							Renderer.DrawLine(.(quadRect.right, quadRect.top, 0), .(quadRect.right, quadRect.bottom, 0), .(64,255,64), .(64,255,64));
						case 2:
							quadRect.left += 4;
							quadRect.top += 4;

							Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.right, quadRect.top, 0), .(64,64,255), .(64,64,255));
							Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.left, quadRect.bottom, 0), .(64,64,255), .(64,64,255));
						case 3:
							quadRect.top += 4;
							quadRect.right -= 4;

							Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.right, quadRect.top, 0), .(64,64,255), .(64,64,255));
							Renderer.DrawLine(.(quadRect.right, quadRect.top, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,255), .(64,64,255));
						case 4:
							quadRect.left += 4;
							quadRect.bottom -= 4;

							Renderer.DrawLine(.(quadRect.left, quadRect.bottom, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,255), .(64,64,255));
							Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.left, quadRect.bottom, 0), .(64,64,255), .(64,64,255));
						case 5:
							quadRect.right -= 4;
							quadRect.bottom -= 4;

							Renderer.DrawLine(.(quadRect.left, quadRect.bottom, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,255), .(64,64,255));
							Renderer.DrawLine(.(quadRect.right, quadRect.top, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,255), .(64,64,255));
					}
				}
			}

			for (let i < textureSprites3.Count) {
				let sprite = textureSprites3[i];
				let partialUVs = sprite.GetVramPartialUV();

				Rect quadRect;
				quadRect.start = UVToScreen(partialUVs.left, partialUVs.leftY);
				quadRect.end = UVToScreen(partialUVs.right, partialUVs.rightY);

				Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.right, quadRect.top, 0), .(64,64,64), .(64,64,64));
				Renderer.DrawLine(.(quadRect.left, quadRect.bottom, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,64), .(64,64,64));
				Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.left, quadRect.bottom, 0), .(64,64,64), .(64,64,64));
				Renderer.DrawLine(.(quadRect.right, quadRect.top, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,64), .(64,64,64));

				if (blinkerTime < 30 && selectedCLUTIndex > -1 && cluts[selectedCLUTIndex].category == .Sprite && cluts[selectedCLUTIndex].references.Contains(i)) {
					DrawUtilities.Rect(quadRect, .(255,0,0,64));
				}
			}

			for (let CLUTIndex < cluts.Count) {
				let clutReference = cluts[CLUTIndex];
				(int x, int y) clutPosition = ((clutReference.location & 0x3f) << 4, clutReference.location >> 6);

				let clutStart = PixelToScreen(clutPosition.x, (clutPosition.x >> 10) + clutPosition.y);
				let clutEnd = PixelToScreen(clutPosition.x + clutReference.width, (clutPosition.x >> 10) + clutPosition.y + (clutReference.type == .Gradient ? 16 : 1));

				Renderer.DrawLine(.(clutStart.x, clutStart.y, 0), .(clutEnd.x, clutStart.y, 0), .(64,64,64), .(64,64,64));
				Renderer.DrawLine(.(clutStart.x, clutEnd.y, 0), .(clutEnd.x, clutEnd.y, 0), .(64,64,64), .(64,64,64));
				Renderer.DrawLine(.(clutStart.x, clutStart.y, 0), .(clutStart.x, clutEnd.y, 0), .(64,64,64), .(64,64,64));
				Renderer.DrawLine(.(clutEnd.x, clutStart.y, 0), .(clutEnd.x, clutEnd.y, 0), .(64,64,64), .(64,64,64));
			}

			// CLUTs can be small and packed very tightly in VRAM so the lines drawn could over draw the highlight,
			// instead do it in another loop draw pass
			for (let CLUTIndex < cluts.Count) {
				let clutReference = cluts[CLUTIndex];
				(int x, int y) clutPosition = ((clutReference.location & 0x3f) << 4, clutReference.location >> 6);

				Rect clutRect;
				clutRect.start = PixelToScreen(clutPosition.x, (clutPosition.x >> 10) + clutPosition.y);
				clutRect.end = PixelToScreen(clutPosition.x + clutReference.width, (clutPosition.x >> 10) + clutPosition.y + (clutReference.type == .Gradient ? 16 : 1));

				if (blinkerTime < 30 &&
					(selectedTextureIndex > -1 && clutReference.category == .Terrain && clutReference.references.Contains(selectedTextureIndex) ||
					selectedSpriteIndex > -1 && clutReference.category == .Sprite && clutReference.references.Contains(selectedSpriteIndex))
				) {

					DrawUtilities.Rect(clutRect, .(255,0,0,64));

					clutRect.left -= 2;
					clutRect.top -= 2;
					clutRect.right += 2;
					clutRect.bottom += 2;

					Renderer.DrawLine(.(clutRect.left, clutRect.top, 0), .(clutRect.right, clutRect.top, 0), .(255,255,255), .(255,255,255));
					Renderer.DrawLine(.(clutRect.left, clutRect.bottom, 0), .(clutRect.right, clutRect.bottom, 0), .(255,255,255), .(255,255,255));
					Renderer.DrawLine(.(clutRect.left, clutRect.top, 0), .(clutRect.left, clutRect.bottom, 0), .(255,255,255), .(255,255,255));
					Renderer.DrawLine(.(clutRect.right, clutRect.top, 0), .(clutRect.right, clutRect.bottom, 0), .(255,255,255), .(255,255,255));
				}
			}

			if (hoveredTextureIndex > -1) {
				let quad = Terrain.textures[hoveredTextureIndex];

				let partialUVs = quad.GetVramPartialUV();
				let quadStart = UVToScreen(partialUVs.left, partialUVs.leftY);

				let clutPosition = quad.GetCLUTCoordinates();
				let clutStart = PixelToScreen(clutPosition.x, (clutPosition.x >> 10) + clutPosition.y);

				Renderer.DrawLine(.(quadStart.x, quadStart.y, 0), .(clutStart.x, clutStart.y, 0), .(64,64,64), .(64,64,64));
			}

			if (Emulator.installment == .RiptosRage) {
				for (let spriteSetIndex < textureSprites.Count) {
					let sprite = textureSprites[spriteSetIndex];

					for (let frame in sprite.frames) {
						Rect quadRect;
						quadRect.start = UVToScreen(0.5f + (float)frame.x / (1024 * 4), 0.5f + (float)frame.y / 512);
						quadRect.end = UVToScreen(0.5f + (float)((int)frame.x + sprite.width) / (1024 * 4), 0.5f + (float)((int)frame.y + sprite.height) / 512);

						Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.right, quadRect.top, 0), .(64,64,64), .(64,64,64));
						Renderer.DrawLine(.(quadRect.left, quadRect.bottom, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,64), .(64,64,64));
						Renderer.DrawLine(.(quadRect.left, quadRect.top, 0), .(quadRect.left, quadRect.bottom, 0), .(64,64,64), .(64,64,64));
						Renderer.DrawLine(.(quadRect.right, quadRect.top, 0), .(quadRect.right, quadRect.bottom, 0), .(64,64,64), .(64,64,64));

						if (blinkerTime < 30 && selectedCLUTIndex > -1 && cluts[selectedCLUTIndex].category == .Sprite && cluts[selectedCLUTIndex].references.FindIndex(scope (x) => x >= sprite.start && x < sprite.start + sprite.frames.Count) > -1) {
							DrawUtilities.Rect(quadRect, .(255,0,0,64));
						}
					}
				}
			}

			if (hoveredSpriteIndex > -1) {
				if (Emulator.installment == .RiptosRage) {
					let spriteSetIndex = textureSprites.FindIndex(scope (x) => hoveredSpriteIndex >= x.start && hoveredSpriteIndex < x.start + x.frames.Count);
					let spriteSet = textureSprites[spriteSetIndex];
					let frame = spriteSet.frames[hoveredSpriteIndex - spriteSet.start];

					let quadStart = PixelToScreen(frame.x / 4 + 512, frame.y + 256);
					let clutStart = PixelToScreen((frame.clutX & 3) * 16 + 512, frame.clutY + 256);

					Renderer.DrawLine(.(quadStart.x, quadStart.y, 0), .(clutStart.x, clutStart.y, 0), .(64,64,64), .(64,64,64));
				} else {
					let quad = textureSprites3[hoveredSpriteIndex];

					let partialUVs = quad.GetVramPartialUV();
					let quadStart = UVToScreen(partialUVs.left, partialUVs.leftY);

					let clutPosition = quad.GetCLUTCoordinates();
					let clutStart = PixelToScreen(clutPosition.x, (clutPosition.x >> 10) + clutPosition.y);

					Renderer.DrawLine(.(quadStart.x, quadStart.y, 0), .(clutStart.x, clutStart.y, 0), .(64,64,64), .(64,64,64));
				}
			}

			if (hoveredCLUTIndex > -1) {
				let clutReference = cluts[hoveredCLUTIndex];

				(int x, int y) clutPosition = ((clutReference.location & 0x3f) << 4, clutReference.location >> 6);
				let clutStart = PixelToScreen(clutPosition.x, (clutPosition.x >> 10) + clutPosition.y);

				switch (clutReference.category) {
					case .Terrain: {
						for (let quadIndex in clutReference.references) {
							let quad = Terrain.textures[quadIndex];

							let partialUVs = quad.GetVramPartialUV();
							let quadStart = UVToScreen(partialUVs.left, partialUVs.leftY);

							Renderer.DrawLine(.(quadStart.x, quadStart.y, 0), .(clutStart.x, clutStart.y, 0), .(64,64,64), .(64,64,64));
						}
					}
					case .Sprite: {
						switch (Emulator.installment) {
							case .RiptosRage:
								for (let spriteIndex in clutReference.references) {
									let spriteSetIndex = textureSprites.FindIndex(scope (x) => spriteIndex >= x.start && spriteIndex < x.start + x.frames.Count);
									let spriteSet = textureSprites[spriteSetIndex];
									let frame = spriteSet.frames[spriteIndex - spriteSet.start];

									let quadStart = UVToScreen(0.5f + (float)frame.x / (1024 * 4), 0.5f + (float)frame.y / 512);

									Renderer.DrawLine(.(quadStart.x, quadStart.y, 0), .(clutStart.x, clutStart.y, 0), .(64,64,64), .(64,64,64));
								}

							case .YearOfTheDragon:
								for (let spriteIndex in clutReference.references) {
									let spriteSet = textureSprites3[spriteIndex];

									let partialUVs = spriteSet.GetVramPartialUV();
									let quadStart = UVToScreen(partialUVs.left, partialUVs.leftY);

									Renderer.DrawLine(.(quadStart.x, quadStart.y, 0), .(clutStart.x, clutStart.y, 0), .(64,64,64), .(64,64,64));
								}
							default:
						}
					}
					case .Object:
				}
			}


			if (blinkerTime < 30) {
				if (selectedTextureIndex > -1) {
					let quad = Terrain.textures[selectedTextureIndex];
					let partialUVs = quad.GetVramPartialUV();

					Rect quadRect;
					quadRect.start = UVToScreen(partialUVs.left, partialUVs.leftY);
					quadRect.end = UVToScreen(partialUVs.right, partialUVs.rightY);

					DrawUtilities.Rect(quadRect, .(255,255,255,64));
				}

				if (selectedSpriteIndex > -1) {
					if (Emulator.installment == .RiptosRage) {
						let spriteSetIndex = textureSprites.FindIndex(scope (x) => selectedSpriteIndex >= x.start && selectedSpriteIndex < x.start + x.frames.Count);
						let spriteSet = textureSprites[spriteSetIndex];
						let frame = spriteSet.frames[selectedSpriteIndex - spriteSet.start];

						Rect quadRect;
						quadRect.start = UVToScreen(0.5f + (float)frame.x / (1024 * 4), 0.5f + (float)frame.y / 512);
						quadRect.end = UVToScreen(0.5f + (float)((int)frame.x + spriteSet.width) / (1024 * 4), 0.5f + (float)((int)frame.y + spriteSet.height) / 512);

						DrawUtilities.Rect(quadRect, .(255,255,255,64));
					} else {
						let quad = textureSprites3[selectedSpriteIndex];
						let partialUVs = quad.GetVramPartialUV();

						Rect quadRect;
						quadRect.start = UVToScreen(partialUVs.left, partialUVs.leftY);
						quadRect.end = UVToScreen(partialUVs.right, partialUVs.rightY);

						DrawUtilities.Rect(quadRect, .(255,255,255,64));
					}
				}

				if (selectedCLUTIndex > -1) {
					let clutReference = cluts[selectedCLUTIndex];
					(int x, int y) clutPosition = ((clutReference.location & 0x3f) << 4, clutReference.location >> 6);

					Rect rect;
					rect.start = PixelToScreen(clutPosition.x, (clutPosition.x >> 10) + clutPosition.y);
					rect.end = PixelToScreen(clutPosition.x + clutReference.width, (clutPosition.x >> 10) + clutPosition.y + (clutReference.type == .Gradient ? 16 : 1));

					DrawUtilities.Rect(rect, .(255,255,255,64));

					rect.left -= 2;
					rect.top -= 2;
					rect.right += 2;
					rect.bottom += 2;

					Renderer.DrawLine(.(rect.left, rect.top, 0), .(rect.right, rect.top, 0), .(255,255,255), .(255,255,255));
					Renderer.DrawLine(.(rect.left, rect.bottom, 0), .(rect.right, rect.bottom, 0), .(255,255,255), .(255,255,255));
					Renderer.DrawLine(.(rect.left, rect.top, 0), .(rect.left, rect.bottom, 0), .(255,255,255), .(255,255,255));
					Renderer.DrawLine(.(rect.right, rect.top, 0), .(rect.right, rect.bottom, 0), .(255,255,255), .(255,255,255));
				}
			}

			if (clickMode != .Normal) {
				String text = clickMode == .Export ? "Export" : "Alter";

				Rect bgRect;
				bgRect.start = WindowApp.mousePosition + .(16,16);
				bgRect.end = bgRect.start + .(WindowApp.bitmapFont.characterWidth * text.Length, WindowApp.bitmapFont.characterHeight);
				DrawUtilities.Rect(bgRect, .(0,0,0,128));
				WindowApp.bitmapFont.Print(text, bgRect.start + .(0,3), .(255,255,255));
			}

			WindowApp.bitmapFont.Print(scope String() .. AppendF("<{},{}>", (int)testPosition.x, (int)testPosition.y), .Zero, .(255,255,255));
			WindowApp.bitmapFont.Print(scope String() .. AppendF("T-page {}", hoveredTexturePage), .(0, WindowApp.bitmapFont.characterHeight), .(255,255,255));

			if (!spritesDecoded) {
				DrawLoadingOverlay();
			}
		}

		void OnSceneChanged() {
			for (let clutReference in cluts) {
				delete clutReference.references;
			}
			cluts.Clear();

			for (let textureIndex in Terrain.usedTextureIndices) {
				let quadCount = Emulator.installment == .SpyroTheDragon ? 21 : 6;

				for (let quadIndex < quadCount) {
					let i = textureIndex * quadCount + quadIndex;
					let quad = Terrain.textures[i];
					let referenceIndex = cluts.FindIndex(scope (x) => x.category == .Terrain && x.type == (quadIndex < (Emulator.installment == .SpyroTheDragon ? 1 : 2) ? .Gradient : .Normal) && x.location == quad.clut);

					if (referenceIndex == -1) {
						CLUTReference clutReference = ?;
						clutReference.category = .Terrain;
						clutReference.type = quadIndex < (Emulator.installment == .SpyroTheDragon ? 1 : 2) ? .Gradient : .Normal;
						clutReference.location = quad.clut;
						clutReference.width = (quad.texturePage & 0x80 > 0) ? 256 : 16;
						clutReference.references = new .();

						clutReference.references.Add(i);
						cluts.Add(clutReference);
					} else {
						cluts[referenceIndex].references.Add(i);
					}
				}
			}

			switch (Emulator.installment) {
				case .RiptosRage: {
					DeleteAndClearItems!(textureSprites);

					textureSprites.Add(new .(0, 0, 10)); // Numbers
					textureSprites.Add(new .(2, 10, 1)); // Forward Slash

					textureSprites.Add(new .(1, 11, 6)); // Gem
					textureSprites.Add(new .(1, 19, 3)); // Spirit

					textureSprites.Add(new .(2, 0x1d, 1)); // Colon
					textureSprites.Add(new .(2, 0x1e, 1)); // Period

					textureSprites.Add(new .(5, 0x16, 1)); // Power Bar Top
					textureSprites.Add(new .(6, 0x1a, 1)); // Power Icon BG
					textureSprites.Add(new .(7, 0x1b, 1)); // Power Icon FG

					textureSprites.Add(new .(5, 0x17, 1)); // Power Bar Mid
					textureSprites.Add(new .(5, 0x18, 1)); // Power Bar Bottom
					textureSprites.Add(new .(5, 0x19, 1)); // Power Bar Mid Lit

					textureSprites.Add(new .(11, 0x24, 4)); // Rounded Corners

					textureSprites.Add(new .(1, 0x1c, 1)); // Reticle Circle

					textureSprites.Add(new .(9, 0x1f, 1)); // Spyro Head
					textureSprites.Add(new .(10, 0x20, 4)); // Spyro Eyes

					textureSprites.Add(new .(4, 0x57, 1)); // Map

					textureSprites.Add(new .(1, 0x37, 8)); // Objective 1
					textureSprites.Add(new .(1, 0x3f, 8)); // Objective 2
					/*textureSprites.Add(new .(1, 0x47, 8)); // Objective 3
					textureSprites.Add(new .(1, 0x4f, 8)); // Objective 4*/

					for (let sprite in textureSprites) {
						for (let frameIndex < sprite.frames.Count) {
							let frame = sprite.frames[frameIndex];
							let clut = (frame.clutX & 3) + ((int)frame.clutY << 6) + 0x4020;
							let referenceIndex = cluts.FindIndex(scope (x) => x.category == .Sprite && x.type == .Normal && x.location == clut);

							if (referenceIndex == -1) {
								CLUTReference clutReference = ?;
								clutReference.category = .Sprite;
								clutReference.type = .Normal;
								clutReference.location = clut;
								clutReference.width = 16;
								clutReference.references = new .();

								clutReference.references.Add(sprite.start + frameIndex);
								cluts.Add(clutReference);
							} else {
								cluts[referenceIndex].references.Add(sprite.start + frameIndex);
							}
						}
					}
				}
				case .YearOfTheDragon: {
					Emulator.Address<TextureQuad> spriteArrayPointer = ?;
					Emulator.ReadFromRAM((.)0x8006c868, &spriteArrayPointer, 4);
					spriteArrayPointer.ReadArray(&textureSprites3[0], 45);

					for (let i < textureSprites3.Count) {
						let sprite = textureSprites3[i];
						let referenceIndex = cluts.FindIndex(scope (x) => x.category == .Sprite && x.type == .Normal && x.location == sprite.clut);

						if (referenceIndex == -1) {
							CLUTReference clutReference = ?;
							clutReference.category = .Sprite;
							clutReference.type = .Normal;
							clutReference.location = sprite.clut;
							clutReference.width = 16;
							clutReference.references = new .();

							clutReference.references.Add(i);
							cluts.Add(clutReference);
						} else {
							cluts[referenceIndex].references.Add(i);
						}
					}
				}
				default:
			}

			if (Emulator.installment != .SpyroTheDragon) {
				SpyroFont.Init();
			}
		}

		void OnNewSnapshot() {
			spritesDecoded = false;
			hoveredTextureIndex = hoveredSpriteIndex = -1;
		}

		public override bool OnEvent(SDL2.SDL.Event event) {
			switch (event.type) {
				case .MouseButtonDown : {
					if (event.button.button == 1) {
						switch (clickMode) {
							case .Normal: {
								blinkerTime = 0;
								selectedTextureIndex = hoveredTextureIndex;
								selectedCLUTIndex = hoveredCLUTIndex;
								selectedSpriteIndex = hoveredSpriteIndex;
							}
							case .Export: Export();
							case .Alter: Alter();
						}
					}
					if (event.button.button == 3) {
						panning = true;
					}
				}
				case .MouseMotion : {
					if (panning) {
						var translationX = event.motion.xrel / scale;
						var translationY = event.motion.yrel / scale;

						viewPosition.x -= translationX;
						viewPosition.y -= translationY;

						vramOrigin.x = WindowApp.width / 2 - viewPosition.x * scale;
						vramOrigin.y = WindowApp.height / 2 - viewPosition.y * scale;
					} else {
						testPosition.x = ((WindowApp.mousePosition.x - WindowApp.width / 2) / scale + viewPosition.x) / (expand ? 4 : 1) + (expand ? 512 : 0);
						testPosition.y = (WindowApp.mousePosition.y - WindowApp.height / 2) / scale + viewPosition.y;

						if (testPosition.x > 0 && testPosition.x < 1024 && testPosition.y > 0 && testPosition.y < 512) {
							hoveredTexturePage = (.)(testPosition.x / 64) + (.)(testPosition.y / 256) * 16;
						}

						hoveredTextureIndex = -1;
						let quadCount = Emulator.installment == .SpyroTheDragon ? 21 : 6;
						for (let textureIndex in Terrain.usedTextureIndices) {
							for (let quadIndex < quadCount) {
								let i = textureIndex * quadCount + quadIndex;
								let quad = Terrain.textures[i];

								let pageIndex = quad.GetTPageIndex();
								let bitMode = (quad.texturePage & 0x80 > 0) ? 2 : 4;
								Vector2 localTestPosition = .(testPosition.x - (pageIndex & 0xf) * 64, testPosition.y - (pageIndex >> 4 << 8));
								let rightSkewAdjusted = Emulator.installment == .SpyroTheDragon ? quad.rightSkew + 0x1f : quad.rightSkew;

								if (localTestPosition.x > quad.left / bitMode && localTestPosition.x <= ((int)quad.right + 1) / bitMode &&
									localTestPosition.y > quad.leftSkew && localTestPosition.y <= (int)rightSkewAdjusted + 1) {

									hoveredTextureIndex = i;
									break;
								}
							}

							if (hoveredTextureIndex > -1) {
								break;
							}
						}

						hoveredSpriteIndex = -1;
						for (let spriteSetIndex < textureSprites.Count) {
							let spriteSet = textureSprites[spriteSetIndex];
							for (let frameIndex < spriteSet.frames.Count) {
								let frame = spriteSet.frames[frameIndex];
								Vector2 localTestPosition = .(testPosition.x - 512, testPosition.y - 256);

								if (localTestPosition.x > frame.x / 4 && localTestPosition.x <= ((int)frame.x + spriteSet.width) / 4 &&
									localTestPosition.y > frame.y && localTestPosition.y <= ((int)frame.y + spriteSet.height)) {

									hoveredSpriteIndex = spriteSet.start + frameIndex;
									break;
								}

								if (hoveredSpriteIndex > -1) {
									break;
								}
							}
						}

						for (let spriteIndex < textureSprites3.Count) {
							let quad = textureSprites3[spriteIndex];
							let pageIndex = quad.GetTPageIndex();
							let bitMode = (quad.texturePage & 0x80 > 0) ? 2 : 4;
							Vector2 localTestPosition = .(testPosition.x - (pageIndex & 0xf) * 64, testPosition.y - (pageIndex >> 4 << 8));
							let rightSkewAdjusted = Emulator.installment == .SpyroTheDragon ? quad.rightSkew + 0x1f : quad.rightSkew;

							if (localTestPosition.x > quad.left / bitMode && localTestPosition.x <= ((int)quad.right + 1) / bitMode &&
								localTestPosition.y > quad.leftSkew && localTestPosition.y <= (int)rightSkewAdjusted + 1) {

								hoveredSpriteIndex = spriteIndex;
								break;
							}
						}

						hoveredCLUTIndex = -1;
						for (let clutIndex < cluts.Count) {
							let clutReference = cluts[clutIndex];
							(int x, int y) clutPosition = ((clutReference.location & 0x3f) << 4, clutReference.location >> 6);

							let left = clutPosition.x & 0x3ff;
							let right = left + clutReference.width;
							let top = (clutPosition.x >> 10) + clutPosition.y;
							let bottom = top + (clutReference.type == .Gradient ? 16 : 1);

							if (testPosition.x > left && testPosition.x <= right &&
								testPosition.y > top && testPosition.y <= bottom) {

								hoveredCLUTIndex = clutIndex;
								break;
							}

							if (hoveredTextureIndex > -1) {
								break;
							}
						}
					}
				}
				case .MouseButtonUp : {
					if (event.button.button == 3) {
						panning = false;
					}
				}
				case .MouseWheel : {
					scaleMagnitude = Math.Round((scaleMagnitude + 0.1f * (.)event.wheel.y) * 10) / 10;
				 	scale = Math.Pow(2, scaleMagnitude);

					vramOrigin.x = WindowApp.width / 2 - viewPosition.x * scale;
					vramOrigin.y = WindowApp.height / 2 - viewPosition.y * scale;
				}
				case .KeyDown : {
					switch (event.key.keysym.scancode) {
						case .LCtrl: clickMode = .Export;
						case .LAlt: clickMode = .Alter;
						case .V: windowApp.GoToState<ViewerState>();
						case .Key0: ResetView();
						case .Key1: ToggleExpandedView();
						case .Key9: ExportVRAM();
						default: return false;
					}
				}
				case .KeyUp : {
					switch (event.key.keysym.scancode) {
						case .LCtrl, .LAlt: clickMode = .Normal;
						default: return false;
					}
				}
				default: return false;
			}
			return true;
		}

		void ResetView() {
			let pixelWidth = expand ? 4 : 1;
			let width = (expand ? 512 : 1024) * pixelWidth;
			Vector2 size = .(width, 512);

			viewPosition.x = size.x / 2;
			viewPosition.y = size.y / 2;

			vramOrigin.x = WindowApp.width / 2 - viewPosition.x * scale;
			vramOrigin.y = WindowApp.height / 2 - viewPosition.y * scale;
		}

		void ToggleExpandedView() {
			expand = !expand;

			if (expand) {
				if (viewPosition.x > 512) {
					viewPosition.x = (viewPosition.x - 512) * 4;
				}
			} else {
				viewPosition.x = viewPosition.x / 4 + 512;
			}

			vramOrigin.x = WindowApp.width / 2 - viewPosition.x * scale;
			vramOrigin.y = WindowApp.height / 2 - viewPosition.y * scale;
		}

		void ExportVRAM() {
			let dialog = new SaveFileDialog();
			dialog.FileName = "vram_decoded";
			dialog.SetFilter("Bitmap image (*.bmp)|*.bmp|All files (*.*)|*.*");
			dialog.OverwritePrompt = true;
			dialog.CheckFileExists = true;
			dialog.AddExtension = true;
			dialog.DefaultExt = "bmp";

			switch (dialog.ShowDialog()) {
				case .Ok(let val):
					if (val == .OK) {
						VRAM.Export(dialog.FileNames[0]);
					}
				case .Err:
			}

			delete dialog;
		}

		[Inline]
		Vector2 PixelToScreen(float x, float y) {
			return UVToScreen(.(x / 1024, y / 512));
		}

		[Inline]
		Vector2 PixelToScreen(Vector2 pixelPos) {
			return PixelToScreen(pixelPos.x, pixelPos.y);
		}

		[Inline]
		Vector2 UVToScreen(float x, float y) {
			return .(vramOrigin.x + (x - (expand ? 0.5f : 0)) * vramSize.width * (expand ? 2 : 1) * scale, vramOrigin.y + y * vramSize.height * scale);
		}

		[Inline]
		Vector2 UVToScreen(Vector2 uvPos) {
			return UVToScreen(uvPos.x, uvPos.y);
		}

		void Export() {
			if (hoveredTextureIndex > -1) {
				let dialog = scope System.IO.SaveFileDialog();
				dialog.FileName = scope String() .. AppendF("T{}", hoveredTextureIndex);
				dialog.SetFilter("Bitmap image (*.bmp)|*.bmp|All files (*.*)|*.*");
				dialog.OverwritePrompt = true;
				dialog.CheckFileExists = true;
				dialog.AddExtension = true;
				dialog.DefaultExt = "bmp";

				switch (dialog.ShowDialog()) {
					case .Ok(let val):
						if (val == .OK) {
							let quad = Terrain.textures[hoveredTextureIndex];
							VRAM.Export(dialog.FileNames[0], quad.left, quad.leftSkew, quad.width, quad.height, (quad.texturePage & 0x80) > 0 ? 8 : 4, quad.texturePage);
						}
					case .Err:
				}
			}

			if (hoveredSpriteIndex > -1) {
				let dialog = scope System.IO.SaveFileDialog();
				dialog.FileName = scope String() .. AppendF("S{}", hoveredSpriteIndex);
				dialog.SetFilter("Bitmap image (*.bmp)|*.bmp|All files (*.*)|*.*");
				dialog.OverwritePrompt = true;
				dialog.CheckFileExists = true;
				dialog.AddExtension = true;
				dialog.DefaultExt = "bmp";

				switch (dialog.ShowDialog()) {
					case .Ok(let val):
						if (val == .OK) {
							if (Emulator.installment == .RiptosRage) {
								let spriteSetIndex = textureSprites.FindIndex(scope (x) => hoveredSpriteIndex >= x.start && hoveredSpriteIndex < x.start + x.frames.Count);
								let spriteSet = textureSprites[spriteSetIndex];
								let frame = spriteSet.frames[hoveredSpriteIndex - spriteSet.start];

								VRAM.Export(dialog.FileNames[0], frame.x, frame.y, spriteSet.width, spriteSet.height, 4, 0x18);
							} else {
								let quad = textureSprites3[hoveredSpriteIndex];
								VRAM.Export(dialog.FileNames[0], quad.left, quad.leftSkew, quad.width, quad.height, (quad.texturePage & 0x80) > 0 ? 8 : 4, quad.texturePage);
							}
						}
					case .Err:
				}
			}
		}

		void Alter() {
			if (hoveredTextureIndex == -1 && hoveredSpriteIndex == -1 && hoveredCLUTIndex == -1) {
				return;
			}

			let dialog = scope OpenFileDialog();
			dialog.SetFilter("Bitmap image (*.bmp)|*.bmp|All files (*.*)|*.*");
			dialog.CheckFileExists = true;
			dialog.Multiselect = true;

			switch (dialog.ShowDialog()) {
				case .Ok(let val):
					if (val == .OK) {
						let file = dialog.FileNames[0];

						let surface = SDLImage.Load(file);
						if (surface != null) {
							if (hoveredTextureIndex > -1) {
								let quad = Terrain.textures[hoveredTextureIndex];
								AlterVRAM(surface, quad.texturePage, quad.left, quad.leftSkew, quad.width, quad.height, (quad.texturePage & 0x80) > 0 ? 8 : 4, quad.clut);
							}

							if (hoveredSpriteIndex > -1) {
								if (Emulator.installment == .RiptosRage) {
									let spriteSetIndex = textureSprites.FindIndex(scope (x) => hoveredSpriteIndex >= x.start && hoveredSpriteIndex < x.start + x.frames.Count);
									let spriteSet = textureSprites[spriteSetIndex];

									let spritesToReplace = Math.Min(dialog.FileNames.Count, spriteSet.frames.Count - (hoveredSpriteIndex - spriteSet.start));
									for (let fileSpriteIndex < spritesToReplace) {
										let sprite = spriteSet.frames[hoveredSpriteIndex - spriteSet.start + fileSpriteIndex];

										let fileSprite = dialog.FileNames[fileSpriteIndex];
										let surfaceSprite = SDLImage.Load(fileSprite);

										AlterVRAM(surfaceSprite, 0x18, sprite.x, sprite.y, spriteSet.width, spriteSet.height, 4, (sprite.clutX & 3) + ((int)sprite.clutY << 6) + 0x4020);

										SDL.FreeSurface(surfaceSprite);
									}
								} else {
									let spritesToReplace = Math.Min(dialog.FileNames.Count, textureSprites3.Count - hoveredSpriteIndex);
									for (let fileSpriteIndex < spritesToReplace) {
										let sprite = textureSprites3[hoveredSpriteIndex + fileSpriteIndex];

										let fileSprite = dialog.FileNames[fileSpriteIndex];
										let surfaceSprite = SDLImage.Load(fileSprite);

										AlterVRAM(surfaceSprite, sprite.texturePage, sprite.left, sprite.leftSkew, sprite.width, sprite.height, (sprite.texturePage & 0x80) > 0 ? 8 : 4, sprite.clut);

										SDL.FreeSurface(surfaceSprite);
									}
								}
							}

							if (hoveredCLUTIndex > -1) {
								let clutReference = cluts[hoveredCLUTIndex];
								(int x, int y) clutPosition = ((clutReference.location & 0x3f) << 4, clutReference.location >> 6);

								uint16[] clutTable = ?;
								switch (clutReference.type) {
									case .Normal:
										clutTable = GenerateCLUT!(surface);
										VRAM.Write(clutTable, clutPosition.x, clutPosition.y, surface.w, 1);

									case .Gradient:
										clutTable = GenerateCLUT!(surface, 16);
										VRAM.Write(clutTable, clutPosition.x, clutPosition.y, surface.w, 16);
								}

								switch (clutReference.category) {
									case .Terrain:
										for (let reference in cluts[hoveredCLUTIndex].references) {
											let quad = Terrain.textures[reference];
											VRAM.Decode(quad.texturePage, quad.left, quad.leftSkew, quad.width, quad.height, (quad.texturePage & 0x80) > 0 ? 8 : 4, clutReference.location);
										}

									case .Sprite:
										if (Emulator.installment == .RiptosRage) {
											for (let reference in cluts[hoveredCLUTIndex].references) {
												let spriteSetIndex = textureSprites.FindIndex(scope (x) => reference >= x.start && reference < x.start + x.frames.Count);
												let spriteSet = textureSprites[spriteSetIndex];
												let frame = spriteSet.frames[reference - spriteSet.start];

												VRAM.Decode(0x18, frame.x, frame.y, spriteSet.width, spriteSet.height, 4, clutReference.location);
											}
										} else {
											for (let reference in cluts[hoveredCLUTIndex].references) {
												let sprite = textureSprites3[reference];
												VRAM.Decode(sprite.texturePage, sprite.left, sprite.leftSkew, sprite.width, sprite.height, 4, clutReference.location);
											}
										}

									default:
								}
							}
						}

						SDL.FreeSurface(surface);
					}
				case .Err:
			}
		}

		void AlterVRAM(SDL.Surface* surface, int texturePage, int textureX, int textureY, int textureWidth, int textureHeight, int bitmode, int clut) {
			let subPixels = 16 / bitmode;
			let clutPosition = clut << 4;
			let colorCount = 1 << bitmode;

			let width = Math.Min(surface.w, textureWidth);
			let height = Math.Min(surface.h, textureHeight);
			let quadWidth = (int)Math.Ceiling((float)width / subPixels);
			let quadPixels = scope uint16[quadWidth * height];

			for (let x < width) {
				for (let y < height) {
					let pixel = GetPixelFromSurface!(surface, x + y * width);

					uint16 i = 0;
					var closest = float.PositiveInfinity;

					for (let c < colorCount) {
						let clutSample = VRAM.snapshot[clutPosition + c];

						if ((GetAlphaValue!(pixel, surface.format.Amask) > 0.5f) == (clutSample >> 15 < 1)) {
							let dr = GetChannelValue!(pixel, surface.format.Rmask) - (float)(clutSample & 0x1f) / 31;
							let dg = GetChannelValue!(pixel, surface.format.Gmask) - (float)(clutSample >> 5 & 0x1f) / 31;
							let db = GetChannelValue!(pixel, surface.format.Bmask) - (float)(clutSample >> 10 & 0x1f) / 31;
							let distance = dr * dr + dg * dg + db * db;

							if (distance < closest) {
								i = (.)c;
								closest = distance;
							}
						}
					}

					let p = x % subPixels;
					quadPixels[x / subPixels + y * quadWidth] |= i << (p * subPixels);
				}
			}

			VRAM.Write(quadPixels, ((texturePage & 0xf) * 64 + textureX / subPixels), ((texturePage >> 4 & 0x1) * 256 + textureY), quadWidth, height);
			VRAM.Decode(texturePage, textureX, textureY, width, height, subPixels, clut);
		}

		mixin GenerateCLUT(SDL.Surface* surface) {
			let clutTable = scope:mixin uint16[surface.w];

			for (let x < surface.w) {
				let pixel = GetPixelFromSurface!(surface, x);

				let r = (uint16)(GetChannelValue!(pixel, surface.format.Rmask) * 31);
				let g = (uint16)(GetChannelValue!(pixel, surface.format.Gmask) * 31);
				let b = (uint16)(GetChannelValue!(pixel, surface.format.Bmask) * 31);

				clutTable[x] = r | g << 5 | b << 10 | (GetAlphaValue!(pixel, surface.format.Amask) > 0.5f ? 0 : 0x8000);
			}

			clutTable
		}

		mixin GenerateCLUT(SDL.Surface* surface, int height, bool black = false) {
			let clutTable = scope:mixin uint16[surface.w * 16];
			let colorLevel = black ? 0 : 16;

			for (let x < surface.w) {
				let pixel = GetPixelFromSurface!(surface, x);

				for (let y < height) {
					uint16 outR, outG, outB = ?;
					float inR = GetChannelValue!(pixel, surface.format.Rmask);
					float inG = GetChannelValue!(pixel, surface.format.Rmask);
					float inB = GetChannelValue!(pixel, surface.format.Rmask);

					if (inR == 0 && inG == 0 && inB == 0) {
						// Extend the black colored pixels
						outR = outG = outB = 0;
					} else {
						// Fade to the desired color
						let fadeAmount = (float)y / height;

						outR = (uint16)Math.Lerp(GetChannelValue!(pixel, surface.format.Rmask) * 31, colorLevel, fadeAmount);
						outG = (uint16)Math.Lerp(GetChannelValue!(pixel, surface.format.Gmask) * 31, colorLevel, fadeAmount);
					 	outB = (uint16)Math.Lerp(GetChannelValue!(pixel, surface.format.Bmask) * 31, colorLevel, fadeAmount);
					}

					clutTable[x + y * surface.w] = outR | outG << 5 | outB << 10 | (GetAlphaValue!(pixel, surface.format.Amask) > 0.5f ? 0 : 0x8000);
				}
			}

			clutTable
		}

		mixin GetPixelFromSurface(SDL.Surface* surface, int pixelIndex) {
			*(uint32*)(&((uint8*)surface.pixels)[pixelIndex * surface.format.bytesPerPixel])
		}

		mixin GetChannelValue(uint32 pixel, uint32 mask) {
			mask > 0 ? (float)(pixel & mask) / mask : 0
		}

		mixin GetAlphaValue(uint32 pixel, uint32 alphaMask) {
			alphaMask > 0 ? (float)(pixel & alphaMask) / alphaMask : 1
		}

		void Decode() {
			if (!Terrain.decoded) {
				Terrain.Decode();
			}

			if (!spritesDecoded) {
				if (Emulator.installment == .RiptosRage) {
					for (let sprite in textureSprites) {
						sprite.Decode();
					}
				} else {
					for (let sprite in textureSprites3) {
						sprite.Decode();
					}
				}

				if (Emulator.installment != .SpyroTheDragon) {
					SpyroFont.Decode();
				}

				spritesDecoded = true;
			}
		}

		void DrawLoadingOverlay() {
			// Darken everything
			DrawUtilities.Rect(0,WindowApp.height,0,WindowApp.width, .(0,0,0,192));

			let message = "Waiting for Unpause...";
			var halfWidth = Math.Round(WindowApp.font.CalculateWidth(message) / 2);
			var baseline = (WindowApp.height - WindowApp.font.height) / 2;
			let middleWindow = WindowApp.width / 2;
			WindowApp.font.Print(message, .(middleWindow - halfWidth, baseline), .(255,255,255));
		}
	}
}
