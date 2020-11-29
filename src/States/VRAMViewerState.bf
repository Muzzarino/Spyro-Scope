using OpenGL;
using SDL2;
using System;

namespace SpyroScope {
	class VRAMViewerState : WindowState {
		enum RenderMode {
			Raw,
			Decoded
		}
		RenderMode renderMode;

		float scale = 1, scaleMagnitude = 0;
		bool expand;

		(float x, float y) viewPosition, testPosition;
		int hoveredTexturePage, hoveredTextureIndex, hoveredTextureQuadIndex;
		bool panning;

		public override void Enter() {
			/*Emulator.OnSceneChanged = new => OnSceneChanged;
			Emulator.OnSceneChanging = new => OnSceneChanging;*/

			if (Emulator.installment == .RiptosRage) {
				TextureSprite a = ?;
				a = scope .(0, 0, 10); // Numbers
				a.Decode();
				a = scope .(2, 10, 1); // Forward Slash
				a.Decode();
	
				a = scope .(1, 11, 6); // Gem
				a.Decode();
				a = scope .(1, 19, 3); // Spirit
				a.Decode();
	
				a = scope .(2, 0x1d, 1); // Colon
				a.Decode();
				a = scope .(2, 0x1e, 1); // Period
				a.Decode();
	
				a = scope .(5, 0x16, 1); // Power Bar Top
				a.Decode();
				a = scope .(6, 0x1a, 1); // Power Icon BG
				a.Decode();
				a = scope .(7, 0x1b, 1); // Power Icon FG
				a.Decode();
	
				a = scope .(5, 0x17, 1); // Power Bar Mid
				a.Decode();
				a = scope .(5, 0x18, 1); // Power Bar Bottom
				a.Decode();
				a = scope .(5, 0x19, 1); // Power Bar Mid Lit
				a.Decode();
	
				a = scope .(11, 0x24, 4); // Rounded Corners
				a.Decode();
	
				a = scope .(1, 0x1c, 1); // Reticle Circle
				a.Decode();
	
				a = scope .(9, 0x1f, 1); // Spyro Head
				a.Decode();
				a = scope .(10, 0x20, 4); // Spyro Eyes
				a.Decode();

				a = scope .(4, 0x57, 1); // Map
				a.Decode();

				a = scope .(1, 0x37, 8); // Objective 1
				a.Decode();
				a = scope .(1, 0x3f, 8); // Objective 2
				a.Decode();
				/*a = scope .(1, 0x47, 8); // Objective 3
				a.Decode();
				a = scope .(1, 0x4f, 8); // Objective 4
				a.Decode();*/
				
				SpyroFont.Init();
				SpyroFont.Decode();
			}

			OnSceneChanged();
			ResetView();
		}

		public override void Exit() {
			/*delete Emulator.OnSceneChanged;
			delete Emulator.OnSceneChanging;*/


		}

		public override void Update() {
			Terrain.UpdateTextureInfo(false);
		}

		public override void DrawGUI() {
			let pixelWidth = expand ? 4 : 1;
			let width = (expand ? 512 : 1024) * pixelWidth;
			(float x, float y) size = (width, 512);

			(float x, float y) centering = ?;
			centering.x = WindowApp.width / 2;
			centering.y = WindowApp.height / 2;

			float top = centering.y - viewPosition.y * scale;
			float bottom = centering.y + (size.y - viewPosition.y) * scale;
			float left = centering.x - viewPosition.x * scale;
			float right = centering.x + (size.x - viewPosition.x) * scale;
			
			DrawUtilities.Rect(top, bottom, left, right, 0, 1, expand ? 0.5f : 0, 1, VRAM.raw, .(255,255,255));
			DrawUtilities.Rect(top, bottom, left, right, 0, 1, expand ? 0.5f : 0, 1, VRAM.decoded, .(255,255,255));

			WindowApp.bitmapFont.Print(scope String() .. AppendF("<{},{}>", (int)testPosition.x, (int)testPosition.y), .Zero, .(255,255,255));
			WindowApp.bitmapFont.Print(scope String() .. AppendF("T-page {}", hoveredTexturePage), .(0, WindowApp.bitmapFont.characterHeight, 0), .(255,255,255));

			if (expand) {
				size.x *= 2;
			}

			for (let textureIndex in Terrain.usedTextureIndices) {
				TextureQuad* quad = ?;
				int quadCount = ?;
				if (Emulator.installment == .SpyroTheDragon) {
					quad = &Terrain.texturesLODs1[textureIndex].D1;
					quadCount = 5;//21;
				} else {
					quad = &Terrain.texturesLODs[textureIndex].farQuad;
					quadCount = 6;
				}

				for (let quadIndex < quadCount) {
					let partialUVs = quad.GetVramPartialUV();

					float qtop = top + partialUVs.leftY * size.y * scale;
					float qbottom = top + partialUVs.rightY * size.y * scale;
					float qleft = left + (partialUVs.left - (expand ? 0.5f : 0)) * size.x * scale;
					float qright = left + (partialUVs.right - (expand ? 0.5f : 0)) * size.x * scale;

					Renderer.DrawLine(.(qleft, qtop, 0), .(qright, qtop, 0), .(64,64,64), .(64,64,64));
					Renderer.DrawLine(.(qleft, qbottom, 0), .(qright, qbottom, 0), .(64,64,64), .(64,64,64));
					Renderer.DrawLine(.(qleft, qtop, 0), .(qleft, qbottom, 0), .(64,64,64), .(64,64,64));
					Renderer.DrawLine(.(qright, qtop, 0), .(qright, qbottom, 0), .(64,64,64), .(64,64,64));

					let modifiedQuadIndex = quadIndex + (Emulator.installment == .SpyroTheDragon ? 1 : 0);
					switch (modifiedQuadIndex) {
						case 0:
							Renderer.DrawLine(.(qleft + 4, qtop + 4, 0), .(qright - 4, qtop + 4, 0), .(255,64,64), .(255,64,64));
							Renderer.DrawLine(.(qleft + 4, qbottom - 4, 0), .(qright - 4, qbottom - 4, 0), .(255,64,64), .(255,64,64));
							Renderer.DrawLine(.(qleft + 4, qtop + 4, 0), .(qleft + 4, qbottom - 4, 0), .(255,64,64), .(255,64,64));
							Renderer.DrawLine(.(qright - 4, qtop + 4, 0), .(qright - 4, qbottom - 4, 0), .(255,64,64), .(255,64,64));
						case 1:
							Renderer.DrawLine(.(qleft + 2, qtop + 2, 0), .(qright - 2, qtop + 2, 0), .(64,255,64), .(64,255,64));
							Renderer.DrawLine(.(qleft + 2, qbottom - 2, 0), .(qright - 2, qbottom - 2, 0), .(64,255,64), .(64,255,64));
							Renderer.DrawLine(.(qleft + 2, qtop + 2, 0), .(qleft + 2, qbottom - 2, 0), .(64,255,64), .(64,255,64));
							Renderer.DrawLine(.(qright - 2, qtop + 2, 0), .(qright - 2, qbottom - 2, 0), .(64,255,64), .(64,255,64));
						case 2:
							Renderer.DrawLine(.(qleft + 4, qtop + 4, 0), .(qright, qtop + 4, 0), .(64,64,255), .(64,64,255));
							Renderer.DrawLine(.(qleft + 4, qtop + 4, 0), .(qleft + 4, qbottom, 0), .(64,64,255), .(64,64,255));
						case 3:
							Renderer.DrawLine(.(qleft, qtop + 4, 0), .(qright - 4, qtop + 4, 0), .(64,64,255), .(64,64,255));
							Renderer.DrawLine(.(qright - 4, qtop + 4, 0), .(qright - 4, qbottom, 0), .(64,64,255), .(64,64,255));
						case 4:
							Renderer.DrawLine(.(qleft + 4, qbottom - 4, 0), .(qright, qbottom - 4, 0), .(64,64,255), .(64,64,255));
							Renderer.DrawLine(.(qleft + 4, qtop, 0), .(qleft + 4, qbottom - 4, 0), .(64,64,255), .(64,64,255));
						case 5:
							Renderer.DrawLine(.(qleft, qbottom - 4, 0), .(qright - 4, qbottom - 4, 0), .(64,64,255), .(64,64,255));
							Renderer.DrawLine(.(qright - 4, qtop, 0), .(qright - 4, qbottom - 4, 0), .(64,64,255), .(64,64,255));
					}

					quad++;
				}
			}

			if (hoveredTextureIndex > -1) {
				TextureQuad* quad = ?;
				int quadCount = ?;
				if (Emulator.installment == .SpyroTheDragon) {
					quad = &Terrain.texturesLODs1[hoveredTextureIndex].D1;
					quadCount = 5;//21;
				} else {
					quad = &Terrain.texturesLODs[hoveredTextureIndex].farQuad;
					quadCount = 6;
				}
				quad += hoveredTextureQuadIndex;

				let partialUVs = quad.GetVramPartialUV();

				float qtop = top + partialUVs.leftY * size.y * scale;
				float qleft = left + (partialUVs.left - (expand ? 0.5f : 0)) * size.x * scale;

				let clutPosition = quad.GetCLUTCoordinates();
				(float x, float y) clutPositionNormalized = ((float)(clutPosition.x & 0x3ff) / 1024, (float)(clutPosition.x >> 10 + clutPosition.y) / 512);

				float ctop = top + clutPositionNormalized.y * size.y * scale;
				float cleft = left + (clutPositionNormalized.x - (expand ? 0.5f : 0)) * size.x * scale;
				
				Renderer.DrawLine(.(qleft, qtop, 0), .(cleft, ctop, 0), .(64,64,64), .(64,64,64));
			}
		}

		public void OnSceneChanged() {
			//
		}

		public override bool OnEvent(SDL2.SDL.Event event) {
			switch (event.type) {
				case .MouseButtonDown : {
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
					} else {
						(float x, float y) centering = ?;
						centering.x = WindowApp.width / 2;
						centering.y = WindowApp.height / 2;

						testPosition.x = ((WindowApp.mousePosition.x - centering.x) / scale + viewPosition.x) / (expand ? 4 : 1) + (expand ? 512 : 0);
						testPosition.y = (WindowApp.mousePosition.y - centering.y) / scale + viewPosition.y;

						if (testPosition.x > 0 && testPosition.x < 1024 && testPosition.y > 0 && testPosition.y < 512) {
							hoveredTexturePage = (.)(testPosition.x / 64) + (.)(testPosition.y / 256) * 16;
						}
						hoveredTextureIndex = hoveredTextureQuadIndex = -1;

						for (let textureIndex in Terrain.usedTextureIndices) {
							TextureQuad* quad = ?;
							int quadCount = ?;
							if (Emulator.installment == .SpyroTheDragon) {
								quad = &Terrain.texturesLODs1[textureIndex].D1;
								quadCount = 5;//21;
							} else {
								quad = &Terrain.texturesLODs[textureIndex].farQuad;
								quadCount = 6;
							}

							for (let quadIndex < quadCount) {
								let pageIndex = quad.GetTPageIndex();
								let bitMode = (quad.texturePage & 0x80 > 0) ? 2 : 4;
								(float x, float y) localTestPosition = (testPosition.x - (pageIndex & 0xf) * 64, testPosition.y - (pageIndex >> 4 << 8));
								if (localTestPosition.x > quad.left / bitMode && localTestPosition.x < ((int)quad.right + 1) / bitMode &&
									localTestPosition.y > quad.leftSkew && localTestPosition.y < (int)quad.rightSkew + 1) {
									hoveredTextureIndex = textureIndex;
									hoveredTextureQuadIndex = quadIndex;
									break;
								}

								quad++;
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
				}
				case .KeyDown : {
					switch (event.key.keysym.scancode) {
						case .V: windowApp.GoToState<ViewerState>();
						case .Key0: ResetView();
						case .Key1: ToggleExpandedView();
						case .Key9:
							let dialog = new System.IO.SaveFileDialog();
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
						default:
					}
				}
				default: return false;
			}
			return true;
		}

		void ResetView() {
			let pixelWidth = expand ? 4 : 1;
			let width = (expand ? 512 : 1024) * pixelWidth;
			(float x, float y) size = (width, 512);

			viewPosition.x = size.x / 2;
			viewPosition.y = size.y / 2;
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
		}
	}
}
