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
   System.StrUtils;

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

    FOnFileFound: TOnFileFound;
    FOnRequestedContents: TOnRequestedContents;
    FOnSearchCompleted: TOnSearchCompleted;

    function FileMatchesFilters(const aFile: string): Boolean;
    function IsBinaryFile(const aFile: string): Boolean;
    function IsHidden(const aFile: string): Boolean;
    function TextMatches(const aText: string): Boolean;
    function FileContainsMatch(const aFile: string): Boolean;
    function GetMatches(const aFile: string; aLinesAround: Integer): TObjectList<TMatchedLines>;
  public
    constructor Create;

    procedure Search(const aFolder: string);
    procedure Replace(const aFolder: string);

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
  Bytes: TBytes;
  I: Integer;
begin
  Result := False;
  Bytes := TFile.ReadAllBytes(aFile);
  for I := 0 to Min(1024, Length(Bytes)-1) do
    if Bytes[I] = 0 then
      Exit(True);
end;

function TGrep.IsHidden(const aFile: string): Boolean;
begin
  Result := TFileAttribute.faHidden in TFile.GetAttributes(aFile);
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

function TGrep.FileContainsMatch(const aFile: string): Boolean;
begin
  Result := TextMatches(TFile.ReadAllText(aFile));
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

function TGrep.GetMatches(const aFile: string; aLinesAround: Integer): TObjectList<TMatchedLines>;
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
    Lines.LoadFromFile(aFile);

    if FSearchMode = gsmRegex then
    begin
      Regex := TRegEx.Create(FSearchText, GetRegexOptions(FCaseSensitive));
    end;

    for I := 0 to Lines.Count - 1 do
    begin
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

procedure TGrep.Search(const aFolder: string);
begin
  TTask.Run(
    procedure
    var
      Files: TArray<string>;
      FileName: string;
    begin
      try
        Files := TDirectory.GetFiles(
          aFolder,
          FWildcards,
          GetSearchOption(FIncludeSubfolders)
        );

        for FileName in Files do
        begin
          if FileMatchesFilters(FileName) and FileContainsMatch(FileName) then
          begin
            if Assigned(FOnFileFound) then
              FOnFileFound(FileName);
          end;
        end;
      finally
        if Assigned(FOnSearchCompleted) then
          FOnSearchCompleted;
      end;
    end
  );
end;

procedure TGrep.Replace(const aFolder: string);
begin
  TTask.Run(
    procedure
    var
      Files: TArray<string>;
      FileName: string;
      SL: TStringList;
      Modified: Boolean;
    begin
      try
        Files := TDirectory.GetFiles(
          aFolder,
          FWildcards,
          GetSearchOption(FIncludeSubfolders)
        );

        for FileName in Files do
        begin
          if not FileMatchesFilters(FileName) then
            Continue;

          SL := TStringList.Create;
          try
            SL.LoadFromFile(FileName);
            Modified := TextMatches(SL.Text);

            if Modified then
            begin
              if FSearchMode = gsmText then
                SL.Text := SL.Text.Replace(FSearchText, FReplaceText, GetReplaceFlags(FCaseSensitive))
              else
                SL.Text := TRegEx.Replace(SL.Text, FSearchText, FReplaceText, GetRegexOptions(FCaseSensitive));

              SL.SaveToFile(FileName);
              if Assigned(FOnFileFound) then
                FOnFileFound(FileName);
            end;
          finally
            SL.Free;
          end;
        end;
      finally
        if Assigned(FOnSearchCompleted) then
          FOnSearchCompleted;
      end;
    end
  );
end;

procedure TGrep.RequestMatches(const aFilename: string; aLinesAround: Integer);
var
  L: TObjectList<TMatchedLines>;
begin
  L := GetMatches(aFilename, aLinesAround);
  try
    if Assigned(FOnRequestedContents) then
      FOnRequestedContents(L);
  finally
    L.Free;
  end;
end;

end.
