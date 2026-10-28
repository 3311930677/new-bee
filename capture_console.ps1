Add-Type -Path 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Drawing.dll'
Add-Type -ReferencedAssemblies 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Drawing.dll' @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class WinCap {
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
 [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr hdc);
 [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);
 [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);
 [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr ho);
 [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr hdc);
 [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDc);
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 public static bool Save(IntPtr hwnd,string path){ RECT r; if(!GetWindowRect(hwnd,out r)) return false; int w=r.Right-r.Left,h=r.Bottom-r.Top; IntPtr desk=GetDC(IntPtr.Zero), mem=CreateCompatibleDC(desk), bmp=CreateCompatibleBitmap(desk,w,h), old=SelectObject(mem,bmp); bool ok=PrintWindow(hwnd,mem,2); using(Bitmap img=Bitmap.FromHbitmap(bmp)){img.Save(path,System.Drawing.Imaging.ImageFormat.Png);} SelectObject(mem,old); DeleteObject(bmp); DeleteDC(mem); ReleaseDC(IntPtr.Zero,desk); return ok; }
}
'@
$out='D:\new-bee\outputs\matrix_chain_222024321062099\real_build_run.png'
$p=Get-Process cmd | Where-Object MainWindowTitle -like 'Dev-C++ / MinGW*' | Sort-Object Id -Descending | Select-Object -First 1
if($p){ [WinCap]::Save($p.MainWindowHandle,$out); Get-Item $out | Select-Object FullName,Length }
