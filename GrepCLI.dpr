program GrepCLI;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Threading,
  System.Generics.Collections,
  System.SyncObjs,
  CliUtils in 'Source\CliUtils.pas',
  Grep.Core in 'Source\Grep.Core.pas';

const
  C_RESET   = #27'[0m';
  C_RED     = #27'[31m';
  C_GREEN   = #27'[32m';
  C_YELLOW  = #27'[33m';
  C_BLUE    = #27'[34m';
  C_MAGENTA = #27'[35m';
  C_CYAN    = #27'[36m';
  C_WHITE   = #27'[37m';

var
  LogFile: TextFile;
  LogFilePath: string = '';
  PendingMatchRequests: Integer = 0;
  SearchFinished: Integer = 0;
  SearchCompletedEvent: TEvent = nil;
  OutputLock: TCriticalSection = nil;

procedure WriteLnColour(const Colour, S: string);
begin
  OutputLock.Acquire;
  try
    Writeln(Colour + S + C_RESET);
  finally
    OutputLock.Release;
  end;
end;

procedure LogContents(const AContents: string);
begin
  if LogFilePath = '' then
    Exit;

  OutputLock.Acquire;
  try
    WriteLn(LogFile, aContents);
    Flush(LogFile);
  finally
    OutputLock.Release;
  end;
end;

procedure LogMatch(const AFilename: string; const ALineNumber: Integer; const AMatchedValue: string);
var
  aContents: string;
begin
  if LogFilePath = '' then
    Exit;

  OutputLock.Acquire;
  try
    aContents := Format('%-128s %-16s %s',[AFilename,ALineNumber.ToString,Trim(AMatchedValue)]);
    WriteLn(LogFile, aContents);
    Flush(LogFile);
  finally
    OutputLock.Release;
  end;
end;

procedure TryCompleteSearch;
begin
  if (TInterlocked.Add(SearchFinished, 0) <> 0) and
     (TInterlocked.Add(PendingMatchRequests, 0) = 0) and
     (SearchCompletedEvent <> nil) then
    SearchCompletedEvent.SetEvent;
end;

procedure ShowHelp;
begin
  WriteLn('');
  WriteLn(C_CYAN + 'GrepCLI - Command line search and replace tool' + C_RESET);
  WriteLn('');
  WriteLn(C_YELLOW + 'Usage:' + C_RESET + ' GrepCLI [options]');
  WriteLn('');
  WriteLn(C_YELLOW + 'Options:' + C_RESET);
  WriteLn('  -folder <path>           Root folder to search ' + C_GREEN + '(REQUIRED)' + C_RESET);
  WriteLn('  -text <text>             Text to search for');
  WriteLn('  -regex <pattern>         Regex pattern to search for');
  WriteLn('  -replace <text>          Replace matched text with this value');
  WriteLn('  -dryrun                  Perform replace but DO NOT write changes');
  WriteLn('  -wildcards <pattern>     File mask (default: *.*)');
  WriteLn('  -casesensitive           Case-sensitive search');
  WriteLn('  -nosubfolders            Do NOT search subfolders');
  WriteLn('  -includehidden           Include hidden files');
  WriteLn('  -includebinary           Include binary files');
  WriteLn('  -minsize <bytes>         Only search files >= this size');
  WriteLn('  -maxsize <bytes>         Only search files <= this size');
  WriteLn('  -datefrom <yyyy-mm-dd>   Only search files modified on/after this date');
  WriteLn('  -dateto <yyyy-mm-dd>     Only search files modified on/before this date');
  WriteLn('  -showmatches <n>         Show n lines around each match (default: 2)');
  WriteLn('  -logfile <path>          Write results to a tab-delimited logfile');
  WriteLn('  -?                       Show this help message');
  WriteLn('');
  WriteLn(C_YELLOW + 'Notes:' + C_RESET);
  WriteLn('  Either -text or -regex must be supplied.');
  WriteLn('  If -replace is supplied, GrepCLI performs a replace operation.');
  WriteLn('  Use ' + C_MAGENTA + '-dryrun' + C_RESET + ' to preview replace operations without writing.');
  WriteLn('');
  WriteLn(C_YELLOW + 'Examples:' + C_RESET);
  WriteLn('  GrepCLI -folder C:\Src -text TODO');
  WriteLn('  GrepCLI -folder C:\Logs -regex "(error|warning)"');
  WriteLn('  GrepCLI -folder C:\Src -text "foo" -replace "bar" -dryrun');
  WriteLn('  GrepCLI -folder C:\Src -text Init -wildcards *.pas -casesensitive');
  WriteLn('  GrepCLI -folder C:\Data -text "hello" -minsize 1000 -maxsize 50000');
  WriteLn('  GrepCLI -folder C:\Src -regex "\bclass\b" -showmatches 5');
  WriteLn('');
end;

var
  Params: TCliParams;
  Grep: TGrep;
  Folder: string;
  LinesAround: Integer;
  DryRun: Boolean;
  UseLogFile: Boolean;

begin
  try
    Grep := nil;
    Params := TCliParams.Create;
    OutputLock := TCriticalSection.Create;
    SearchCompletedEvent := TEvent.Create(nil, True, False, '');
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
      DryRun := Params.HasParam('dryrun');
      UseLogFile := Params.HasParam('logfile');

      if not Params.HasParam('text') and not Params.HasParam('regex') then
      begin
        ShowHelp;
        Exit;
      end;

      if UseLogFile then
      begin
        LogFilePath := Params.GetString('logfile');
        AssignFile(LogFile, LogFilePath);
        Rewrite(LogFile);
      end;

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

      Grep.MinSize := Params.GetInt64('minsize', 0);
      Grep.MaxSize := Params.GetInt64('maxsize', High(Int64));

      if Params.HasParam('datefrom') then
        Grep.DateFrom := ISO8601ToDate(Params.GetString('datefrom'));

      if Params.HasParam('dateto') then
        Grep.DateTo := ISO8601ToDate(Params.GetString('dateto'));

      // Events
      Grep.OnFileFound :=
        procedure(const aFilename: string)
        begin
          WriteLnColour(C_GREEN, 'FOUND: ' + aFilename);

          if LinesAround > 0 then
          begin
            TInterlocked.Increment(PendingMatchRequests);
            Grep.RequestMatches(aFilename, LinesAround);
          end;
        end;

      Grep.OnRequestedContents :=
        procedure(aContents: TObjectList<TMatchedLines>)
        var
          ML: TMatchedLines;
        begin
          try
            for ML in aContents do
            begin
              WriteLnColour(
                C_MAGENTA,
                Format('%s (%d): %s',
                  [ML.Filename, ML.LineNumber, ML.MatchedValue])
              );

              if UseLogFile then
                LogMatch(ML.Filename, ML.LineNumber, ML.MatchedValue);
            end;
          finally
            TInterlocked.Decrement(PendingMatchRequests);
            TryCompleteSearch;
          end;
        end;

      Grep.OnSearchCompleted :=
        procedure
        begin
          TInterlocked.Exchange(SearchFinished, 1);
          TryCompleteSearch;
        end;

      // Execute
      if Params.HasParam('replace') then
      begin
        if DryRun then
          WriteLnColour(C_YELLOW, 'Performing REPLACE (DRY RUN)...')
        else
          WriteLnColour(C_YELLOW, 'Performing REPLACE...');

        if DryRun then
        begin
          // Dry-run: do NOT write files
          WriteLnColour(C_CYAN, 'Dry-run mode: No files will be modified.');
          Grep.Search(Folder); // Just search, but show matches
        end
        else
        begin
          Grep.Replace(Folder);
        end;
      end
      else
      begin
        WriteLnColour(C_YELLOW, 'Performing SEARCH...');
        Grep.Search(Folder);
      end;

      WriteLnColour(C_BLUE, 'Running...');
      SearchCompletedEvent.WaitFor(INFINITE);
      WriteLnColour(C_CYAN, 'Search complete.');

    finally
      Grep.Free;
      if UseLogFile and (LogFilePath <> '') then
        CloseFile(LogFile);
      SearchCompletedEvent.Free;
      OutputLock.Free;
      Params.Free;
    end;

  except
    on E: Exception do
      WriteLnColour(C_RED, 'ERROR: ' + E.Message);
  end;
end.
