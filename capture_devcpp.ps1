Add-Type -Path 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Drawing.dll'
Add-Type -ReferencedAssemblies 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Drawing.dll' @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class DevCppCap {
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
 [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr hdc);
 [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);
 [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);
 [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr ho);
 [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr hdc);
 [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDc);
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 public static bool Save(IntPtr hwnd,string path){ RECT r; if(!GetWindowRect(hwnd,out r)) return false; int w=Math.Max(1,r.Right-r.Left),h=Math.Max(1,r.Bottom-r.Top); IntPtr desk=GetDC(IntPtr.Zero),mem=CreateCompatibleDC(desk),bmp=CreateCompatibleBitmap(desk,w,h),old=SelectObject(mem,bmp); bool ok=PrintWindow(hwnd,mem,2); using(Bitmap img=Bitmap.FromHbitmap(bmp)){img.Save(path,System.Drawing.Imaging.ImageFormat.Png);} SelectObject(mem,old);DeleteObject(bmp);DeleteDC(mem);ReleaseDC(IntPtr.Zero,desk);return ok; }
}
'@
$out='D:\new-bee\outputs\matrix_chain_222024321062099\devcpp_editor.png'
$p=Get-Process devcpp | Select-Object -First 1
if($p){
 [DevCppCap]::ShowWindow($p.MainWindowHandle,9) | Out-Null
 [DevCppCap]::MoveWindow($p.MainWindowHandle,40,40,1200,800,$true) | Out-Null
 [DevCppCap]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
 Start-Sleep -Milliseconds 800
 $r=New-Object DevCppCap+RECT; [DevCppCap]::GetWindowRect($p.MainWindowHandle,[ref]$r) | Out-Null
 $w=$r.Right-$r.Left; $h=$r.Bottom-$r.Top
 $bmp=New-Object System.Drawing.Bitmap($w,$h); $g=[System.Drawing.Graphics]::FromImage($bmp)
 $g.CopyFromScreen($r.Left,$r.Top,0,0,[System.Drawing.Size]::new($w,$h)); $bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
 Get-Item $out | Select-Object FullName,Length
}
