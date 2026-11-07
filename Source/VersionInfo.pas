unit VersionInfo;

interface

type
  TVersionInfo = class
  public
    class function FileVersion: string; static;
  end;

implementation

uses
  System.SysUtils, Winapi.Windows;

class function TVersionInfo.FileVersion: string;
var
  FileName: string;
  Handle: DWORD;
  VersionInfoSize: DWORD;
  VersionInfoData: TBytes;
  FixedFileInfo: PVSFixedFileInfo;
  FixedFileInfoSize: UINT;
begin
  Result := '';
  FileName := ParamStr(0);
  VersionInfoSize := GetFileVersionInfoSize(PChar(FileName), Handle);
  if VersionInfoSize = 0 then
    Exit;

  SetLength(VersionInfoData, VersionInfoSize);
  if not GetFileVersionInfo(PChar(FileName), Handle, VersionInfoSize, VersionInfoData) then
    Exit;

  if not VerQueryValue(VersionInfoData, '\', Pointer(FixedFileInfo), FixedFileInfoSize) then
    Exit;

  Result := Format('%d.%d.%d.%d', [
    HiWord(FixedFileInfo.dwFileVersionMS),
    LoWord(FixedFileInfo.dwFileVersionMS),
    HiWord(FixedFileInfo.dwFileVersionLS),
    LoWord(FixedFileInfo.dwFileVersionLS)
  ]);
end;

end.
