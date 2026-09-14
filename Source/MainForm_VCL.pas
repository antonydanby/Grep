unit MainForm_VCL;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.ShellAPI,
  System.SysUtils,
  System.UITypes,
  System.Classes,
  System.Math,
  System.IOUtils,
  System.SyncObjs,
  System.DateUtils,
  System.RegularExpressions,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Samples.Spin,
  Vcl.FileCtrl,
  Grep.Core,
  MatchesList;

type
  TMainForm = class(TForm)
    HeaderPanel: TPanel;
    TitleLabel: TLabel;
    SubtitleLabel: TLabel;
    btnSearch: TButton;
    btnClear: TButton;
    btnStop: TButton;
    BodyPanel: TPanel;
    FiltersPanel: TPanel;
    FiltersScrollBox: TScrollBox;
    SearchCard: TPanel;
    lblFolder: TLabel;
    edtFolder: TEdit;
    btnBrowse: TButton;
    lblFind: TLabel;
    edtSearchText: TEdit;
    lblReplace: TLabel;
    edtReplaceText: TEdit;
    lblWildcards: TLabel;
    edtWildcards: TEdit;
    lblContextLines: TLabel;
    spnContextLines: TSpinEdit;
    swRegex: TCheckBox;
    swCaseSensitive: TCheckBox;
    swReplaceMode: TCheckBox;
    FiltersCard: TPanel;
    swIncludeSubfolders: TCheckBox;
    swIncludeHidden: TCheckBox;
    swIncludeBinary: TCheckBox;
    swUseDateFrom: TCheckBox;
    dtpDateFrom: TDateTimePicker;
    swUseDateTo: TCheckBox;
    dtpDateTo: TDateTimePicker;
    lblMinSize: TLabel;
    edtMinSize: TEdit;
    lblMaxSize: TLabel;
    edtMaxSize: TEdit;
    ResultsPanel: TPanel;
    SearchCardTitle: TLabel;
    FiltersCardTitle: TLabel;
    SearchCardDivider: TShape;
    FiltersCardDivider: TShape;
    MatchesPanel: TPanel;
    MatchesListView: TListView;
    TogglePanel: TPanel;
    Panel1: TPanel;
    ResultsHeaderPanel: TPanel;
    ResultsTitleLabel: TLabel;
    ResultsStatusLabel: TLabel;
    ProgressBar: TProgressBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure ToggleModeChanged(Sender: TObject);
    procedure MatchesListViewSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure TogglePanelClick(Sender: TObject);
    procedure TogglePanelPaint(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FGrep: TGrep;
    FMatches: TMatchesList;
    FFileMatches: TObjectList<TFileMatches>;
    FPendingMatchRequests: Integer;
    FMatchedFiles: Integer;
    FSearchFinished: Integer;
    FSearchRequestId: Integer;
    FCurrentLinesAround: Integer;
    FSearching: Boolean;

    FToggleMatch: TMatchesData;
    FToggleFileMatches: TFileMatches;
    FToggleMatchIndex: Integer;
    FToggleItemIndex: Integer;
    FWrappedAbove: TStringList;
    FWrappedMatch: TStringList;
    FWrappedBelow: TStringList;
    FTogglePaintBox: TPaintBox;
    FOpenButton: TButton;
    FPreviousMatchButton: TButton;
    FNextMatchButton: TButton;
    FMatchPositionLabel: TLabel;

    procedure ConfigureGrepFromForm;
    procedure ClearResults;
    procedure FinalizeSearchIfReady(const ASearchRequestId: Integer);
    procedure StopSearch;
    procedure UpdateSearchUi(const ASearching: Boolean);
    function ValidateInputs(out AFolder: string): Boolean;
    function BuildMatchDataList(AContents: TObjectList<TMatchedLines>): TObjectList<TMatchesData>;
    procedure UpdateModeState;
    procedure UpdateResultSummary;
    procedure UpdateStatusText(const AText: string);
    procedure HandleFileFound(const aFilename: string);
    procedure HandleRequestedContents(aContents: TObjectList<TMatchedLines>);
    procedure HandleSearchCompleted;

    procedure AddMatchToListView(const AMatch: TMatchesData);
    function FindFileMatches(const AFilename: string): TFileMatches;
    procedure SetToggleMatchIndex(const AIndex: Integer);
    function CalculateToggleHeight(const AMatch: TMatchesData): Integer;
    procedure ExpandToggleForItem(AItem: TListItem);
    procedure CollapseTogglePanel(const AKeepSelection: Boolean);
    procedure BuildToggleWrappedLines;
    procedure OpenButtonClick(Sender: TObject);
    procedure PreviousMatchButtonClick(Sender: TObject);
    procedure NextMatchButtonClick(Sender: TObject);
    procedure TogglePaintBoxPaint(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure AddWrappedParagraph(ACanvas: TCanvas; ALines: TStrings; const AParagraph: string;
  const AMaxWidth: Integer);
var
  Remaining: string;
  BreakPos: Integer;
  LastSpace: Integer;
  Prefix: string;
  Low: Integer;
  High: Integer;
  Mid: Integer;
  Best: Integer;
begin
  if AParagraph = '' then
  begin
    ALines.Add('');
    Exit;
  end;

  Remaining := AParagraph;
  while Remaining <> '' do
  begin
    if (AMaxWidth <= 0) or (ACanvas.TextWidth(Remaining) <= AMaxWidth) then
    begin
      ALines.Add(Remaining);
      Exit;
    end;

    Low := 1;
    High := Length(Remaining);
    Best := 1;
    while Low <= High do
    begin
      Mid := (Low + High) div 2;
      Prefix := Copy(Remaining, 1, Mid);
      if ACanvas.TextWidth(Prefix) <= AMaxWidth then
      begin
        Best := Mid;
        Low := Mid + 1;
      end
      else
        High := Mid - 1;
    end;

    BreakPos := Best;
    LastSpace := BreakPos;
    while (LastSpace > 1) and (Remaining[LastSpace] <> ' ') do
      Dec(LastSpace);

    if LastSpace > 1 then
      BreakPos := LastSpace;

    ALines.Add(Copy(Remaining, 1, BreakPos));
    Delete(Remaining, 1, BreakPos);
  end;
end;

procedure BuildWrappedLines(ACanvas: TCanvas; ASourceLines, ADestination: TStrings;
  const AMaxWidth: Integer);
var
  I: Integer;
begin
  ADestination.Clear;
  for I := 0 to ASourceLines.Count - 1 do
    AddWrappedParagraph(ACanvas, ADestination, ASourceLines[I], AMaxWidth);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FGrep := TGrep.Create;
  FGrep.OnFileFound := HandleFileFound;
  FGrep.OnRequestedContents := HandleRequestedContents;
  FGrep.OnSearchCompleted := HandleSearchCompleted;

  FMatches := TMatchesList.Create(Self);
  FFileMatches := TObjectList<TFileMatches>.Create(True);
  FToggleMatch := nil;
  FToggleFileMatches := nil;
  FToggleMatchIndex := -1;
  FToggleItemIndex := -1;
  FWrappedAbove := TStringList.Create;
  FWrappedMatch := TStringList.Create;
  FWrappedBelow := TStringList.Create;
  FTogglePaintBox := TPaintBox.Create(Self);
  FTogglePaintBox.Parent := TogglePanel;
  FTogglePaintBox.Align := alClient;
  FTogglePaintBox.OnPaint := TogglePaintBoxPaint;
  FTogglePaintBox.OnClick := TogglePanelClick;

  FOpenButton := TButton.Create(Self);
  FOpenButton.Parent := TogglePanel;
  FOpenButton.Caption := 'Open';
  FOpenButton.Width := 60;
  FOpenButton.Height := 25;
  FOpenButton.Left := TogglePanel.ClientWidth - 68;
  FOpenButton.Top := 8;
  FOpenButton.Anchors := [akTop, akRight];
  FOpenButton.OnClick := OpenButtonClick;
  FOpenButton.BringToFront;

  FMatchPositionLabel := TLabel.Create(Self);
  FMatchPositionLabel.Parent := TogglePanel;
  FMatchPositionLabel.Width := 60;
  FMatchPositionLabel.Height := 17;
  FMatchPositionLabel.Left := TogglePanel.ClientWidth - 68;
  FMatchPositionLabel.Top := 38;
  FMatchPositionLabel.Alignment := taCenter;
  FMatchPositionLabel.Font.Style := [fsBold];
  FMatchPositionLabel.Anchors := [akTop, akRight];

  FPreviousMatchButton := TButton.Create(Self);
  FPreviousMatchButton.Parent := TogglePanel;
  FPreviousMatchButton.Caption := 'Up';
  FPreviousMatchButton.Width := 60;
  FPreviousMatchButton.Height := 22;
  FPreviousMatchButton.Left := TogglePanel.ClientWidth - 68;
  FPreviousMatchButton.Top := 58;
  FPreviousMatchButton.Anchors := [akTop, akRight];
  FPreviousMatchButton.OnClick := PreviousMatchButtonClick;

  FNextMatchButton := TButton.Create(Self);
  FNextMatchButton.Parent := TogglePanel;
  FNextMatchButton.Caption := 'Down';
  FNextMatchButton.Width := 60;
  FNextMatchButton.Height := 22;
  FNextMatchButton.Left := TogglePanel.ClientWidth - 68;
  FNextMatchButton.Top := 82;
  FNextMatchButton.Anchors := [akTop, akRight];
  FNextMatchButton.OnClick := NextMatchButtonClick;

  dtpDateFrom.Date := Now - 30;
  dtpDateTo.Date := Now;
  UpdateModeState;
  UpdateSearchUi(False);
  ClearResults;
  UpdateStatusText('Configure the search options and start a new Grep.');
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FGrep.Stop;
  FWrappedBelow.Free;
  FWrappedMatch.Free;
  FWrappedAbove.Free;
  FFileMatches.Free;
  FMatches.Free;
  FGrep.Free;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_UP:
      SetToggleMatchIndex(FToggleMatchIndex - 1);
    VK_DOWN:
      SetToggleMatchIndex(FToggleMatchIndex + 1);
    VK_PRIOR:
      SetToggleMatchIndex(0);
    VK_NEXT:
      if FToggleFileMatches <> nil then
        SetToggleMatchIndex(FToggleFileMatches.Count - 1);
  else
    Exit;
  end;
  Key := 0;
end;

procedure TMainForm.btnBrowseClick(Sender: TObject);
var
  SelectedFolder: string;
begin
  SelectedFolder := Trim(edtFolder.Text);
  if SelectDirectory('Choose the root folder', '', SelectedFolder) then
    edtFolder.Text := SelectedFolder;
end;

procedure TMainForm.btnSearchClick(Sender: TObject);
var
  Folder: string;
begin
  if FSearching then
    Exit;

  if not ValidateInputs(Folder) then
    Exit;

  ClearResults;
  ConfigureGrepFromForm;
  FCurrentLinesAround := spnContextLines.Value;
  TInterlocked.Increment(FSearchRequestId);
  TInterlocked.Exchange(FPendingMatchRequests, 0);
  TInterlocked.Exchange(FMatchedFiles, 0);
  TInterlocked.Exchange(FSearchFinished, 0);
  FSearching := True;
  UpdateSearchUi(True);

  if swReplaceMode.Checked then
    UpdateStatusText('Replacing matches...')
  else
    UpdateStatusText('Searching...');

  if swReplaceMode.Checked then
    FGrep.Replace(Folder)
  else
    FGrep.Search(Folder);
end;

procedure TMainForm.btnClearClick(Sender: TObject);
begin
  if FSearching then
    Exit;

  ClearResults;
  UpdateStatusText('Configure the search options and start a new Grep.');
end;

procedure TMainForm.btnStopClick(Sender: TObject);
begin
  StopSearch;
end;

procedure TMainForm.ToggleModeChanged(Sender: TObject);
begin
  UpdateModeState;
end;

procedure TMainForm.UpdateModeState;
begin
  edtReplaceText.Enabled := swReplaceMode.Checked;
  dtpDateFrom.Enabled := swUseDateFrom.Checked;
  dtpDateTo.Enabled := swUseDateTo.Checked;

  if swReplaceMode.Checked then
    btnSearch.Caption := 'Replace'
  else
    btnSearch.Caption := 'Search';
end;

procedure TMainForm.UpdateResultSummary;
begin
  ResultsTitleLabel.Caption := Format('Results (%d files)', [FFileMatches.Count]);
end;

procedure TMainForm.UpdateStatusText(const AText: string);
begin
  ResultsStatusLabel.Caption := AText;
end;

procedure TMainForm.ConfigureGrepFromForm;
var
  SizeValue: Int64;
begin
  if swRegex.Checked then
    FGrep.SearchMode := gsmRegex
  else
    FGrep.SearchMode := gsmText;

  FGrep.SearchText := Trim(edtSearchText.Text);
  FGrep.ReplaceText := edtReplaceText.Text;
  FGrep.CaseSensitive := swCaseSensitive.Checked;
  FGrep.Wildcards := Trim(edtWildcards.Text);
  FGrep.IncludeSubfolders := swIncludeSubfolders.Checked;
  FGrep.ExcludeHidden := not swIncludeHidden.Checked;
  FGrep.ExcludeBinary := not swIncludeBinary.Checked;

  if TryStrToInt64(Trim(edtMinSize.Text), SizeValue) then
    FGrep.MinSize := SizeValue
  else
    FGrep.MinSize := 0;

  if TryStrToInt64(Trim(edtMaxSize.Text), SizeValue) then
    FGrep.MaxSize := SizeValue
  else
    FGrep.MaxSize := High(Int64);

  if swUseDateFrom.Checked then
    FGrep.DateFrom := StartOfTheDay(dtpDateFrom.Date)
  else
    FGrep.DateFrom := 0;

  if swUseDateTo.Checked then
    FGrep.DateTo := EndOfTheDay(dtpDateTo.Date)
  else
    FGrep.DateTo := MaxDateTime;
end;

procedure TMainForm.ClearResults;
begin
  FMatches.Clear;
  FFileMatches.Clear;
  MatchesListView.Items.BeginUpdate;
  try
    MatchesListView.Items.Clear;
  finally
    MatchesListView.Items.EndUpdate;
  end;
  CollapseTogglePanel(False);
  UpdateResultSummary;
end;

procedure TMainForm.UpdateSearchUi(const ASearching: Boolean);
begin
  btnSearch.Enabled := not ASearching;
  btnClear.Enabled := not ASearching;
  btnClear.Visible := not ASearching;
  btnStop.Visible := ASearching;
  ProgressBar.Visible := ASearching;
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

  if swReplaceMode.Checked then
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
  AFolder := Trim(edtFolder.Text);
  Folders := AFolder.Split([',']);
  if AFolder = '' then
  begin
    MessageDlg('Choose at least one valid root folder before starting the search.', mtError, [mbOK], 0);
    Exit;
  end;

  for I := Low(Folders) to High(Folders) do
  begin
    Folder := Trim(Folders[I]);
    if (Folder = '') or not TDirectory.Exists(Folder) then
    begin
      MessageDlg('Choose valid comma-separated root folders before starting the search.', mtError, [mbOK], 0);
      Exit;
    end;
  end;

  if Trim(edtSearchText.Text) = '' then
  begin
    MessageDlg('Enter text or a regex pattern to search for.', mtError, [mbOK], 0);
    Exit;
  end;

  if Trim(edtWildcards.Text) = '' then
    edtWildcards.Text := '*.*';

  if (Trim(edtMinSize.Text) <> '') and not TryStrToInt64(Trim(edtMinSize.Text), MinSize) then
  begin
    MessageDlg('The minimum file size must be a whole number.', mtError, [mbOK], 0);
    Exit;
  end;

  if (Trim(edtMaxSize.Text) <> '') and not TryStrToInt64(Trim(edtMaxSize.Text), MaxSize) then
  begin
    MessageDlg('The maximum file size must be a whole number.', mtError, [mbOK], 0);
    Exit;
  end;

  if (Trim(edtMinSize.Text) <> '') and (Trim(edtMaxSize.Text) <> '') and (MinSize > MaxSize) then
  begin
    MessageDlg('The minimum file size cannot be greater than the maximum file size.', mtError, [mbOK], 0);
    Exit;
  end;

  if swUseDateFrom.Checked and swUseDateTo.Checked and (dtpDateFrom.Date > dtpDateTo.Date) then
  begin
    MessageDlg('The "from" date cannot be after the "to" date.', mtError, [mbOK], 0);
    Exit;
  end;

  if swRegex.Checked then
  begin
    try
      TRegEx.Create(edtSearchText.Text);
    except
      on E: Exception do
      begin
        MessageDlg('The regex pattern is invalid: ' + E.Message, mtError, [mbOK], 0);
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

procedure TMainForm.AddMatchToListView(const AMatch: TMatchesData);
var
  Item: TListItem;
  FileMatches: TFileMatches;
  I: Integer;
begin
  FileMatches := FindFileMatches(AMatch.Filename);
  if FileMatches = nil then
  begin
    FileMatches := TFileMatches.Create(AMatch.Filename);
    FFileMatches.Add(FileMatches);
  end;
  FileMatches.Add(AMatch);

  for I := 0 to MatchesListView.Items.Count - 1 do
    if MatchesListView.Items[I].Data = FileMatches then
    begin
      MatchesListView.Items[I].SubItems[0] := IntToStr(FileMatches.Count);
      Exit;
    end;

  Item := MatchesListView.Items.Add;
  Item.Caption := FileMatches.Filename;
  Item.SubItems.Add(IntToStr(FileMatches.Count));
  Item.SubItems.Add(AMatch.MatchValue);
  Item.Data := FileMatches;
end;

function TMainForm.FindFileMatches(const AFilename: string): TFileMatches;
var
  FileMatches: TFileMatches;
begin
  Result := nil;
  for FileMatches in FFileMatches do
    if SameText(FileMatches.Filename, AFilename) then
      Exit(FileMatches);
end;

function TMainForm.CalculateToggleHeight(const AMatch: TMatchesData): Integer;
var
  TitleHeight: Integer;
  LineHeight: Integer;
  TotalHeight: Integer;
  MaxAvailableHeight: Integer;
begin
  FToggleMatch := AMatch;
  BuildToggleWrappedLines;

  FTogglePaintBox.Canvas.Font.Name := 'Segoe UI Semibold';
  FTogglePaintBox.Canvas.Font.Size := 9;
  TitleHeight := FTogglePaintBox.Canvas.TextHeight('Wg');

  FTogglePaintBox.Canvas.Font.Name := 'Consolas';
  FTogglePaintBox.Canvas.Font.Size := 9;
  LineHeight := FTogglePaintBox.Canvas.TextHeight('Wg') + 2;

  TotalHeight := 8 + TitleHeight + 6;
  Inc(TotalHeight, FWrappedAbove.Count * LineHeight);
  Inc(TotalHeight, Max(1, FWrappedMatch.Count) * LineHeight);
  Inc(TotalHeight, FWrappedBelow.Count * LineHeight);
  Inc(TotalHeight, 16);

  MaxAvailableHeight := Max(120, MatchesPanel.ClientHeight - ResultsHeaderPanel.Height - 24);
  Result := EnsureRange(TotalHeight, 112, MaxAvailableHeight);
end;

procedure TMainForm.ExpandToggleForItem(AItem: TListItem);
begin
  if (AItem = nil) or (AItem.Data = nil) then
  begin
    CollapseTogglePanel(False);
    Exit;
  end;

  FToggleFileMatches := TFileMatches(AItem.Data);
  FToggleItemIndex := AItem.Index;
  SetToggleMatchIndex(0);
  TogglePanel.Visible := True;
  AItem.MakeVisible(False);
end;

procedure TMainForm.SetToggleMatchIndex(const AIndex: Integer);
begin
  if (FToggleFileMatches = nil) or (AIndex < 0) or (AIndex >= FToggleFileMatches.Count) then
    Exit;

  FToggleMatchIndex := AIndex;
  FToggleMatch := FToggleFileMatches[AIndex];
  TogglePanel.Height := CalculateToggleHeight(FToggleMatch);
  FMatchPositionLabel.Caption := Format('%d/%d', [AIndex + 1, FToggleFileMatches.Count]);
  FPreviousMatchButton.Enabled := AIndex > 0;
  FNextMatchButton.Enabled := AIndex < FToggleFileMatches.Count - 1;
  FTogglePaintBox.Invalidate;
end;

procedure TMainForm.CollapseTogglePanel(const AKeepSelection: Boolean);
begin
  TogglePanel.Height := 0;
  TogglePanel.Visible := False;
  FToggleFileMatches := nil;
  FToggleMatch := nil;
  FToggleMatchIndex := -1;

  if AKeepSelection and (FToggleItemIndex >= 0) and (FToggleItemIndex < MatchesListView.Items.Count) then
  begin
    MatchesListView.ItemFocused := MatchesListView.Items[FToggleItemIndex];
    MatchesListView.Selected := MatchesListView.Items[FToggleItemIndex];
    MatchesListView.Items[FToggleItemIndex].MakeVisible(False);
    MatchesListView.SetFocus;
  end;
end;

procedure TMainForm.PreviousMatchButtonClick(Sender: TObject);
begin
  SetToggleMatchIndex(FToggleMatchIndex - 1);
end;

procedure TMainForm.NextMatchButtonClick(Sender: TObject);
begin
  SetToggleMatchIndex(FToggleMatchIndex + 1);
end;

procedure TMainForm.BuildToggleWrappedLines;
var
  MaxWidth: Integer;
  MatchLineSource: TStringList;
begin
  if FToggleMatch = nil then
    Exit;

  MaxWidth := Max(120, MatchesListView.ClientWidth - 104);
  FTogglePaintBox.Canvas.Font.Name := 'Consolas';
  FTogglePaintBox.Canvas.Font.Size := 9;
  FTogglePaintBox.Canvas.Font.Style := [];
  BuildWrappedLines(FTogglePaintBox.Canvas, FToggleMatch.LinesAbove, FWrappedAbove, MaxWidth);
  BuildWrappedLines(FTogglePaintBox.Canvas, FToggleMatch.LinesBelow, FWrappedBelow, MaxWidth);

  MatchLineSource := TStringList.Create;
  try
    MatchLineSource.Add(FToggleMatch.MatchValue);
    BuildWrappedLines(FTogglePaintBox.Canvas, MatchLineSource, FWrappedMatch, MaxWidth);
  finally
    MatchLineSource.Free;
  end;
end;

procedure TMainForm.TogglePanelPaint(Sender: TObject);
begin
  TogglePaintBoxPaint(Sender);
end;

procedure TMainForm.TogglePaintBoxPaint(Sender: TObject);
var
  R: TRect;
  TopPos: Integer;
  LineHeight: Integer;
  I: Integer;
  TitleText: string;
begin
  FTogglePaintBox.Canvas.Brush.Color := clWhite;
  FTogglePaintBox.Canvas.FillRect(FTogglePaintBox.ClientRect);
  FTogglePaintBox.Canvas.Pen.Color := RGB(224, 229, 236);
  FTogglePaintBox.Canvas.MoveTo(0, 0);
  FTogglePaintBox.Canvas.LineTo(FTogglePaintBox.Width, 0);

  if FToggleMatch = nil then
    Exit;

  BuildToggleWrappedLines;
  TopPos := 8;

  FTogglePaintBox.Canvas.Font.Name := 'Segoe UI Semibold';
  FTogglePaintBox.Canvas.Font.Size := 9;
  FTogglePaintBox.Canvas.Font.Style := [fsBold];
  FTogglePaintBox.Canvas.Font.Color := RGB(32, 45, 64);
  TitleText := Format('%s (Line %d)', [FToggleMatch.Filename, FToggleMatch.LineNumber]);
  FTogglePaintBox.Canvas.TextOut(12, TopPos, TitleText);
  Inc(TopPos, FTogglePaintBox.Canvas.TextHeight('Wg') + 6);

  FTogglePaintBox.Canvas.Font.Name := 'Consolas';
  FTogglePaintBox.Canvas.Font.Size := 9;
  FTogglePaintBox.Canvas.Font.Style := [];
  FTogglePaintBox.Canvas.Font.Color := RGB(110, 117, 129);
  LineHeight := FTogglePaintBox.Canvas.TextHeight('Wg') + 2;
  for I := 0 to FWrappedAbove.Count - 1 do
  begin
    FTogglePaintBox.Canvas.TextOut(12, TopPos, FWrappedAbove[I]);
    Inc(TopPos, LineHeight);
  end;

  if FWrappedMatch.Count > 0 then
  begin
    R := Rect(8, TopPos - 1, FTogglePaintBox.ClientWidth - 8, TopPos + (FWrappedMatch.Count * LineHeight) + 2);
    FTogglePaintBox.Canvas.Brush.Color := RGB(231, 242, 255);
    FTogglePaintBox.Canvas.FillRect(R);
    FTogglePaintBox.Canvas.Font.Style := [fsBold];
    FTogglePaintBox.Canvas.Font.Color := RGB(25, 61, 122);
    for I := 0 to FWrappedMatch.Count - 1 do
    begin
      FTogglePaintBox.Canvas.TextOut(12, TopPos, FWrappedMatch[I]);
      Inc(TopPos, LineHeight);
    end;
    FTogglePaintBox.Canvas.Font.Style := [];
    FTogglePaintBox.Canvas.Font.Color := RGB(110, 117, 129);
  end;

  for I := 0 to FWrappedBelow.Count - 1 do
  begin
    FTogglePaintBox.Canvas.TextOut(12, TopPos, FWrappedBelow[I]);
    Inc(TopPos, LineHeight);
  end;
end;

procedure TMainForm.OpenButtonClick(Sender: TObject);
var
  OpenResult: HINST;
begin
  if (FToggleMatch = nil) or not TFile.Exists(FToggleMatch.Filename) then
  begin
    MessageDlg('The matched file is no longer available.', mtError, [mbOK], 0);
    Exit;
  end;

  OpenResult := ShellExecute(Handle, 'open', PChar(FToggleMatch.Filename), nil, nil, SW_SHOWNORMAL);
  if OpenResult <= 32 then
  begin
    OpenResult := ShellExecute(Handle, 'open', 'notepad.exe', PChar(FToggleMatch.Filename), nil, SW_SHOWNORMAL);
    if OpenResult <= 32 then
      MessageDlg('Unable to open the matched file.', mtError, [mbOK], 0);
  end;
end;

procedure TMainForm.TogglePanelClick(Sender: TObject);
begin
  CollapseTogglePanel(True);
end;

procedure TMainForm.MatchesListViewSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if not Selected then
    Exit;
  ExpandToggleForItem(Item);
end;

procedure TMainForm.HandleFileFound(const aFilename: string);
var
  FileCount: Integer;
  SearchRequestId: Integer;
begin
  SearchRequestId := TInterlocked.Add(FSearchRequestId, 0);
  FileCount := TInterlocked.Increment(FMatchedFiles);
  TInterlocked.Increment(FPendingMatchRequests);
  FGrep.RequestMatches(aFilename, FCurrentLinesAround);

  TThread.Queue(nil,
    procedure
    begin
      if SearchRequestId <> TInterlocked.Add(FSearchRequestId, 0) then
        Exit;

      UpdateStatusText(Format('Collecting match details from %d file(s)...', [FileCount]));
    end);
end;

procedure TMainForm.HandleRequestedContents(aContents: TObjectList<TMatchedLines>);
var
  BuiltMatches: TObjectList<TMatchesData>;
  SearchRequestId: Integer;
begin
  SearchRequestId := TInterlocked.Add(FSearchRequestId, 0);
  BuiltMatches := BuildMatchDataList(aContents);
  TThread.Queue(nil,
    procedure
    var
      I: Integer;
      MatchData: TMatchesData;
      Remaining: Integer;
    begin
      if SearchRequestId <> TInterlocked.Add(FSearchRequestId, 0) then
      begin
        BuiltMatches.Free;
        Exit;
      end;

      try
        MatchesListView.Items.BeginUpdate;
        try
          for I := 0 to BuiltMatches.Count - 1 do
          begin
            MatchData := BuiltMatches[I];
            FMatches.Add(MatchData);
            AddMatchToListView(MatchData);
          end;
        finally
          MatchesListView.Items.EndUpdate;
        end;

        BuiltMatches.OwnsObjects := False;
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
  ResultCount := FMatches.Count;

  if swReplaceMode.Checked then
    UpdateStatusText(Format('Replace complete. %d file(s) changed.', [FileCount]))
  else
    UpdateStatusText(Format('Search complete. %d match result(s) across %d file(s).',
      [ResultCount, FileCount]));
end;

end.
