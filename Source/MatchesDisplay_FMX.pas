unit MatchesDisplay_FMX;

interface

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Types,
  System.UITypes,
  System.IOUtils,
  System.Generics.Collections,
  Winapi.ShlObj,
  FMX.Types,
  FMX.Controls,
  FMX.DialogService,
  FMX.Graphics,
  FMX.StdCtrls,
  FMX.Objects,
  FMX.ListView,
  FMX.ListView.Types,
  FMX.ListView.Appearances,
  MatchesList;

type
  TMatchesData = MatchesList.TMatchesData;

  TMatchesDisplay = class
  private
    FListView: TListView;
    FDetailsPanel: TRectangle;
    FDetailsPaintBox: TPaintBox;
    FMatches: TMatchesList;
    FFileMatches: TObjectList<TFileMatches>;
    FSelectedFileMatches: TFileMatches;
    FSelectedMatch: TMatchesData;
    FSelectedMatchIndex: Integer;
    FExpanded: Boolean;
    FFileIcons: TDictionary<string, TBitmap>;
    FPreviousMatchButton: TButton;
    FNextMatchButton: TButton;
    FMatchPositionLabel: TLabel;
    FWrappedAbove: TStringList;
    FWrappedMatch: TStringList;
    FWrappedBelow: TStringList;
    procedure ConfigureListView;
    procedure ListViewItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure DetailsPaint(Sender: TObject; Canvas: TCanvas);
    procedure DetailsClick(Sender: TObject);
    procedure PreviousMatchButtonClick(Sender: TObject);
    procedure NextMatchButtonClick(Sender: TObject);
    procedure HideDetails;
    procedure UpdateDetails;
    procedure UpdateNavigationControls;
    procedure SetSelectedMatchIndex(const AIndex: Integer);
    procedure BuildWrappedDetails(ACanvas: TCanvas);
    function GetFileIcon(const AFileName: string): TBitmap;
    function FindFileMatches(const AFilename: string): TFileMatches;
    function CalculateDetailHeight(ACanvas: TCanvas): Single;
    procedure DrawTextLine(ACanvas: TCanvas; const ARect: TRectF; const AText: string;
      const AColor: TAlphaColor; const ASize: Single; const ABold: Boolean);
  public
    constructor Create(AOwner: TComponent; AListView: TListView; ADetailsPanel: TRectangle;
      ADetailsPaintBox: TPaintBox); overload;
    constructor Create(AOwner: TComponent; AListView: TListView; ADetailsPanel: TRectangle;
      ADetailsPaintBox: TPaintBox; AUnusedFileIcon: TBitmap); overload;
    destructor Destroy; override;
    procedure ClearBrowser;
    procedure AddMatch(const AData: TMatchesData);
    procedure AddMatches(const AData: TObjectList<TMatchesData>);
    function Count: Integer;
    function FileCount: Integer;
    function SelectPreviousMatch: Boolean;
    function SelectNextMatch: Boolean;
    function SelectFirstMatch: Boolean;
    function SelectLastMatch: Boolean;
    procedure OpenSelectedMatch;
    property Matches: TMatchesList read FMatches;
  end;

implementation

const
  cDetailsPadding = 14;
  cCollapsedHeight = 180;
  cMinListHeight = 120;

function NormalizePreviewText(const AText: string): string;
begin
  Result := StringReplace(AText, #13#10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

procedure AddWrappedParagraph(ACanvas: TCanvas; ALines: TStrings; const AParagraph: string;
  const AMaxWidth: Single);
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
  const AMaxWidth: Single);
var
  I: Integer;
begin
  ADestination.Clear;
  for I := 0 to ASourceLines.Count - 1 do
    AddWrappedParagraph(ACanvas, ADestination, ASourceLines[I], AMaxWidth);
end;

function CreateBitmapFromIcon(const AIcon: HICON): TBitmap;
var
  BitmapInfo: TBitmapInfo;
  BitmapData: TBitmapData;
  Bits: Pointer;
  IconDC: HDC;
  IconBitmap: HBITMAP;
  OldBitmap: HGDIOBJ;
  IconWidth: Integer;
  IconHeight: Integer;
  Row: Integer;
  SourceRow: PByte;
  DestinationRow: PByte;
begin
  Result := nil;
  IconWidth := GetSystemMetrics(SM_CXICON);
  IconHeight := GetSystemMetrics(SM_CYICON);
  if (AIcon = 0) or (IconWidth <= 0) or (IconHeight <= 0) then
    Exit;

  ZeroMemory(@BitmapInfo, SizeOf(BitmapInfo));
  BitmapInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  BitmapInfo.bmiHeader.biWidth := IconWidth;
  BitmapInfo.bmiHeader.biHeight := IconHeight;
  BitmapInfo.bmiHeader.biPlanes := 1;
  BitmapInfo.bmiHeader.biBitCount := 32;
  BitmapInfo.bmiHeader.biCompression := BI_RGB;

  Bits := nil;
  IconBitmap := CreateDIBSection(0, BitmapInfo, DIB_RGB_COLORS, Bits, 0, 0);
  if (IconBitmap = 0) or (Bits = nil) then
    Exit;

  IconDC := CreateCompatibleDC(0);
  if IconDC = 0 then
  begin
    DeleteObject(IconBitmap);
    Exit;
  end;

  OldBitmap := SelectObject(IconDC, IconBitmap);
  try
    ZeroMemory(Bits, IconWidth * IconHeight * SizeOf(Cardinal));
    if not DrawIconEx(IconDC, 0, 0, AIcon, IconWidth, IconHeight, 0, 0, DI_NORMAL) then
      Exit;

    Result := TBitmap.Create(IconWidth, IconHeight);
    if not Result.Map(TMapAccess.Write, BitmapData) then
    begin
      Result.Free;
      Result := nil;
      Exit;
    end;
    try
      for Row := 0 to IconHeight - 1 do
      begin
        SourceRow := PByte(NativeInt(Bits) + ((IconHeight - Row - 1) * IconWidth * SizeOf(Cardinal)));
        DestinationRow := PByte(NativeInt(BitmapData.Data) + (Row * BitmapData.Pitch));
        Move(SourceRow^, DestinationRow^, IconWidth * SizeOf(Cardinal));
      end;
    finally
      Result.Unmap(BitmapData);
    end;
  finally
    SelectObject(IconDC, OldBitmap);
    DeleteDC(IconDC);
    DeleteObject(IconBitmap);
  end;
end;

{ TMatchesDisplay }

constructor TMatchesDisplay.Create(AOwner: TComponent; AListView: TListView; ADetailsPanel: TRectangle;
  ADetailsPaintBox: TPaintBox);
begin
  inherited Create;
  FMatches := TMatchesList.Create(AOwner);
  FFileMatches := TObjectList<TFileMatches>.Create(True);
  FListView := AListView;
  FDetailsPanel := ADetailsPanel;
  FDetailsPaintBox := ADetailsPaintBox;
  FSelectedFileMatches := nil;
  FSelectedMatch := nil;
  FSelectedMatchIndex := -1;
  FExpanded := False;
  FFileIcons := TDictionary<string, TBitmap>.Create;
  FWrappedAbove := TStringList.Create;
  FWrappedMatch := TStringList.Create;
  FWrappedBelow := TStringList.Create;

  ConfigureListView;

  if (FDetailsPanel <> nil) and (FDetailsPaintBox <> nil) then
  begin
    FDetailsPaintBox.OnPaint := DetailsPaint;
    FDetailsPaintBox.OnClick := DetailsClick;
    FDetailsPanel.OnClick := DetailsClick;
    FMatchPositionLabel := TLabel.Create(AOwner);
    FMatchPositionLabel.Parent := FDetailsPanel;
    FMatchPositionLabel.Width := 60;
    FMatchPositionLabel.Height := 20;
    FMatchPositionLabel.Position.X := FDetailsPanel.Width - 74;
    FMatchPositionLabel.Position.Y := 60;
    FMatchPositionLabel.Anchors := [TAnchorKind.akTop, TAnchorKind.akRight];
    FMatchPositionLabel.TextSettings.Font.Style := [TFontStyle.fsBold];
    FMatchPositionLabel.TextSettings.HorzAlign := TTextAlign.Center;

    FPreviousMatchButton := TButton.Create(AOwner);
    FPreviousMatchButton.Parent := FDetailsPanel;
    FPreviousMatchButton.Text := 'Up';
    FPreviousMatchButton.Width := 60;
    FPreviousMatchButton.Height := 44;
    FPreviousMatchButton.Position.X := FDetailsPanel.Width - 74;
    FPreviousMatchButton.Position.Y := 82;
    FPreviousMatchButton.Anchors := [TAnchorKind.akTop, TAnchorKind.akRight];
    FPreviousMatchButton.OnClick := PreviousMatchButtonClick;

    FNextMatchButton := TButton.Create(AOwner);
    FNextMatchButton.Parent := FDetailsPanel;
    FNextMatchButton.Text := 'Down';
    FNextMatchButton.Width := 60;
    FNextMatchButton.Height := 44;
    FNextMatchButton.Position.X := FDetailsPanel.Width - 74;
    FNextMatchButton.Position.Y := 130;
    FNextMatchButton.Anchors := [TAnchorKind.akTop, TAnchorKind.akRight];
    FNextMatchButton.OnClick := NextMatchButtonClick;
    HideDetails;
  end;
end;

constructor TMatchesDisplay.Create(AOwner: TComponent; AListView: TListView; ADetailsPanel: TRectangle;
  ADetailsPaintBox: TPaintBox; AUnusedFileIcon: TBitmap);
begin
  Create(AOwner, AListView, ADetailsPanel, ADetailsPaintBox);
end;

destructor TMatchesDisplay.Destroy;
var
  FileIcon: TBitmap;
begin
  for FileIcon in FFileIcons.Values do
    FileIcon.Free;
  FFileIcons.Free;
  FFileMatches.Free;
  FWrappedBelow.Free;
  FWrappedMatch.Free;
  FWrappedAbove.Free;
  FMatches.Free;
  inherited;
end;

function TMatchesDisplay.FindFileMatches(const AFilename: string): TFileMatches;
var
  FileMatches: TFileMatches;
begin
  Result := nil;
  for FileMatches in FFileMatches do
    if SameText(FileMatches.Filename, AFilename) then
      Exit(FileMatches);
end;

function TMatchesDisplay.GetFileIcon(const AFileName: string): TBitmap;
var
  Extension: string;
  FileInfo: SHFILEINFO;
  Icon: HICON;
begin
  Result := nil;
  Extension := LowerCase(ExtractFileExt(AFileName));
  if FFileIcons.TryGetValue(Extension, Result) then
    Exit;

  ZeroMemory(@FileInfo, SizeOf(FileInfo));
  if SHGetFileInfo(PChar(AFileName), 0, FileInfo, SizeOf(FileInfo),
    SHGFI_ICON or SHGFI_LARGEICON) = 0 then
    Exit;

  Icon := FileInfo.hIcon;
  try
    Result := CreateBitmapFromIcon(Icon);
  finally
    DestroyIcon(Icon);
  end;

  if Result <> nil then
    FFileIcons.Add(Extension, Result);
end;

procedure TMatchesDisplay.ConfigureListView;
begin
  if FListView = nil then
    Exit;

  FListView.ItemAppearance.ItemAppearance := TAppearanceNames.ImageListItemBottomDetail;
  FListView.OnItemClick := ListViewItemClick;
end;

procedure TMatchesDisplay.ClearBrowser;
begin
  FMatches.Clear;
  FFileMatches.Clear;
  FSelectedFileMatches := nil;
  FSelectedMatch := nil;
  FSelectedMatchIndex := -1;
  FExpanded := False;

  if FListView <> nil then
  begin
    FListView.Items.BeginUpdate;
    try
      FListView.Items.Clear;
    finally
      FListView.Items.EndUpdate;
    end;
  end;

  HideDetails;
end;

procedure TMatchesDisplay.AddMatch(const AData: TMatchesData);
var
  Item: TListViewItem;
  Preview: string;
  FirstPreview: string;
  FileMatches: TFileMatches;
  I: Integer;
begin
  if AData = nil then
    Exit;

  FMatches.Add(AData);
  FileMatches := FindFileMatches(AData.Filename);
  if FileMatches = nil then
  begin
    FileMatches := TFileMatches.Create(AData.Filename);
    FFileMatches.Add(FileMatches);
  end;
  FileMatches.Add(AData);

  if FListView = nil then
    Exit;

  if FileMatches.Count > 1 then
  begin
    for I := 0 to FListView.Items.Count - 1 do
      if FListView.Items[I].TagObject = FileMatches then
      begin
        FirstPreview := NormalizePreviewText(FileMatches[0].MatchValue);
        if Length(FirstPreview) > 160 then
          FirstPreview := Copy(FirstPreview, 1, 160) + '...';
        FListView.Items[I].Detail := Format('%d matches - Line %d - %s',
          [FileMatches.Count, FileMatches[0].LineNumber, FirstPreview]);
        Exit;
      end;
    Exit;
  end;

  Preview := NormalizePreviewText(AData.MatchValue);
  if Length(Preview) > 160 then
    Preview := Copy(Preview, 1, 160) + '...';

  Item := FListView.Items.Add;
  Item.Text := AData.Filename;
  Item.Detail := Format('1 match - Line %d - %s', [AData.LineNumber, Preview]);
  Item.Height := 58;
  Item.TagObject := FileMatches;
  Item.Bitmap := GetFileIcon(AData.Filename);
end;

procedure TMatchesDisplay.AddMatches(const AData: TObjectList<TMatchesData>);
var
  MatchData: TMatchesData;
begin
  if AData = nil then
    Exit;

  if FListView <> nil then
    FListView.Items.BeginUpdate;
  try
    while AData.Count > 0 do
    begin
      MatchData := AData.Extract(AData[0]);
      AddMatch(MatchData);
    end;
  finally
    if FListView <> nil then
      FListView.Items.EndUpdate;
  end;
end;

function TMatchesDisplay.Count: Integer;
begin
  Result := FMatches.Count;
end;

function TMatchesDisplay.FileCount: Integer;
begin
  Result := FFileMatches.Count;
end;

function TMatchesDisplay.SelectPreviousMatch: Boolean;
begin
  Result := (FSelectedFileMatches <> nil) and (FSelectedMatchIndex > 0);
  if Result then
    SetSelectedMatchIndex(FSelectedMatchIndex - 1);
end;

function TMatchesDisplay.SelectNextMatch: Boolean;
begin
  Result := (FSelectedFileMatches <> nil) and
    (FSelectedMatchIndex < FSelectedFileMatches.Count - 1);
  if Result then
    SetSelectedMatchIndex(FSelectedMatchIndex + 1);
end;

function TMatchesDisplay.SelectFirstMatch: Boolean;
begin
  Result := (FSelectedFileMatches <> nil) and (FSelectedMatchIndex <> 0);
  if Result then
    SetSelectedMatchIndex(0);
end;

function TMatchesDisplay.SelectLastMatch: Boolean;
begin
  Result := (FSelectedFileMatches <> nil) and
    (FSelectedMatchIndex <> FSelectedFileMatches.Count - 1);
  if Result then
    SetSelectedMatchIndex(FSelectedFileMatches.Count - 1);
end;

procedure TMatchesDisplay.OpenSelectedMatch;
var
  OpenResult: HINST;
begin
  if (FSelectedMatch = nil) or not TFile.Exists(FSelectedMatch.Filename) then
  begin
    TDialogService.MessageDialog('The matched file is no longer available.',
      TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
    Exit;
  end;

  OpenResult := ShellExecute(0, 'open', PChar(FSelectedMatch.Filename), nil, nil, SW_SHOWNORMAL);
  if OpenResult <= 32 then
  begin
    OpenResult := ShellExecute(0, 'open', 'notepad.exe', PChar(FSelectedMatch.Filename), nil, SW_SHOWNORMAL);
    if OpenResult <= 32 then
      TDialogService.MessageDialog('Unable to open the matched file.',
        TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
  end;
end;

procedure TMatchesDisplay.ListViewItemClick(const Sender: TObject; const AItem: TListViewItem);
begin
  if (AItem = nil) or not (AItem.TagObject is TFileMatches) then
  begin
    HideDetails;
    Exit;
  end;

  FSelectedFileMatches := TFileMatches(AItem.TagObject);
  SetSelectedMatchIndex(0);
  FExpanded := True;
  UpdateDetails;
end;

procedure TMatchesDisplay.DetailsClick(Sender: TObject);
begin
  FSelectedFileMatches := nil;
  FSelectedMatch := nil;
  FSelectedMatchIndex := -1;
  FExpanded := False;
  HideDetails;
end;

procedure TMatchesDisplay.PreviousMatchButtonClick(Sender: TObject);
begin
  SetSelectedMatchIndex(FSelectedMatchIndex - 1);
end;

procedure TMatchesDisplay.NextMatchButtonClick(Sender: TObject);
begin
  SetSelectedMatchIndex(FSelectedMatchIndex + 1);
end;

procedure TMatchesDisplay.SetSelectedMatchIndex(const AIndex: Integer);
begin
  if (FSelectedFileMatches = nil) or (AIndex < 0) or (AIndex >= FSelectedFileMatches.Count) then
    Exit;

  FSelectedMatchIndex := AIndex;
  FSelectedMatch := FSelectedFileMatches[AIndex];
  UpdateDetails;
  if FListView <> nil then
    FListView.SetFocus;
end;

procedure TMatchesDisplay.UpdateNavigationControls;
begin
  if FMatchPositionLabel = nil then
    Exit;

  FMatchPositionLabel.Text := Format('%d/%d', [FSelectedMatchIndex + 1, FSelectedFileMatches.Count]);
  FPreviousMatchButton.Enabled := FSelectedMatchIndex > 0;
  FNextMatchButton.Enabled := FSelectedMatchIndex < FSelectedFileMatches.Count - 1;
end;

procedure TMatchesDisplay.HideDetails;
begin
  if FDetailsPanel = nil then
    Exit;

  FDetailsPanel.Visible := False;
  FDetailsPanel.Height := 0;
  if FDetailsPaintBox <> nil then
    FDetailsPaintBox.Repaint;
end;

procedure TMatchesDisplay.UpdateDetails;
begin
  if (FSelectedMatch = nil) or (FDetailsPanel = nil) or (FDetailsPaintBox = nil) then
  begin
    HideDetails;
    Exit;
  end;

  FDetailsPanel.Visible := True;
  FDetailsPanel.Height := CalculateDetailHeight(FDetailsPaintBox.Canvas);
  UpdateNavigationControls;
  FDetailsPanel.BringToFront;
  FDetailsPaintBox.Repaint;
end;

procedure TMatchesDisplay.BuildWrappedDetails(ACanvas: TCanvas);
var
  MatchLineSource: TStringList;
  MaxWidth: Single;
begin
  FWrappedAbove.Clear;
  FWrappedMatch.Clear;
  FWrappedBelow.Clear;

  if FSelectedMatch = nil then
    Exit;

  MaxWidth := Max(180, FDetailsPaintBox.Width - (cDetailsPadding * 2) - 80);
  BuildWrappedLines(ACanvas, FSelectedMatch.LinesAbove, FWrappedAbove, MaxWidth);
  BuildWrappedLines(ACanvas, FSelectedMatch.LinesBelow, FWrappedBelow, MaxWidth);

  MatchLineSource := TStringList.Create;
  try
    MatchLineSource.Add(FSelectedMatch.MatchValue);
    BuildWrappedLines(ACanvas, MatchLineSource, FWrappedMatch, MaxWidth);
  finally
    MatchLineSource.Free;
  end;
end;

function TMatchesDisplay.CalculateDetailHeight(ACanvas: TCanvas): Single;
var
  LineHeight: Single;
  LineCount: Integer;
  MaxAvailableHeight: Single;
  ParentControl: TControl;
begin
  BuildWrappedDetails(ACanvas);

  ACanvas.Font.Size := 13;
  LineHeight := Max(20, ACanvas.TextHeight('Wg') + 4);

  LineCount := Max(1, FWrappedMatch.Count) + 3;
  if FExpanded then
    Inc(LineCount, FWrappedAbove.Count + FWrappedBelow.Count);

  Result := (LineCount * LineHeight) + (cDetailsPadding * 2);
  if not FExpanded then
    Result := Max(cCollapsedHeight, Result)
  else
  begin
    if (FDetailsPanel.Parent <> nil) and (FDetailsPanel.Parent is TControl) then
    begin
      ParentControl := TControl(FDetailsPanel.Parent);
      MaxAvailableHeight := Max(cCollapsedHeight,
        ParentControl.Size.Height - cMinListHeight - FDetailsPanel.Margins.Bottom);
    end
    else
      MaxAvailableHeight := Result;

    Result := Min(MaxAvailableHeight, Max(cCollapsedHeight, Result));
  end;
end;

procedure TMatchesDisplay.DrawTextLine(ACanvas: TCanvas; const ARect: TRectF; const AText: string;
  const AColor: TAlphaColor; const ASize: Single; const ABold: Boolean);
begin
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := AColor;
  ACanvas.Font.Size := ASize;
  if ABold then
    ACanvas.Font.Style := [TFontStyle.fsBold]
  else
    ACanvas.Font.Style := [];

  ACanvas.FillText(ARect, AText, False, 1, [], TTextAlign.Leading, TTextAlign.Leading);
end;

procedure TMatchesDisplay.DetailsPaint(Sender: TObject; Canvas: TCanvas);
var
  TopPos: Single;
  LineHeight: Single;
  I: Integer;
  TitleText: string;
  LineRect: TRectF;
  HighlightRect: TRectF;
begin
  if FSelectedMatch = nil then
    Exit;

  BuildWrappedDetails(Canvas);
  LineHeight := Max(20, Canvas.TextHeight('Wg') + 4);
  TopPos := cDetailsPadding;

  TitleText := Format('%s (Line %d)', [FSelectedMatch.Filename, FSelectedMatch.LineNumber]);
  LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding - 80, TopPos + LineHeight);
  DrawTextLine(Canvas, LineRect, TitleText, $FF20324D, 15, True);
  TopPos := TopPos + LineHeight + 4;

  if FExpanded then
  begin
    for I := 0 to FWrappedAbove.Count - 1 do
    begin
      LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding - 80, TopPos + LineHeight);
      DrawTextLine(Canvas, LineRect, FWrappedAbove[I], $FF6B7280, 13, False);
      TopPos := TopPos + LineHeight;
    end;
  end;

  HighlightRect := RectF(cDetailsPadding - 4, TopPos - 2, FDetailsPaintBox.Width - cDetailsPadding - 76,
    TopPos + (Max(1, FWrappedMatch.Count) * LineHeight) + 2);
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := $FFEAF4FF;
  Canvas.FillRect(HighlightRect, 8, 8, [], 1);

  for I := 0 to FWrappedMatch.Count - 1 do
  begin
    LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding - 80, TopPos + LineHeight);
    DrawTextLine(Canvas, LineRect, FWrappedMatch[I], $FF174B87, 13, True);
    TopPos := TopPos + LineHeight;
  end;

  TopPos := TopPos + 6;
  if FExpanded then
  begin
    for I := 0 to FWrappedBelow.Count - 1 do
    begin
      LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding - 80, TopPos + LineHeight);
      DrawTextLine(Canvas, LineRect, FWrappedBelow[I], $FF6B7280, 13, False);
      TopPos := TopPos + LineHeight;
    end;
  end
  else
  begin
    LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding - 80, TopPos + LineHeight);
    DrawTextLine(Canvas, LineRect, 'Click to show surrounding lines', $FF5F6F82, 12, False);
  end;
end;

end.
