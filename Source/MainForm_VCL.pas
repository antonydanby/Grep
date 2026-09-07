unit MainForm_VCL;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
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
  Vcl.WinXCtrls,
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
    lblRegex: TLabel;
    swRegex: TToggleSwitch;
    lblCaseSensitive: TLabel;
    swCaseSensitive: TToggleSwitch;
    lblReplaceMode: TLabel;
    swReplaceMode: TToggleSwitch;
    FiltersCard: TPanel;
    lblIncludeSubfolders: TLabel;
    swIncludeSubfolders: TToggleSwitch;
    lblIncludeHidden: TLabel;
    swIncludeHidden: TToggleSwitch;
    lblIncludeBinary: TLabel;
    lblUseDateFrom: TLabel;
    swUseDateFrom: TToggleSwitch;
    dtpDateFrom: TDateTimePicker;
    lblUseDateTo: TLabel;
    swUseDateTo: TToggleSwitch;
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
    swIncludeBinary: TToggleSwitch;
    MatchesPanel: TPanel;
    MatchesListView: TListView;
    TogglePanel: TPanel;
    Panel1: TPanel;
    ResultsHeaderPanel: TPanel;
    ResultsTitleLabel: TLabel;
    ResultsStatusLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure ToggleModeChanged(Sender: TObject);
    procedure MatchesListViewSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure TogglePanelClick(Sender: TObject);
    procedure TogglePanelPaint(Sender: TObject);
  private
    FGrep: TGrep;
    FMatches: TMatchesList;
    FPendingMatchRequests: Integer;
    FMatchedFiles: Integer;
    FSearchFinished: Integer;
    FCurrentLinesAround: Integer;
    FSearching: Boolean;

    FToggleMatch: TMatchesData;
    FToggleItemIndex: Integer;
    FWrappedAbove: TStringList;
    FWrappedMatch: TStringList;
    FWrappedBelow: TStringList;
    FTogglePaintBox: TPaintBox;

    procedure ConfigureGrepFromForm;
    procedure ClearResults;
    procedure FinalizeSearchIfReady;
    function ValidateInputs(out AFolder: string): Boolean;
    function BuildMatchDataList(AContents: TObjectList<TMatchedLines>): TObjectList<TMatchesData>;
    procedure UpdateModeState;
    procedure UpdateResultSummary;
    procedure UpdateStatusText(const AText: string);
    procedure HandleFileFound(const aFilename: string);
    procedure HandleRequestedContents(aContents: TObjectList<TMatchedLines>);
    procedure HandleSearchCompleted;

    procedure AddMatchToListView(const AMatch: TMatchesData);
    function CalculateToggleHeight(const AMatch: TMatchesData): Integer;
    procedure ExpandToggleForItem(AItem: TListItem);
    procedure CollapseTogglePanel(const AKeepSelection: Boolean);
    procedure BuildToggleWrappedLines;
    procedure TogglePaintBoxPaint(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure AddWrappedParagraph(ACanvas: TCanvas; ALines: TStrings; const AParagraph: string;
  const AMaxWidth: Integer);
var
  Words: TStringList;
  CurrentLine: string;
  Candidate: string;
  I: Integer;
begin
  if AParagraph = '' then
  begin
    ALines.Add('');
    Exit;
  end;

  Words := TStringList.Create;
  try
    ExtractStrings([' '], [], PChar(AParagraph), Words);
    if Words.Count = 0 then
    begin
      ALines.Add(AParagraph);
      Exit;
    end;

    CurrentLine := '';
    for I := 0 to Words.Count - 1 do
    begin
      if CurrentLine = '' then
        Candidate := Words[I]
      else
        Candidate := CurrentLine + ' ' + Words[I];

      if (AMaxWidth > 0) and (CurrentLine <> '') and (ACanvas.TextWidth(Candidate) > AMaxWidth) then
      begin
        ALines.Add(CurrentLine);
        CurrentLine := Words[I];
      end
      else
        CurrentLine := Candidate;
    end;

    if CurrentLine <> '' then
      ALines.Add(CurrentLine);
  finally
    Words.Free;
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
  FToggleMatch := nil;
  FToggleItemIndex := -1;
  FWrappedAbove := TStringList.Create;
  FWrappedMatch := TStringList.Create;
  FWrappedBelow := TStringList.Create;
  FTogglePaintBox := TPaintBox.Create(Self);
  FTogglePaintBox.Parent := TogglePanel;
  FTogglePaintBox.Align := alClient;
  FTogglePaintBox.OnPaint := TogglePaintBoxPaint;
  FTogglePaintBox.OnClick := TogglePanelClick;

  dtpDateFrom.Date := Now - 30;
  dtpDateTo.Date := Now;
  UpdateModeState;
  ClearResults;
  UpdateStatusText('Configure the search options and start a new Grep.');
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FWrappedBelow.Free;
  FWrappedMatch.Free;
  FWrappedAbove.Free;
  FMatches.Free;
  FGrep.Free;
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
  TInterlocked.Exchange(FPendingMatchRequests, 0);
  TInterlocked.Exchange(FMatchedFiles, 0);
  TInterlocked.Exchange(FSearchFinished, 0);
  FSearching := True;
  btnSearch.Enabled := False;
  btnClear.Enabled := False;

  if swReplaceMode.State = tssOn then
    UpdateStatusText('Replacing matches...')
  else
    UpdateStatusText('Searching...');

  if swReplaceMode.State = tssOn then
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

procedure TMainForm.ToggleModeChanged(Sender: TObject);
begin
  UpdateModeState;
end;

procedure TMainForm.UpdateModeState;
begin
  edtReplaceText.Enabled := swReplaceMode.State = tssOn;
  dtpDateFrom.Enabled := swUseDateFrom.State = tssOn;
  dtpDateTo.Enabled := swUseDateTo.State = tssOn;

  if swReplaceMode.State = tssOn then
    btnSearch.Caption := 'Replace'
  else
    btnSearch.Caption := 'Search';
end;

procedure TMainForm.UpdateResultSummary;
begin
  ResultsTitleLabel.Caption := Format('Results (%d)', [FMatches.Count]);
end;

procedure TMainForm.UpdateStatusText(const AText: string);
begin
  ResultsStatusLabel.Caption := AText;
end;

procedure TMainForm.ConfigureGrepFromForm;
var
  SizeValue: Int64;
begin
  if swRegex.State = tssOn then
    FGrep.SearchMode := gsmRegex
  else
    FGrep.SearchMode := gsmText;

  FGrep.SearchText := Trim(edtSearchText.Text);
  FGrep.ReplaceText := edtReplaceText.Text;
  FGrep.CaseSensitive := swCaseSensitive.State = tssOn;
  FGrep.Wildcards := Trim(edtWildcards.Text);
  FGrep.IncludeSubfolders := swIncludeSubfolders.State = tssOn;
  FGrep.ExcludeHidden := swIncludeHidden.State <> tssOn;
  FGrep.ExcludeBinary := swIncludeBinary.State <> tssOn;

  if TryStrToInt64(Trim(edtMinSize.Text), SizeValue) then
    FGrep.MinSize := SizeValue
  else
    FGrep.MinSize := 0;

  if TryStrToInt64(Trim(edtMaxSize.Text), SizeValue) then
    FGrep.MaxSize := SizeValue
  else
    FGrep.MaxSize := High(Int64);

  if swUseDateFrom.State = tssOn then
    FGrep.DateFrom := StartOfTheDay(dtpDateFrom.Date)
  else
    FGrep.DateFrom := 0;

  if swUseDateTo.State = tssOn then
    FGrep.DateTo := EndOfTheDay(dtpDateTo.Date)
  else
    FGrep.DateTo := MaxDateTime;
end;

procedure TMainForm.ClearResults;
begin
  FMatches.Clear;
  MatchesListView.Items.BeginUpdate;
  try
    MatchesListView.Items.Clear;
  finally
    MatchesListView.Items.EndUpdate;
  end;
  CollapseTogglePanel(False);
  UpdateResultSummary;
end;

function TMainForm.ValidateInputs(out AFolder: string): Boolean;
var
  MinSize: Int64;
  MaxSize: Int64;
begin
  Result := False;
  AFolder := Trim(edtFolder.Text);
  if (AFolder = '') or not TDirectory.Exists(AFolder) then
  begin
    MessageDlg('Choose a valid root folder before starting the search.', mtError, [mbOK], 0);
    Exit;
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

  if (swUseDateFrom.State = tssOn) and (swUseDateTo.State = tssOn) and (dtpDateFrom.Date > dtpDateTo.Date) then
  begin
    MessageDlg('The "from" date cannot be after the "to" date.', mtError, [mbOK], 0);
    Exit;
  end;

  if swRegex.State = tssOn then
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
begin
  Item := MatchesListView.Items.Add;
  Item.Caption := AMatch.Filename;
  Item.SubItems.Add(IntToStr(AMatch.LineNumber));
  Item.SubItems.Add(AMatch.MatchValue);
  Item.Data := AMatch;
end;

function TMainForm.CalculateToggleHeight(const AMatch: TMatchesData): Integer;
var
  LineHeight: Integer;
  EstimatedLines: Integer;
begin
  FTogglePaintBox.Canvas.Font.Name := 'Consolas';
  FTogglePaintBox.Canvas.Font.Size := 9;
  LineHeight := FTogglePaintBox.Canvas.TextHeight('Wg') + 2;

  EstimatedLines := 4 + AMatch.LinesAbove.Count + AMatch.LinesBelow.Count;
  Result := EnsureRange((EstimatedLines * LineHeight) + 30, 90, 300);
end;

procedure TMainForm.ExpandToggleForItem(AItem: TListItem);
begin
  if (AItem = nil) or (AItem.Data = nil) then
  begin
    CollapseTogglePanel(False);
    Exit;
  end;

  FToggleMatch := TMatchesData(AItem.Data);
  FToggleItemIndex := AItem.Index;
  TogglePanel.Height := CalculateToggleHeight(FToggleMatch);
  TogglePanel.Visible := True;
  FTogglePaintBox.Invalidate;
  AItem.MakeVisible(False);
end;

procedure TMainForm.CollapseTogglePanel(const AKeepSelection: Boolean);
begin
  TogglePanel.Height := 0;
  TogglePanel.Visible := False;

  if AKeepSelection and (FToggleItemIndex >= 0) and (FToggleItemIndex < MatchesListView.Items.Count) then
  begin
    MatchesListView.ItemFocused := MatchesListView.Items[FToggleItemIndex];
    MatchesListView.Selected := MatchesListView.Items[FToggleItemIndex];
    MatchesListView.Items[FToggleItemIndex].MakeVisible(False);
    MatchesListView.SetFocus;
  end;
end;

procedure TMainForm.BuildToggleWrappedLines;
var
  MaxWidth: Integer;
  MatchLineSource: TStringList;
begin
  if FToggleMatch = nil then
    Exit;

  MaxWidth := Max(120, TogglePanel.ClientWidth - 24);
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
begin
  FileCount := TInterlocked.Increment(FMatchedFiles);
  TInterlocked.Increment(FPendingMatchRequests);
  FGrep.RequestMatches(aFilename, FCurrentLinesAround);

  TThread.Queue(nil,
    procedure
    begin
      UpdateStatusText(Format('Collecting match details from %d file(s)...', [FileCount]));
    end);
end;

procedure TMainForm.HandleRequestedContents(aContents: TObjectList<TMatchedLines>);
var
  BuiltMatches: TObjectList<TMatchesData>;
begin
  BuiltMatches := BuildMatchDataList(aContents);
  TThread.Queue(nil,
    procedure
    var
      I: Integer;
      MatchData: TMatchesData;
      Remaining: Integer;
    begin
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
        FinalizeSearchIfReady;
      end;
    end);
end;

procedure TMainForm.HandleSearchCompleted;
begin
  TInterlocked.Exchange(FSearchFinished, 1);
  TThread.Queue(nil,
    procedure
    begin
      FinalizeSearchIfReady;
    end);
end;

procedure TMainForm.FinalizeSearchIfReady;
var
  Pending: Integer;
  FileCount: Integer;
  ResultCount: Integer;
begin
  Pending := TInterlocked.Add(FPendingMatchRequests, 0);
  if (TInterlocked.Add(FSearchFinished, 0) = 0) or (Pending <> 0) then
    Exit;

  FSearching := False;
  btnSearch.Enabled := True;
  btnClear.Enabled := True;

  FileCount := TInterlocked.Add(FMatchedFiles, 0);
  ResultCount := FMatches.Count;

  if swReplaceMode.State = tssOn then
    UpdateStatusText(Format('Replace complete. %d file(s) changed.', [FileCount]))
  else
    UpdateStatusText(Format('Search complete. %d match result(s) across %d file(s).',
      [ResultCount, FileCount]));
end;

end.
