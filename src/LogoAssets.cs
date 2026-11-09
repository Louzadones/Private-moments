using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class LogoAssets
{
    // User-approved cleanup: two flat colors, opaque interior and transparent exterior.
    public static void Create(string sourcePath, string destination)
    {
        Directory.CreateDirectory(destination);
        Color wine = ColorTranslator.FromHtml("#590027");
        Color pink = ColorTranslator.FromHtml("#F7A6CE");
        using (Bitmap source = new Bitmap(sourcePath))
        using (Bitmap flat = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb))
        {
            for (int y = 0; y < source.Height; y++)
            for (int x = 0; x < source.Width; x++)
            {
                Color pixel = source.GetPixel(x, y);
                Color fill = pixel.G >= 80 ? pink : wine;
                flat.SetPixel(x, y, Color.FromArgb(pixel.A >= 128 ? 255 : 0, fill));
            }
            flat.Save(Path.Combine(destination, "logo.png"), ImageFormat.Png);
            int[] sizes = {16, 24, 32, 48, 64, 128, 256};
            List<byte[]> frames = new List<byte[]>();
            foreach (int size in sizes)
            using (Bitmap frame = new Bitmap(size, size, PixelFormat.Format32bppArgb))
            {
                using (Graphics graphics = Graphics.FromImage(frame))
                {
                    graphics.CompositingMode = CompositingMode.SourceCopy;
                    graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    using (ImageAttributes attributes = new ImageAttributes())
                    {
                        attributes.SetWrapMode(WrapMode.TileFlipXY);
                        graphics.DrawImage(flat, new Rectangle(0, 0, size, size), 0, 0, flat.Width, flat.Height, GraphicsUnit.Pixel, attributes);
                    }
                }
                using (MemoryStream stream = new MemoryStream())
                {
                    frame.Save(stream, ImageFormat.Png);
                    frames.Add(stream.ToArray());
                }
            }
            using (BinaryWriter writer = new BinaryWriter(File.Create(Path.Combine(destination, "app.ico"))))
            {
                writer.Write((ushort)0); writer.Write((ushort)1); writer.Write((ushort)sizes.Length);
                int offset = 6 + 16 * sizes.Length;
                for (int i = 0; i < sizes.Length; i++)
                {
                    writer.Write((byte)(sizes[i] == 256 ? 0 : sizes[i]));
                    writer.Write((byte)(sizes[i] == 256 ? 0 : sizes[i]));
                    writer.Write((byte)0); writer.Write((byte)0);
                    writer.Write((ushort)1); writer.Write((ushort)32);
                    writer.Write(frames[i].Length); writer.Write(offset);
                    offset += frames[i].Length;
                }
                foreach (byte[] frame in frames) writer.Write(frame);
            }
        }
    }
}
