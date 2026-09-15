unit MainForm_FMX;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Math,
  System.IOUtils,
  System.SyncObjs,
  System.DateUtils,
  System.RegularExpressions,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Dialogs,
  FMX.DialogService,
  FMX.Layouts,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.DateTimeCtrls,
  FMX.NumberBox,
  FMX.ListView,
  Grep.Core,
  MatchesList,
  MatchesDisplay_FMX, FMX.ListView.Types, FMX.ListView.Appearances,
  FMX.ListView.Adapters.Base, FMX.EditBox, FMX.Controls.Presentation;

type
  TMainForm = class(TForm)
    HeaderBar: TRectangle;
    TitleLabel: TLabel;
    SubtitleLabel: TLabel;
    ActionLayout: TLayout;
    BackButton: TButton;
    StopButton: TButton;
    SearchButton: TButton;
    BodyLayout: TLayout;
    SearchCard: TRectangle;
    FilterCard: TRectangle;
    FolderLabel: TLabel;
    FolderEdit: TEdit;
    BrowseButton: TButton;
    FindLabel: TLabel;
    SearchTextEdit: TEdit;
    ReplaceLabel: TLabel;
    ReplaceTextEdit: TEdit;
    WildcardsLabel: TLabel;
    WildcardsEdit: TEdit;
    ContextLinesLabel: TLabel;
    ContextLinesBox: TNumberBox;
    RegexLabel: TLabel;
    RegexSwitch: TSwitch;
    CaseSensitiveLabel: TLabel;
    CaseSensitiveSwitch: TSwitch;
    ReplaceModeLabel: TLabel;
    ReplaceModeSwitch: TSwitch;
    SearchCardTitle: TLabel;
    FilterCardTitle: TLabel;
    IncludeSubfoldersLabel: TLabel;
    IncludeSubfoldersSwitch: TSwitch;
    IncludeHiddenLabel: TLabel;
    IncludeHiddenSwitch: TSwitch;
    IncludeBinaryLabel: TLabel;
    IncludeBinarySwitch: TSwitch;
    UseDateFromLabel: TLabel;
    UseDateFromSwitch: TSwitch;
    DateFromEdit: TDateEdit;
    UseDateToLabel: TLabel;
    UseDateToSwitch: TSwitch;
    DateToEdit: TDateEdit;
    MinSizeLabel: TLabel;
    MinSizeEdit: TEdit;
    MaxSizeLabel: TLabel;
    MaxSizeEdit: TEdit;
    ResultsLayout: TLayout;
    ResultsHeader: TRectangle;
    ResultsTitleLabel: TLabel;
    ResultsStatusLabel: TLabel;
    SearchIndicator: TAniIndicator;
    ResultsSurface: TRectangle;
    DetailsPanel: TRectangle;
    DetailsPaintBox: TPaintBox;
    MatchesListView: TListView;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
  private
    FGrep: TGrep;
    FMatchesDisplay: TMatchesDisplay;
    FPendingMatchRequests: Integer;
    FMatchedFiles: Integer;
    FSearchFinished: Integer;
    FSearchRequestId: Integer;
    FCurrentLinesAround: Integer;
    FSearching: Boolean;
    FOpenButton: TButton;
    procedure ConfigureGrepFromForm;
    procedure ClearResults;
    procedure FinalizeSearchIfReady(const ASearchRequestId: Integer);
    function ValidateInputs(out AFolder: string): Boolean;
    function BuildMatchDataList(AContents: TObjectList<TMatchedLines>): TObjectList<TMatchesData>;
    procedure UpdateModeState;
    procedure UpdateResultSummary;
    procedure UpdateStatusText(const AText: string);
    procedure HandleFileFound(const AFileName: string);
    procedure HandleRequestedContents(AContents: TObjectList<TMatchedLines>);
    procedure HandleSearchCompleted;
    procedure BrowseButtonClick(Sender: TObject);
    procedure SearchButtonClick(Sender: TObject);
    procedure BackButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure ToggleModeChanged(Sender: TObject);
    procedure OpenButtonClick(Sender: TObject);
    procedure StopSearch;
    procedure UpdateSearchUi(const ASearching: Boolean);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure AddButtonImage(const AButton: TButton; const AFileName: string);
var
  Image: TImage;
  Stream: TResourceStream;
begin
  Image := TImage.Create(AButton);
  Image.Parent := AButton;
  Image.Align := TAlignLayout.Center;
  Image.Width := 20;
  Image.Height := 20;
  Image.HitTest := False;
  Stream := TResourceStream.Create(HInstance, UpperCase(ChangeFileExt(AFileName, '')), RT_RCDATA);
  try
    Image.Bitmap.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  MatchesListView.OnKeyDown := FormKeyDown;
  SearchButton.OnClick := SearchButtonClick;
  BackButton.OnClick := BackButtonClick;
  StopButton.OnClick := StopButtonClick;
  BrowseButton.OnClick := BrowseButtonClick;
  RegexSwitch.OnClick := ToggleModeChanged;
  CaseSensitiveSwitch.OnClick := ToggleModeChanged;
  ReplaceModeSwitch.OnClick := ToggleModeChanged;
  UseDateFromSwitch.OnClick := ToggleModeChanged;
  UseDateToSwitch.OnClick := ToggleModeChanged;

  FGrep := TGrep.Create;
  FGrep.OnFileFound := HandleFileFound;
  FGrep.OnRequestedContents := HandleRequestedContents;
  FGrep.OnSearchCompleted := HandleSearchCompleted;

  FMatchesDisplay := TMatchesDisplay.Create(Self, MatchesListView, DetailsPanel, DetailsPaintBox);

  FOpenButton := TButton.Create(Self);
  FOpenButton.Parent := DetailsPanel;
  FOpenButton.Text := '';
  FOpenButton.Width := 60;
  FOpenButton.Height := 44;
  FOpenButton.Position.X := DetailsPanel.Width - FOpenButton.Width - 14;
  FOpenButton.Position.Y := 8;
  FOpenButton.Anchors := [TAnchorKind.akTop, TAnchorKind.akRight];
  FOpenButton.OnClick := OpenButtonClick;
  AddButtonImage(FOpenButton, 'open_with_32dp.png');
  FOpenButton.BringToFront;

  ContextLinesBox.Min := 0;
  ContextLinesBox.Max := 20;
  ContextLinesBox.DecimalDigits := 0;
  ContextLinesBox.HorzIncrement := 1;
  ContextLinesBox.Value := 3;

  IncludeSubfoldersSwitch.IsChecked := True;
  IncludeHiddenSwitch.IsChecked := False;
  IncludeBinarySwitch.IsChecked := False;
  RegexSwitch.IsChecked := False;
  CaseSensitiveSwitch.IsChecked := False;
  ReplaceModeSwitch.IsChecked := False;
  UseDateFromSwitch.IsChecked := False;
  UseDateToSwitch.IsChecked := False;

  DateFromEdit.Date := Date - 30;
  DateToEdit.Date := Date;
  WildcardsEdit.Text := '*.*';

  UpdateModeState;
  UpdateSearchUi(False);
  ClearResults;
  UpdateStatusText('Configure the search options and start a new Grep.');
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  if (Key = Ord('O')) and (ssCtrl in Shift) then
  begin
    OpenButtonClick(nil);
    Key := 0;
    KeyChar := #0;
    Exit;
  end;

  case Key of
    vkUp:
      FMatchesDisplay.SelectPreviousMatch;
    vkDown:
      FMatchesDisplay.SelectNextMatch;
    vkPrior:
      FMatchesDisplay.SelectFirstMatch;
    vkNext:
      FMatchesDisplay.SelectLastMatch;
  else
    Exit;
  end;
  Key := 0;
  KeyChar := #0;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FGrep.Stop;
  FMatchesDisplay.Free;
  FGrep.Free;
end;

procedure TMainForm.BrowseButtonClick(Sender: TObject);
var
  SelectedFolder: string;
begin
  SelectedFolder := Trim(FolderEdit.Text);
  if SelectDirectory('Choose the root folder', '', SelectedFolder) then
    FolderEdit.Text := SelectedFolder;
end;

procedure TMainForm.SearchButtonClick(Sender: TObject);
var
  Folder: string;
begin
  if FSearching then
    Exit;

  if not ValidateInputs(Folder) then
    Exit;

  ClearResults;
  ConfigureGrepFromForm;
  FCurrentLinesAround := Round(ContextLinesBox.Value);
  TInterlocked.Increment(FSearchRequestId);
  TInterlocked.Exchange(FPendingMatchRequests, 0);
  TInterlocked.Exchange(FMatchedFiles, 0);
  TInterlocked.Exchange(FSearchFinished, 0);
  FSearching := True;
  UpdateSearchUi(True);
  if ReplaceModeSwitch.IsChecked then
    UpdateStatusText('Replacing matches...')
  else
    UpdateStatusText('Searching...');

  if ReplaceModeSwitch.IsChecked then
    FGrep.Replace(Folder)
  else
    FGrep.Search(Folder);
end;

procedure TMainForm.BackButtonClick(Sender: TObject);
begin
  if FSearching then
    Exit;

  ClearResults;
  UpdateStatusText('Configure the search options and start a new Grep.');
end;

procedure TMainForm.StopButtonClick(Sender: TObject);
begin
  StopSearch;
end;

procedure TMainForm.OpenButtonClick(Sender: TObject);
begin
  FMatchesDisplay.OpenSelectedMatch;
end;

procedure TMainForm.ToggleModeChanged(Sender: TObject);
begin
  UpdateModeState;
end;

procedure TMainForm.UpdateModeState;
begin
  ReplaceTextEdit.Enabled := ReplaceModeSwitch.IsChecked;
  DateFromEdit.Enabled := UseDateFromSwitch.IsChecked;
  DateToEdit.Enabled := UseDateToSwitch.IsChecked;

  if ReplaceModeSwitch.IsChecked then
    SearchButton.Text := 'Replace'
  else
    SearchButton.Text := 'Search';
end;

procedure TMainForm.UpdateResultSummary;
begin
  ResultsTitleLabel.Text := Format('Results (%d files)', [FMatchesDisplay.FileCount]);
end;

procedure TMainForm.UpdateStatusText(const AText: string);
begin
  ResultsStatusLabel.Text := AText;
end;

procedure TMainForm.ConfigureGrepFromForm;
var
  SizeValue: Int64;
begin
  if RegexSwitch.IsChecked then
    FGrep.SearchMode := gsmRegex
  else
    FGrep.SearchMode := gsmText;

  FGrep.SearchText := Trim(SearchTextEdit.Text);
  FGrep.ReplaceText := ReplaceTextEdit.Text;
  FGrep.CaseSensitive := CaseSensitiveSwitch.IsChecked;
  FGrep.Wildcards := Trim(WildcardsEdit.Text);
  FGrep.IncludeSubfolders := IncludeSubfoldersSwitch.IsChecked;
  FGrep.ExcludeHidden := not IncludeHiddenSwitch.IsChecked;
  FGrep.ExcludeBinary := not IncludeBinarySwitch.IsChecked;

  if TryStrToInt64(Trim(MinSizeEdit.Text), SizeValue) then
    FGrep.MinSize := SizeValue
  else
    FGrep.MinSize := 0;

  if TryStrToInt64(Trim(MaxSizeEdit.Text), SizeValue) then
    FGrep.MaxSize := SizeValue
  else
    FGrep.MaxSize := High(Int64);

  if UseDateFromSwitch.IsChecked then
    FGrep.DateFrom := StartOfTheDay(DateFromEdit.Date)
  else
    FGrep.DateFrom := 0;

  if UseDateToSwitch.IsChecked then
    FGrep.DateTo := EndOfTheDay(DateToEdit.Date)
  else
    FGrep.DateTo := MaxDateTime;
end;

procedure TMainForm.ClearResults;
begin
  FMatchesDisplay.ClearBrowser;
  UpdateResultSummary;
end;

procedure TMainForm.UpdateSearchUi(const ASearching: Boolean);
begin
  SearchButton.Enabled := not ASearching;
  BackButton.Enabled := not ASearching;
  BackButton.Visible := not ASearching;
  StopButton.Visible := ASearching;
  SearchIndicator.Enabled := ASearching;
  SearchIndicator.Visible := ASearching;
end;

procedure TMainForm.StopSearch;
begin
  if not FSearching then
    Exit;

  FGrep.Stop;
  TInterlocked.Increment(FSearchRequestId);
  TInterlocked.Exchange(FPendingMatchRequests, 0);
  TInterlocked.Exchange(FSearchFinished, 0);
  FSearching := False;
  UpdateSearchUi(False);

  if ReplaceModeSwitch.IsChecked then
    UpdateStatusText('Replace stopped.')
  else
    UpdateStatusText('Search stopped.');
end;

function TMainForm.ValidateInputs(out AFolder: string): Boolean;
var
  Folder: string;
  Folders: TArray<string>;
  MinSize: Int64;
  MaxSize: Int64;
  I: Integer;
begin
  Result := False;
  AFolder := Trim(FolderEdit.Text);
  Folders := AFolder.Split([',']);
  if AFolder = '' then
  begin
    TDialogService.MessageDialog('Choose at least one valid root folder before starting the search.',
      TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
    Exit;
  end;

  for I := Low(Folders) to High(Folders) do
  begin
    Folder := Trim(Folders[I]);
    if (Folder = '') or not TDirectory.Exists(Folder) then
    begin
      TDialogService.MessageDialog('Choose valid comma-separated root folders before starting the search.',
        TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
      Exit;
    end;
  end;

  if Trim(SearchTextEdit.Text) = '' then
  begin
    TDialogService.MessageDialog('Enter text or a regex pattern to search for.',
      TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
    Exit;
  end;

  if Trim(WildcardsEdit.Text) = '' then
    WildcardsEdit.Text := '*.*';

  if (Trim(MinSizeEdit.Text) <> '') and not TryStrToInt64(Trim(MinSizeEdit.Text), MinSize) then
  begin
    TDialogService.MessageDialog('The minimum file size must be a whole number.',
      TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
    Exit;
  end;

  if (Trim(MaxSizeEdit.Text) <> '') and not TryStrToInt64(Trim(MaxSizeEdit.Text), MaxSize) then
  begin
    TDialogService.MessageDialog('The maximum file size must be a whole number.',
      TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
    Exit;
  end;

  if (Trim(MinSizeEdit.Text) <> '') and (Trim(MaxSizeEdit.Text) <> '') and (MinSize > MaxSize) then
  begin
    TDialogService.MessageDialog('The minimum file size cannot be greater than the maximum file size.',
      TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
    Exit;
  end;

  if UseDateFromSwitch.IsChecked and UseDateToSwitch.IsChecked and (DateFromEdit.Date > DateToEdit.Date) then
  begin
    TDialogService.MessageDialog('The "from" date cannot be after the "to" date.',
      TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
    Exit;
  end;

  if RegexSwitch.IsChecked then
  begin
    try
      TRegEx.Create(SearchTextEdit.Text);
    except
      on E: Exception do
      begin
        TDialogService.MessageDialog('The regex pattern is invalid: ' + E.Message,
          TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
        Exit;
      end;
    end;
  end;

  Result := True;
end;

function TMainForm.BuildMatchDataList(AContents: TObjectList<TMatchedLines>): TObjectList<TMatchesData>;
var
  SourceLines: TStringList;
  Match: TMatchedLines;
  MatchData: TMatchesData;
  StartIndex: Integer;
  EndIndex: Integer;
  I: Integer;
  FileTimestamp: TDateTime;
begin
  Result := TObjectList<TMatchesData>.Create(True);
  if (AContents = nil) or (AContents.Count = 0) then
    Exit;

  SourceLines := TStringList.Create;
  try
    SourceLines.LoadFromFile(AContents[0].Filename);
    FileTimestamp := TFile.GetLastWriteTime(AContents[0].Filename);

    for Match in AContents do
    begin
      MatchData := TMatchesData.Create;
      MatchData.Filename := Match.Filename;
      MatchData.FileTimestamp := FileTimestamp;
      MatchData.LineNumber := Match.LineNumber;
      MatchData.MatchValue := Match.MatchedValue;

      StartIndex := Max(0, Match.LineNumber - FCurrentLinesAround - 1);
      EndIndex := Match.LineNumber - 2;
      for I := StartIndex to EndIndex do
        if (I >= 0) and (I < SourceLines.Count) then
          MatchData.LinesAbove.Add(SourceLines[I]);

      StartIndex := Match.LineNumber;
      EndIndex := Min(SourceLines.Count - 1, Match.LineNumber + FCurrentLinesAround - 1);
      for I := StartIndex to EndIndex do
        if (I >= 0) and (I < SourceLines.Count) then
          MatchData.LinesBelow.Add(SourceLines[I]);

      Result.Add(MatchData);
    end;
  finally
    SourceLines.Free;
  end;
end;

procedure TMainForm.HandleFileFound(const AFileName: string);
var
  FileCount: Integer;
  SearchRequestId: Integer;
begin
  SearchRequestId := TInterlocked.Add(FSearchRequestId, 0);
  FileCount := TInterlocked.Increment(FMatchedFiles);
  TInterlocked.Increment(FPendingMatchRequests);
  FGrep.RequestMatches(AFileName, FCurrentLinesAround);

  TThread.Queue(nil,
    procedure
    begin
      if SearchRequestId <> TInterlocked.Add(FSearchRequestId, 0) then
        Exit;

      UpdateStatusText(Format('Collecting match details from %d file(s)...', [FileCount]));
    end);
end;

procedure TMainForm.HandleRequestedContents(AContents: TObjectList<TMatchedLines>);
var
  BuiltMatches: TObjectList<TMatchesData>;
  SearchRequestId: Integer;
begin
  SearchRequestId := TInterlocked.Add(FSearchRequestId, 0);
  BuiltMatches := BuildMatchDataList(AContents);
  TThread.Queue(nil,
    procedure
    var
      Remaining: Integer;
    begin
      if SearchRequestId <> TInterlocked.Add(FSearchRequestId, 0) then
      begin
        BuiltMatches.Free;
        Exit;
      end;

      try
        FMatchesDisplay.AddMatches(BuiltMatches);
        UpdateResultSummary;
      finally
        BuiltMatches.Free;
        Remaining := TInterlocked.Decrement(FPendingMatchRequests);
        if Remaining < 0 then
          TInterlocked.Exchange(FPendingMatchRequests, 0);
        FinalizeSearchIfReady(SearchRequestId);
      end;
    end);
end;

procedure TMainForm.HandleSearchCompleted;
var
  SearchRequestId: Integer;
begin
  SearchRequestId := TInterlocked.Add(FSearchRequestId, 0);
  TInterlocked.Exchange(FSearchFinished, 1);
  TThread.Queue(nil,
    procedure
    begin
      FinalizeSearchIfReady(SearchRequestId);
    end);
end;

procedure TMainForm.FinalizeSearchIfReady(const ASearchRequestId: Integer);
var
  Pending: Integer;
  FileCount: Integer;
  ResultCount: Integer;
begin
  if ASearchRequestId <> TInterlocked.Add(FSearchRequestId, 0) then
    Exit;

  Pending := TInterlocked.Add(FPendingMatchRequests, 0);
  if (not FSearching) or (TInterlocked.Add(FSearchFinished, 0) = 0) or (Pending <> 0) then
    Exit;

  FSearching := False;
  UpdateSearchUi(False);

  FileCount := TInterlocked.Add(FMatchedFiles, 0);
  ResultCount := FMatchesDisplay.Count;

  if ReplaceModeSwitch.IsChecked then
    UpdateStatusText(Format('Replace complete. %d file(s) changed.', [FileCount]))
  else
    UpdateStatusText(Format('Search complete. %d match result(s) across %d file(s).',
      [ResultCount, FileCount]));
end;

end.
