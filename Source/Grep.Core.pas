unit Grep.Core;

interface

 uses
   System.SysUtils,
   System.Classes,
   System.Generics.Collections,
   System.RegularExpressions,
   System.Threading,
   System.Math,
   System.IOUtils,
   System.StrUtils,
   System.SyncObjs;

type
  TMatchedLines = class
  public
    Filename: string;
    LineNumber: Integer;
    MatchedValue: string;
  end;

  TOnFileFound = reference to procedure(const aFilename: string);
  TOnRequestedContents = reference to procedure(aContents: TObjectList<TMatchedLines>);
  TOnSearchCompleted = reference to procedure;

  TGrepSearchMode = (gsmText, gsmRegex);

  TGrep = class
  private
    FSearchMode: TGrepSearchMode;
    FSearchText: string;
    FReplaceText: string;
    FCaseSensitive: Boolean;
    FWildcards: string;
    FIncludeSubfolders: Boolean;
    FExcludeBinary: Boolean;
    FExcludeHidden: Boolean;
    FMinSize: Int64;
    FMaxSize: Int64;
    FDateFrom: TDateTime;
    FDateTo: TDateTime;
    FSearchToken: Integer;

    FOnFileFound: TOnFileFound;
    FOnRequestedContents: TOnRequestedContents;
    FOnSearchCompleted: TOnSearchCompleted;

    function FileMatchesFilters(const aFile: string): Boolean;
    function IsBinaryFile(const aFile: string): Boolean;
    function IsHidden(const aFile: string): Boolean;
    function IsSearchCancelled(const ASearchToken: Integer): Boolean;
    function TextMatches(const aText: string): Boolean;
    function FileContainsMatch(const aFile: string; const ASearchToken: Integer): Boolean;
    function GetMatches(const aFile: string; aLinesAround: Integer;
      const ASearchToken: Integer): TObjectList<TMatchedLines>;
    procedure SearchFolder(const AFolder: string; const ASearchToken: Integer);
    procedure ReplaceFolder(const AFolder: string; const ASearchToken: Integer);
  public
    constructor Create;

    procedure Search(const aFolder: string);
    procedure Replace(const aFolder: string);
    procedure Stop;

    procedure RequestMatches(const aFilename: string; aLinesAround: Integer);

    property SearchMode: TGrepSearchMode read FSearchMode write FSearchMode;
    property SearchText: string read FSearchText write FSearchText;
    property ReplaceText: string read FReplaceText write FReplaceText;
    property CaseSensitive: Boolean read FCaseSensitive write FCaseSensitive;
    property Wildcards: string read FWildcards write FWildcards;
    property IncludeSubfolders: Boolean read FIncludeSubfolders write FIncludeSubfolders;
    property ExcludeBinary: Boolean read FExcludeBinary write FExcludeBinary;
    property ExcludeHidden: Boolean read FExcludeHidden write FExcludeHidden;
    property MinSize: Int64 read FMinSize write FMinSize;
    property MaxSize: Int64 read FMaxSize write FMaxSize;
    property DateFrom: TDateTime read FDateFrom write FDateFrom;
    property DateTo: TDateTime read FDateTo write FDateTo;

    property OnFileFound: TOnFileFound read FOnFileFound write FOnFileFound;
    property OnRequestedContents: TOnRequestedContents read FOnRequestedContents write FOnRequestedContents;
    property OnSearchCompleted: TOnSearchCompleted read FOnSearchCompleted write FOnSearchCompleted;
  end;

implementation

function GetSearchOption(const IncludeSubfolders: Boolean): TSearchOption;
begin
  if IncludeSubfolders then
    Result := TSearchOption.soAllDirectories
  else
    Result := TSearchOption.soTopDirectoryOnly;
end;

function GetRegexOptions(const CaseSensitive: Boolean): TRegExOptions;
begin
  Result := [roMultiLine];
  if not CaseSensitive then
    Include(Result, roIgnoreCase);
end;

function GetReplaceFlags(const CaseSensitive: Boolean): TReplaceFlags;
begin
  Result := [rfReplaceAll];
  if not CaseSensitive then
    Include(Result, rfIgnoreCase);
end;

constructor TGrep.Create;
begin
  FWildcards := '*.*';
  FIncludeSubfolders := True;
  FExcludeBinary := True;
  FExcludeHidden := True;
  FMinSize := 0;
  FMaxSize := High(Int64);
  FDateFrom := 0;
  FDateTo := MaxDateTime;
end;

function TGrep.IsBinaryFile(const aFile: string): Boolean;
var
  Stream: TFileStream;
  Buffer: array[0..1023] of Byte;
  BytesRead: Integer;
  I: Integer;
begin
  Result := False;
  try
    Stream := TFile.OpenRead(aFile);
    try
      BytesRead := Stream.Read(Buffer, SizeOf(Buffer));
      for I := 0 to BytesRead - 1 do
        if Buffer[I] = 0 then
          Exit(True);
    finally
      Stream.Free;
    end;
  except
    Exit(True);
  end;
end;

function TGrep.IsHidden(const aFile: string): Boolean;
var
  Name: string;
{$IF Defined(MSWINDOWS)}
  Attributes: Integer;
{$ENDIF}
begin
  Name := ExtractFileName(ExcludeTrailingPathDelimiter(aFile));
  Result := Name.StartsWith('.');
  if Result then
    Exit;

{$IF Defined(MSWINDOWS)}
{$WARN SYMBOL_PLATFORM OFF}
  Attributes := FileGetAttr(aFile);
  Result := (Attributes <> -1) and ((Attributes and faHidden) <> 0);
{$WARN SYMBOL_PLATFORM ON}
{$ENDIF}
end;

function TGrep.IsSearchCancelled(const ASearchToken: Integer): Boolean;
begin
  Result := TInterlocked.Add(FSearchToken, 0) <> ASearchToken;
end;

function TGrep.TextMatches(const aText: string): Boolean;
begin
  if FSearchText = '' then
    Exit(False);

  if FSearchMode = gsmText then
  begin
    if FCaseSensitive then
      Result := aText.Contains(FSearchText)
    else
      Result := ContainsText(aText, FSearchText);
  end
  else
    Result := TRegEx.IsMatch(aText, FSearchText, GetRegexOptions(FCaseSensitive));
end;

function TGrep.FileContainsMatch(const aFile: string; const ASearchToken: Integer): Boolean;
begin
  if IsSearchCancelled(ASearchToken) then
    Exit(False);

  try
    Result := TextMatches(TFile.ReadAllText(aFile));
  except
    Exit(False);
  end;

  if Result and IsSearchCancelled(ASearchToken) then
    Result := False;
end;

function TGrep.FileMatchesFilters(const aFile: string): Boolean;
var
  Info: TSearchRec;
begin
  Result := False;

  if FindFirst(aFile, faAnyFile, Info) = 0 then
  try
    if (Info.Size < FMinSize) or (Info.Size > FMaxSize) then Exit;
    if (Info.TimeStamp < FDateFrom) or (Info.TimeStamp > FDateTo) then Exit;
    if FExcludeHidden and IsHidden(aFile) then Exit;
    if FExcludeBinary and IsBinaryFile(aFile) then Exit;

    Result := True;
  finally
    FindClose(Info);
  end;
end;

function TGrep.GetMatches(const aFile: string; aLinesAround: Integer;
  const ASearchToken: Integer): TObjectList<TMatchedLines>;
var
  Lines: TStringList;
  I: Integer;
  Regex: TRegEx;
  Match: TMatch;
  ML: TMatchedLines;
begin
  Result := TObjectList<TMatchedLines>.Create(True);
  Lines := TStringList.Create;
  try
    if IsSearchCancelled(ASearchToken) then
      Exit;

    try
      Lines.LoadFromFile(aFile);
    except
      Exit;
    end;

    if FSearchMode = gsmRegex then
      Regex := TRegEx.Create(FSearchText, GetRegexOptions(FCaseSensitive));

    for I := 0 to Lines.Count - 1 do
    begin
      if IsSearchCancelled(ASearchToken) then
        Exit;

      if FSearchMode = gsmText then
      begin
        if FCaseSensitive then
        begin
          if Lines[I].Contains(FSearchText) then
          begin
            ML := TMatchedLines.Create;
            ML.Filename := aFile;
            ML.LineNumber := I + 1;
            ML.MatchedValue := Lines[I];
            Result.Add(ML);
          end;
        end
        else
        begin
          if ContainsText(Lines[I], FSearchText) then
          begin
            ML := TMatchedLines.Create;
            ML.Filename := aFile;
            ML.LineNumber := I + 1;
            ML.MatchedValue := Lines[I];
            Result.Add(ML);
          end;
        end;
      end
      else
      begin
        Match := Regex.Match(Lines[I]);
        if Match.Success then
        begin
          ML := TMatchedLines.Create;
          ML.Filename := aFile;
          ML.LineNumber := I + 1;
          ML.MatchedValue := Lines[I];
          Result.Add(ML);
        end;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

procedure TGrep.SearchFolder(const AFolder: string; const ASearchToken: Integer);
var
  FileName: string;
  SubFolder: string;
  Wildcard: string;
  I: Integer;
  Files: TArray<string>;
  Wildcards: TArray<string>;
  SubFolders: TArray<string>;
begin
  if IsSearchCancelled(ASearchToken) then
    Exit;

  Wildcards := FWildcards.Split([',']);
  for I := Low(Wildcards) to High(Wildcards) do
  begin
    Wildcard := Trim(Wildcards[I]);
    if Wildcard = '' then
      Continue;

    try
      Files := TDirectory.GetFiles(AFolder, Wildcard, TSearchOption.soTopDirectoryOnly);
    except
      Continue;
    end;

    for FileName in Files do
    begin
      if IsSearchCancelled(ASearchToken) then
        Exit;

      if FileMatchesFilters(FileName) and FileContainsMatch(FileName, ASearchToken) then
      begin
        if IsSearchCancelled(ASearchToken) then
          Exit;

        if Assigned(FOnFileFound) then
          FOnFileFound(FileName);
      end;
    end;
  end;

  if not FIncludeSubfolders then
    Exit;

  try
    SubFolders := TDirectory.GetDirectories(AFolder);
  except
    Exit;
  end;

  for SubFolder in SubFolders do
  begin
    if IsSearchCancelled(ASearchToken) then
      Exit;

    if FExcludeHidden and IsHidden(SubFolder) then
      Continue;

    SearchFolder(SubFolder, ASearchToken);
  end;
end;

procedure TGrep.Search(const aFolder: string);
var
  SearchToken: Integer;
  Folders: TArray<string>;
begin
  SearchToken := TInterlocked.Increment(FSearchToken);
  Folders := aFolder.Split([',']);
  TTask.Create(
    procedure
    var
      Folder: string;
      I: Integer;
    begin
      try
        for I := Low(Folders) to High(Folders) do
        begin
          Folder := Trim(Folders[I]);
          if Folder <> '' then
            SearchFolder(Folder, SearchToken);
        end;
      finally
        if not IsSearchCancelled(SearchToken) and Assigned(FOnSearchCompleted) then
          FOnSearchCompleted;
      end;
    end
  ).Start;
end;

procedure TGrep.ReplaceFolder(const AFolder: string; const ASearchToken: Integer);
var
  FileName: string;
  SubFolder: string;
  Wildcard: string;
  SL: TStringList;
  Modified: Boolean;
  I: Integer;
  Files: TArray<string>;
  Wildcards: TArray<string>;
  SubFolders: TArray<string>;
begin
  if IsSearchCancelled(ASearchToken) then
    Exit;

  Wildcards := FWildcards.Split([',']);
  for I := Low(Wildcards) to High(Wildcards) do
  begin
    Wildcard := Trim(Wildcards[I]);
    if Wildcard = '' then
      Continue;

    try
      Files := TDirectory.GetFiles(AFolder, Wildcard, TSearchOption.soTopDirectoryOnly);
    except
      Continue;
    end;

    for FileName in Files do
    begin
      if IsSearchCancelled(ASearchToken) then
        Exit;

      if not FileMatchesFilters(FileName) then
        Continue;

      SL := TStringList.Create;
      try
        try
          SL.LoadFromFile(FileName);
        except
          Continue;
        end;

        if IsSearchCancelled(ASearchToken) then
          Exit;

        Modified := TextMatches(SL.Text);
        if Modified then
        begin
          if FSearchMode = gsmText then
            SL.Text := SL.Text.Replace(FSearchText, FReplaceText, GetReplaceFlags(FCaseSensitive))
          else
            SL.Text := TRegEx.Replace(SL.Text, FSearchText, FReplaceText, GetRegexOptions(FCaseSensitive));

          if IsSearchCancelled(ASearchToken) then
            Exit;

          try
            SL.SaveToFile(FileName);
          except
            Continue;
          end;

          if IsSearchCancelled(ASearchToken) then
            Exit;

          if Assigned(FOnFileFound) then
            FOnFileFound(FileName);
        end;
      finally
        SL.Free;
      end;
    end;
  end;

  if not FIncludeSubfolders then
    Exit;

  try
    SubFolders := TDirectory.GetDirectories(AFolder);
  except
    Exit;
  end;

  for SubFolder in SubFolders do
  begin
    if IsSearchCancelled(ASearchToken) then
      Exit;

    if FExcludeHidden and IsHidden(SubFolder) then
      Continue;

    ReplaceFolder(SubFolder, ASearchToken);
  end;
end;

procedure TGrep.Replace(const aFolder: string);
var
  SearchToken: Integer;
  Folders: TArray<string>;
begin
  SearchToken := TInterlocked.Increment(FSearchToken);
  Folders := aFolder.Split([',']);
  TTask.Create(
    procedure
    var
      Folder: string;
      I: Integer;
    begin
      try
        for I := Low(Folders) to High(Folders) do
        begin
          Folder := Trim(Folders[I]);
          if Folder <> '' then
            ReplaceFolder(Folder, SearchToken);
        end;
      finally
        if not IsSearchCancelled(SearchToken) and Assigned(FOnSearchCompleted) then
          FOnSearchCompleted;
      end;
    end
  ).Start;
end;

procedure TGrep.Stop;
begin
  TInterlocked.Increment(FSearchToken);
end;

procedure TGrep.RequestMatches(const aFilename: string; aLinesAround: Integer);
var
  L: TObjectList<TMatchedLines>;
  SearchToken: Integer;
begin
  SearchToken := TInterlocked.Add(FSearchToken, 0);
  L := GetMatches(aFilename, aLinesAround, SearchToken);
  try
    if not IsSearchCancelled(SearchToken) and Assigned(FOnRequestedContents) then
      FOnRequestedContents(L);
  finally
    L.Free;
  end;
end;

end.
