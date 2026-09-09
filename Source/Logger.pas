unit Logger;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  System.SyncObjs, System.Rtti, System.IOUtils,
  System.TypInfo,
  System.Generics.Collections,
  System.JSON;

type
  {$SCOPEDENUMS ON}
  TLogStatus = (Information, Watch, Warning, Error, Critical);
  TLogOutputFormat = (Text, CSV, JSON); // Enumerated type for output format
  {$SCOPEDENUMS OFF}

  TLogEntry = class
    LogTime: TDateTime;
    UserID: string;
    LogObject: string;
    Description: string;
    LogStatus: TLogStatus;
    constructor Create;
  end;

  TLogger = class
  private
    class var
      fUserID: string;
      fLogPath: string;
      fLogFileName: string;
      fOutputFormat: TLogOutputFormat; // Output format (Text, CSV or JSON)
      fFileLock: TCriticalSection;  // For thread-safe file access
      fJSONFileInitialized: Boolean;  // Track if we need to start JSON array
      fEnabled: boolean; // Are we allowed to log

    class procedure Initialise;
    class function LogToFile(const aLogEntry: TLogEntry): string;
    class function LogToCSV(const aLogEntry: TLogEntry): string;
    class function LogToJSON(const aLogEntry: TLogEntry): string;

    class procedure WriteLogEntry(const aLogEntry: TLogEntry);
    class procedure InitializeJSONFile;
    class procedure WriteJSONToFile(const aJSON: string);
    class procedure WriteTextToFile(const aText: string);
    class procedure SetEnabled(const Value: boolean); static;
  public
    class procedure SetLogFileAndPath(const aUserID: string; const aLogPath: string = '.');
    class procedure SetOutputFormat(const aFormat: TLogOutputFormat);
    class procedure Log(const aLogEntry: TLogEntry);

    class procedure CopyLogFile(const aSourceFile, aDestFile: string);
    class procedure DeleteLogFile;

    class function ContainsUserID: boolean;
    class function GetUserID: string;
    class function GetFileName: string;
    class function GetLogPath: string;
    class function GetOutputFormat: TLogOutputFormat;
    class function GetFileContents: string;

    class property Enabled: boolean read fEnabled write SetEnabled default false;
  end;

implementation

{ TLogger }

class procedure TLogger.Initialise;
begin
  TLogger.fJSONFileInitialized := False;
end;

class procedure TLogger.SetEnabled(const Value: boolean);
var
  logContent: TArray<string>;
  maxLines: integer;
begin
  fEnabled := Value;
  if not fEnabled then
  begin
    // We will need to remove the log file, but only if there is the equivalent
    // of  single line of log; otherwise the file has some usefull content
    // and will not be removed
    maxLines := 1;
    if fOutputFormat = TLogOutputFormat.JSON then maxLines := 3;
    if FileExists(TLogger.GetFileName) then
    begin
      logContent := TFile.ReadAllLines(TLogger.GetFileName);
      if Length(logContent) <= maxLines then TLogger.DeleteLogFile;
    end;
  end;
end;

class procedure TLogger.SetLogFileAndPath(const aUserID: string; const aLogPath: string);
begin
  try
    fUserID := aUserID;
    fLogPath := aLogPath;
    fLogFileName := IncludeTrailingPathDelimiter(aLogPath)+FormatDateTime('yyy-mm-dd',Now)+'_'+aUserID.Trim+'.log';
    ForceDirectories(ExtractFilePath(fLogFileName));
  except
	  on e: Exception do
	    raise Exception.CreateFmt('TLogger.SetLogFileName,Error: %s', [e.Message]);
  end;
end;

class procedure TLogger.SetOutputFormat(const aFormat: TLogOutputFormat);
begin
  fOutputFormat := aFormat;
  Initialise;
end;

class procedure TLogger.CopyLogFile(const aSourceFile, aDestFile: string);
begin
  try
    if FileExists(aSourceFile) then
      TFile.Copy(aSourceFile, aDestFile);
  except
	  on e: Exception do
	    raise Exception.CreateFmt('TLogger.CopyLogFile,Error: %s', [e.Message]);
  end;
end;

class procedure TLogger.DeleteLogFile;
begin
  try
    if FileExists(fLogFileName) then DeleteFile(fLogFileName);
  except
	  on e: Exception do
	    raise Exception.CreateFmt('TLogger.CopyLogFile,DeleteLogFile: %s', [e.Message]);
  end;
end;

class function TLogger.GetFileContents: string;
var
  fileContents: string;
begin
  Result := '';
  if FileExists(fLogFileName) then
  begin
    try
      fileContents := TFile.ReadAllText(fLogFileName);
      Result := fileContents;
    except
      on e: Exception do
        raise Exception.CreateFmt('TLogger.CopyLogFile,GetFileContents: %s', [e.Message]);
    end;
  end
  else
    raise Exception.CreateFmt('TLogger.GetFileContents,No file: %s', [fLogFileName]);
end;

class function TLogger.GetFileName: string;
begin
  Result := fLogFileName;
end;

class function TLogger.GetLogPath: string;
begin
  Result := fLogPath;
end;

class function TLogger.GetOutputFormat: TLogOutputFormat;
begin
  Result := fOutputFormat;
end;

class function TLogger.GetUserID: string;
begin
  Result := fUserID;
end;

class function TLogger.ContainsUserID: boolean;
begin
  Result := not fUserID.IsEmpty;
end;

// The main loggin routine
class procedure TLogger.Log(const aLogEntry: TLogEntry);
begin
  if fLogFileName = '' then
    raise Exception.Create('TLogger.Log, Log filename not set');

  // Log to file
  WriteLogEntry(aLogEntry);
end;

class procedure TLogger.WriteLogEntry(const aLogEntry: TLogEntry);
var
  logLine: string;
begin
  case fOutputFormat of
    TLogOutputFormat.Text:
      begin
        logLine := TLogger.LogToFile(aLogEntry);
        if not logLine.IsEmpty then WriteTextToFile(logLine);
      end;
    TLogOutputFormat.CSV:
      begin
        logLine := TLogger.LogToCSV(aLogEntry);
        if not logLine.IsEmpty then WriteTextToFile(logLine);
      end;
    TLogOutputFormat.JSON:
      begin
        logLine := TLogger.LogToJSON(aLogEntry);
        if not logLine.IsEmpty then WriteJSONToFile(logLine);
      end;
  end;
end;

class function TLogger.LogToCSV(const aLogEntry: TLogEntry): string;
var
  statusStr: string;
  timeString: string;
begin
  statusStr := GetEnumName(TypeInfo(TLogStatus), Ord(aLogEntry.LogStatus));
  DateTimeToString(timeString,'yyyy-mm-dd hh:nn:ss.zzz',aLogEntry.LogTime);
  Result := Format('"%s","%s","%s","%s","%s"', [
    timeString,
    aLogEntry.UserID,
    aLogEntry.LogObject,
    aLogEntry.Description,
    statusStr
  ]);
end;

class function TLogger.LogToFile(const aLogEntry: TLogEntry): string;
var
  statusStr: string;
  timeString: string;
begin
  statusStr := GetEnumName(TypeInfo(TLogStatus), Ord(aLogEntry.LogStatus));
  DateTimeToString(timeString,'yyyy-mm-dd hh:nn:ss.zzz',aLogEntry.LogTime);
  Result := Format('[%s] %-12s %-20s %s', [
    timeString,
    statusStr,
    aLogEntry.LogObject,
    aLogEntry.Description
  ]);
end;

class function TLogger.LogToJSON(const aLogEntry: TLogEntry): string;
var
  StatusStr: string;
  jsonObj: TJSONObject;
begin
  Result := EmptyStr;
  try
    StatusStr := GetEnumName(TypeInfo(TLogStatus), Ord(ALogEntry.LogStatus));

    // Create a JSON object for the log entry
    jsonObj := TJSONObject.Create;
    try
      jsonObj.AddPair('LogTime', FormatDateTime('yyyy-mm-dd hh:nn:ss', aLogEntry.LogTime));
      jsonObj.AddPair('UserID', aLogEntry.UserID);
      jsonObj.AddPair('LogObject', aLogEntry.LogObject);
      jsonObj.AddPair('Description', aLogEntry.Description);
      jsonObj.AddPair('LogStatus', StatusStr);
      Result := jsonObj.ToString;
    finally
      jsonObj.Free;
    end;
  except
	  on e: Exception do
	    raise Exception.CreateFmt('TLogger.LogToJSON,Error when creating the log entry: %s', [e.Message]);
  end;
end;


class procedure TLogger.InitializeJSONFile;
var
  stream: TFileStream;
  buffer: TBytes;
  logContents: string;
begin
  if not FileExists(FLogFileName) then
  begin
    stream := TFileStream.Create(fLogFileName, fmCreate or fmShareDenyWrite);
    try
      buffer := TEncoding.UTF8.GetBytes('[' + sLineBreak);
      stream.WriteBuffer(buffer[0], Length(buffer));
      fJSONFileInitialized := True;
    finally
      stream.Free;
    end;
  end
  else
  begin
    logContents := TFile.ReadAllText(fLogFileName);
    if logContents.IsEmpty then
    begin
      Stream := TFileStream.Create(fLogFileName, fmOpenWrite or fmShareDenyWrite);
      try
        buffer := TEncoding.UTF8.GetBytes('[' + sLineBreak);
        stream.WriteBuffer(buffer[0], Length(buffer));
        fJSONFileInitialized := True;
      finally
        stream.Free;
      end;
    end;
  end;
end;


class procedure TLogger.WriteJSONToFile(const aJSON: string);
var
  stream: TFileStream;
  buffer: TBytes;
  fileSize: Int64;
  needsComma: boolean;
  logExists: boolean;
  EndArrayCharsLength: integer;
begin
  // Length of the final characters we need to overwrite: sLineBreak + ']'
  // We MUST know the exact size of sLineBreak for this seeking logic to work.
  // Assuming sLineBreak is #13#10 (2 bytes) for Windows, the size is 3 (2 + 1 for ']').
  EndArrayCharsLength := Length(sLineBreak) + 1; // +1 for the final ']'

  logExists := FileExists(fLogFileName);

  // Initialization only needs to happen if the file doesn't exist AND hasn't been initialized
  if ( (not fJSONFileInitialized) and (not logExists) ) then
    InitializeJSONFile;

  fFileLock.Acquire;
  try
    stream := TFileStream.Create(fLogFileName, fmOpenReadWrite or fmShareDenyWrite);
    try
      fileSize := stream.Size;

      // 1. Determine if a comma is needed (i.e., if this is NOT the very first log item).
      // The file is initialized with '[' + sLineBreak (Min size: 1 + Length(sLineBreak))
      // If the file size is greater than the initial setup, we need a comma.
      if fileSize > (Length('[') + Length(sLineBreak)) then
        needsComma := True
      else
        // This is the first log item being written, so no comma is needed.
        needsComma := False;

      // 2. Prepare the buffer with the new content
      if needsComma then
        // Subsequent entry: prefix with comma, add new JSON, and re-add closing ']'
        buffer := TEncoding.UTF8.GetBytes(',' + sLineBreak + aJSON + sLineBreak + ']')
      else
        // First entry: just add new JSON, and add the closing ']'
        // This logic handles the bug you reported.
        buffer := TEncoding.UTF8.GetBytes(aJSON + sLineBreak + ']');

      // 3. Seek to overwrite the file's current end.
      if fileSize > EndArrayCharsLength then
        // If content exists, seek back to overwrite the current final ']' and sLineBreak
        stream.Seek(-EndArrayCharsLength, soEnd)
      else
        // File is basically empty (just '[', sLineBreak, etc.), seek to the end
        // This ensures we start writing right after the initial '[' + sLineBreak
        stream.Seek(fileSize, soBeginning);

      // 4. Write the new buffer content
      stream.Write(Buffer[0], Length(buffer));

      fJSONFileInitialized := True;
    finally
      stream.Free;
    end;
  finally
    fFileLock.Release;
  end;
end;


class procedure TLogger.WriteTextToFile(const aText: string);
var
  stream: TFileStream;
  buffer: TBytes;
begin
  fFileLock.Acquire;
  try
    if FileExists(FLogFileName) then
      stream := TFileStream.Create(FLogFileName, fmOpenWrite or fmShareDenyWrite)
    else
      stream := TFileStream.Create(FLogFileName, fmCreate or fmShareDenyWrite);

    try
      stream.Seek(0, soEnd);
      buffer := TEncoding.UTF8.GetBytes(aText + sLineBreak);
      stream.WriteBuffer(buffer[0], Length(buffer));
    finally
      stream.Free;
    end;
  finally
    fFileLock.Release;
  end;
end;

{ TLogEntry }

constructor TLogEntry.Create;
begin
  inherited Create;
  LogTime := Now;
  UserID := '';
  LogObject := '';
  Description := '';
  LogStatus := TLogStatus.Information;
end;

initialization
  TLogger.FFileLock := TCriticalSection.Create;
  TLogger.Initialise;

finalization
  TLogger.FFileLock.Free;

end.
