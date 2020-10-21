using OpenGL;
using SDL2;
using System;

namespace SpyroScope {
	class Texture {
		public uint textureObjectID;
		public readonly int width;
		public readonly int height;

		public this(String source) {
			let surface = SDLImage.Load(source);
			if (surface != null) {
				width = surface.w;
				height = surface.h;

				GL.glGenTextures(1, &textureObjectID);
				GL.glBindTexture(GL.GL_TEXTURE_2D, textureObjectID);

				uint format = surface.format.Amask == 0 ? GL.GL_RGB : GL.GL_RGBA;

				GL.glTexImage2D(GL.GL_TEXTURE_2D, 0, (.)format, surface.w, surface.h, 0, format, GL.GL_UNSIGNED_BYTE, surface.pixels);
				GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR);
				GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR);
				SDL.FreeSurface(surface);

				GL.glBindTexture(GL.GL_TEXTURE_2D, 0);

				Renderer.CheckForErrors();
			}
		}
		
		public this(int width, int height, uint format, void* data) {
			this.width = width;
			this.height = height;

			GL.glGenTextures(1, &textureObjectID);
			GL.glBindTexture(GL.GL_TEXTURE_2D, textureObjectID);

			GL.glTexImage2D(GL.GL_TEXTURE_2D, 0, (.)format, width, height, 0, format, GL.GL_UNSIGNED_BYTE, data);
			GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR);
			GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR);

			GL.glBindTexture(GL.GL_TEXTURE_2D, 0);

			Renderer.CheckForErrors();
		}

		public this(int width, int height, uint format, uint type, void* data) {
			this.width = width;
			this.height = height;

			GL.glGenTextures(1, &textureObjectID);
			GL.glBindTexture(GL.GL_TEXTURE_2D, textureObjectID);

			GL.glTexImage2D(GL.GL_TEXTURE_2D, 0, (.)format, width, height, 0, format, type, data);
			GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR);
			GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR);

			GL.glBindTexture(GL.GL_TEXTURE_2D, 0);

			Renderer.CheckForErrors();
		}

		public ~this() {
			GL.glDeleteTextures(1, &textureObjectID);
		}

		public void Bind() {
			GL.glBindTexture(GL.GL_TEXTURE_2D, textureObjectID);
		}

		public static void Unbind() {
			GL.glBindTexture(GL.GL_TEXTURE_2D, 0);
		}
	}
}
