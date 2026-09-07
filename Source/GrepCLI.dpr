program GrepCLI;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Threading,
  CliUtils,
  Grep.Core;

procedure ShowHelp;
begin
  WriteLn('');
  WriteLn('GrepCLI - Command line search and replace tool');
  WriteLn('');
  WriteLn('Usage: GrepCLI [options]');
  WriteLn('');
  WriteLn('Options:');
  WriteLn('  -folder <path>           Root folder to search (REQUIRED)');
  WriteLn('  -text <text>             Text to search for');
  WriteLn('  -regex <pattern>         Regex pattern to search for');
  WriteLn('  -replace <text>          Replace matched text with this value');
  WriteLn('  -wildcards <pattern>     File mask (default: *.*)');
  WriteLn('  -casesensitive           Case-sensitive search');
  WriteLn('  -nosubfolders            Do NOT search subfolders');
  WriteLn('  -includehidden           Include hidden files');
  WriteLn('  -includebinary           Include binary files');
  WriteLn('  -minsize <bytes>         Only search files >= this size');
  WriteLn('  -maxsize <bytes>         Only search files <= this size');
  WriteLn('  -datefrom <yyyy-mm-dd>   Only search files modified on/after this date');
  WriteLn('  -dateto <yyyy-mm-dd>     Only search files modified on/before this date');
  WriteLn('  -showmatches <n>         Show n lines above/below each match (default: 2)');
  WriteLn('  -?                       Show this help message');
  WriteLn('');
  WriteLn('Notes:');
  WriteLn('  Either -text or -regex must be supplied.');
  WriteLn('  If -replace is supplied, GrepCLI performs a replace operation.');
  WriteLn('  All searching and replacing is threaded.');
  WriteLn('');
  WriteLn('Examples:');
  WriteLn('  GrepCLI -folder C:\Src -text TODO');
  WriteLn('  GrepCLI -folder C:\Logs -regex "(error|warning)"');
  WriteLn('  GrepCLI -folder C:\Src -text "foo" -replace "bar"');
  WriteLn('  GrepCLI -folder C:\Src -text Init -wildcards *.pas -casesensitive');
  WriteLn('  GrepCLI -folder C:\Data -text "hello" -minsize 1000 -maxsize 50000');
  WriteLn('  GrepCLI -folder C:\Src -regex "\bclass\b" -showmatches 5');
  WriteLn('');
end;

procedure WriteLnSafe(const S: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      Writeln(S);
    end);
end;

var
  Params: TCliParams;
  Grep: TGrep;
  Folder: string;
  LinesAround: Integer;

begin
  try
    Params := TCliParams.Create;
    try
      Params.Parse(ParamStr(0));

      if Params.HasParam('?') then
      begin
        ShowHelp;
        Exit;
      end;

      if not Params.HasParam('folder') then
      begin
        ShowHelp;
        Exit;
      end;

      Folder := Params.GetString('folder');
      LinesAround := Params.GetInteger('showmatches', 2);

      Grep := TGrep.Create;

      // Search mode
      if Params.HasParam('regex') then
      begin
        Grep.SearchMode := gsmRegex;
        Grep.SearchText := Params.GetString('regex');
      end
      else
      begin
        Grep.SearchMode := gsmText;
        Grep.SearchText := Params.GetString('text');
      end;

      // Replace mode
      Grep.ReplaceText := Params.GetString('replace', '');

      // Filters
      Grep.Wildcards := Params.GetString('wildcards', '*.*');
      Grep.CaseSensitive := Params.HasParam('casesensitive');
      Grep.IncludeSubfolders := not Params.HasParam('nosubfolders');
      Grep.ExcludeHidden := not Params.HasParam('includehidden');
      Grep.ExcludeBinary := not Params.HasParam('includebinary');

      Grep.MinSize := Params.GetInteger('minsize', 0);
      Grep.MaxSize := Params.GetInteger('maxsize', High(Int64));

      if Params.HasParam('datefrom') then
        Grep.DateFrom := ISO8601ToDate(Params.GetString('datefrom'));

      if Params.HasParam('dateto') then
        Grep.DateTo := ISO8601ToDate(Params.GetString('dateto'));

      // Events
      Grep.OnFileFound :=
        procedure(const aFilename: string)
        begin
          WriteLnSafe('FOUND: ' + aFilename);

          if LinesAround > 0 then
            Grep.RequestMatches(aFilename, LinesAround);
        end;

      Grep.OnRequestedContents :=
        procedure(aContents: TObjectList<TMatchedLines>)
        var
          ML: TMatchedLines;
        begin
          for ML in aContents do
            WriteLnSafe(
              Format('%s (%d): %s',
                [ML.Filename, ML.LineNumber, ML.MatchedValue])
            );
        end;

      // Execute
      if Params.HasParam('replace') then
      begin
        Writeln('Performing REPLACE...');
        Grep.Replace(Folder);
      end
      else
      begin
        Writeln('Performing SEARCH...');
        Grep.Search(Folder);
      end;

      // Keep console alive while tasks run
      Writeln('Running... press Ctrl+C to exit.');
      while True do
        Sleep(100);

    finally
      Params.Free;
    end;

  except
    on E: Exception do
      Writeln('ERROR: ' + E.Message);
  end;
end.
